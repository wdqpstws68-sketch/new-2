import Foundation
import SwiftUI

struct DailyCatalogManifest: Decodable, Hashable {
    let titleKey: String
    let subtitleKey: String
    let albumTitleKey: String
    let referenceDate: String
    let dailyLevelKeys: [String]
}

struct EventManifest: Decodable, Hashable, Identifiable {
    let id: String
    let titleKey: String
    let bannerKey: String
    let startDate: String
    let endDate: String
    let accentHex: String
    let dailyLevelKeys: [String]
    let archiveTitleKey: String
    let archiveSubtitleKey: String

    var accentColor: Color {
        Color(hex: accentHex)
    }

    func localizedTitle(using localization: AppLocalization) -> String {
        localization.string(titleKey)
    }

    func localizedBanner(using localization: AppLocalization) -> String {
        localization.string(bannerKey)
    }

    func localizedArchiveTitle(using localization: AppLocalization) -> String {
        localization.string(archiveTitleKey)
    }

    func localizedArchiveSubtitle(using localization: AppLocalization) -> String {
        localization.string(archiveSubtitleKey)
    }
}

struct DailyChallengeState: Hashable {
    let dayKey: String
    let level: LevelManifest
    let titleKey: String
    let subtitleKey: String
    let albumTitleKey: String
    let accentHex: String
    let eventTitleKey: String?
    let isCompletedToday: Bool
    let isCompletedEver: Bool
    let bestRank: CompletionRank

    var accentColor: Color {
        Color(hex: accentHex)
    }

    func localizedTitle(using localization: AppLocalization) -> String {
        localization.string(titleKey)
    }

    func localizedSubtitle(using localization: AppLocalization) -> String {
        localization.string(subtitleKey)
    }

    func localizedAlbumTitle(using localization: AppLocalization) -> String {
        localization.string(albumTitleKey)
    }

    func localizedEventTitle(using localization: AppLocalization) -> String? {
        guard let eventTitleKey else { return nil }
        return localization.string(eventTitleKey)
    }
}

struct HomeStreakState: Hashable {
    let current: Int
    let best: Int
    let countedToday: Bool
}

enum ChapterMissionKind: String, Hashable {
    case finishArtworks
    case earnPerfects
    case finishAllArtworks

    func localizedTitle(targetValue: Int, using localization: AppLocalization) -> String {
        switch self {
        case .finishArtworks:
            return localization.string("mission.finishArtworks", targetValue)
        case .earnPerfects:
            return localization.string("mission.earnPerfects", targetValue)
        case .finishAllArtworks:
            return localization.string("mission.finishAllArtworks", targetValue)
        }
    }
}

struct ChapterMissionProgress: Identifiable, Hashable {
    let id: String
    let kind: ChapterMissionKind
    let progressValue: Int
    let targetValue: Int

    var isCompleted: Bool {
        progressValue >= targetValue
    }

    var progressLabel: String {
        "\(min(progressValue, targetValue))/\(targetValue)"
    }

    func localizedTitle(using localization: AppLocalization) -> String {
        kind.localizedTitle(targetValue: targetValue, using: localization)
    }
}

struct ChapterMissionSummary: Identifiable, Hashable {
    let chapterID: String
    let chapterTitleKey: String
    let missions: [ChapterMissionProgress]

    var id: String { chapterID }

    var completedCount: Int {
        missions.count(where: \.isCompleted)
    }
}

struct DailyAlbumEntryState: Identifiable, Hashable {
    let level: LevelManifest
    let isCompleted: Bool
    let bestRank: CompletionRank
    let isToday: Bool

    var id: String { level.storageKey }
}

struct EventArchiveState: Identifiable, Hashable {
    let event: EventManifest
    let entries: [DailyAlbumEntryState]

    var id: String { event.id }
}

struct HomeProgressSnapshot: Hashable {
    let dailyChallenge: DailyChallengeState?
    let lifeBalance: LifeBalance
    let streak: HomeStreakState
    let badges: [BadgeDefinition]
    let chapterMissionSummaries: [ChapterMissionSummary]
    let dailyAlbumEntries: [DailyAlbumEntryState]
    let activeEvent: EventManifest?
    let archivedEvents: [EventArchiveState]

    func chapterMissionSummary(for chapterID: String?) -> ChapterMissionSummary? {
        guard let chapterID else { return nil }
        return chapterMissionSummaries.first(where: { $0.chapterID == chapterID })
    }

    @MainActor
    init(
        journeySnapshot: JourneyProgressSnapshot,
        dailyRepository: DailyChallengeRepository,
        progressLookup: [String: LevelProgress],
        lifeBalance: LifeBalance,
        profile: PlayerProfile?,
        currentDate: Date = .now
    ) {
        let resolvedDailyChallenge = dailyRepository.challenge(for: currentDate)
        let dayKey = resolvedDailyChallenge?.dayKey ?? DayKey.string(from: currentDate)
        self.lifeBalance = lifeBalance

        if let challenge = resolvedDailyChallenge {
            let progress = progressLookup[challenge.level.storageKey]
            self.dailyChallenge = DailyChallengeState(
                dayKey: challenge.dayKey,
                level: challenge.level,
                titleKey: challenge.titleKey,
                subtitleKey: challenge.subtitleKey,
                albumTitleKey: challenge.albumTitleKey,
                accentHex: challenge.accentHex,
                eventTitleKey: challenge.event?.titleKey,
                isCompletedToday: profile?.completedDailyDayKeys.contains(challenge.dayKey) ?? false,
                isCompletedEver: progress?.completedAt != nil,
                bestRank: progress?.bestCompletionRank ?? .normal
            )
        } else {
            self.dailyChallenge = nil
        }

        self.streak = HomeStreakState(
            current: profile?.currentStreak ?? 0,
            best: profile?.bestStreak ?? 0,
            countedToday: profile?.lastActiveDayKey == dayKey
        )

        let badgeLookup = [
            BadgeDefinition.streak7.id: BadgeDefinition.streak7
        ]
        self.badges = (profile?.earnedBadgeIDs ?? [])
            .compactMap { badgeLookup[$0] }
            .sorted { $0.id < $1.id }

        self.chapterMissionSummaries = journeySnapshot.chapters.map { chapter in
            let completedCount = chapter.completedLevelCount
            let perfectCount = chapter.levelStates.count { levelState in
                progressLookup[levelState.level.storageKey]?.bestCompletionRank == .perfect
            }
            let twoArtworksTarget = min(2, max(chapter.totalLevelCount, 1))

            return ChapterMissionSummary(
                chapterID: chapter.id,
                chapterTitleKey: chapter.chapter.chapter.titleKey,
                missions: [
                    ChapterMissionProgress(
                        id: "\(chapter.id).finish-two",
                        kind: .finishArtworks,
                        progressValue: completedCount,
                        targetValue: twoArtworksTarget
                    ),
                    ChapterMissionProgress(
                        id: "\(chapter.id).perfect-one",
                        kind: .earnPerfects,
                        progressValue: perfectCount,
                        targetValue: 1
                    ),
                    ChapterMissionProgress(
                        id: "\(chapter.id).finish-all",
                        kind: .finishAllArtworks,
                        progressValue: completedCount,
                        targetValue: max(chapter.totalLevelCount, 1)
                    )
                ]
            )
        }

        let todayStorageKey = resolvedDailyChallenge?.level.storageKey
        self.dailyAlbumEntries = dailyRepository.catalogLevels.compactMap { level in
            let progress = progressLookup[level.storageKey]
            return DailyAlbumEntryState(
                level: level,
                isCompleted: progress?.completedAt != nil,
                bestRank: progress?.bestCompletionRank ?? .normal,
                isToday: level.storageKey == todayStorageKey
            )
        }

        self.activeEvent = dailyRepository.activeEvent(on: currentDate)
        self.archivedEvents = dailyRepository.archivedEvents(on: currentDate).map { event in
            EventArchiveState(
                event: event,
                entries: event.dailyLevelKeys.compactMap { storageKey in
                    guard let level = dailyRepository.level(storageKey: storageKey) else {
                        return nil
                    }
                    let progress = progressLookup[storageKey]
                    return DailyAlbumEntryState(
                        level: level,
                        isCompleted: progress?.completedAt != nil,
                        bestRank: progress?.bestCompletionRank ?? .normal,
                        isToday: level.storageKey == todayStorageKey
                    )
                }
            )
        }
    }
}

@MainActor
struct DailyChallengeRepository {
    private static let fallbackCatalog = DailyCatalogManifest(
        titleKey: "daily.catalog.title",
        subtitleKey: "daily.catalog.subtitle",
        albumTitleKey: "daily.catalog.albumTitle",
        referenceDate: "2026-01-01",
        dailyLevelKeys: []
    )

    let bundle: Bundle
    let levelRepository: LevelRepository
    let catalog: DailyCatalogManifest
    let events: [EventManifest]

    init(bundle: Bundle = .main, levelRepository: LevelRepository) {
        self.bundle = bundle
        self.levelRepository = levelRepository
        self.catalog = Self.loadCatalog(from: bundle) ?? Self.fallbackCatalog
        self.events = Self.loadEvents(from: bundle)
    }

    init(
        bundle: Bundle = .main,
        levelRepository: LevelRepository,
        catalog: DailyCatalogManifest,
        events: [EventManifest]
    ) {
        self.bundle = bundle
        self.levelRepository = levelRepository
        self.catalog = catalog
        self.events = events
    }

    var catalogLevels: [LevelManifest] {
        catalog.dailyLevelKeys.compactMap(level(storageKey:))
    }

    func level(storageKey: String) -> LevelManifest? {
        levelRepository.level(storageKey: storageKey)
    }

    func activeEvent(on date: Date, calendar: Calendar = .current) -> EventManifest? {
        let currentDay = calendar.startOfDay(for: date)
        return events.first(where: { event in
            guard let startDay = DayKey.date(from: event.startDate, calendar: calendar),
                  let endDay = DayKey.date(from: event.endDate, calendar: calendar) else {
                return false
            }
            return currentDay >= startDay && currentDay <= endDay
        })
    }

    func archivedEvents(on date: Date, calendar: Calendar = .current) -> [EventManifest] {
        let currentDay = calendar.startOfDay(for: date)
        return events.filter { event in
            guard let endDay = DayKey.date(from: event.endDate, calendar: calendar) else {
                return false
            }
            return endDay < currentDay
        }
    }

    func challenge(for date: Date, calendar: Calendar = .current) -> DailyChallengeDefinition? {
        let activeEvent = activeEvent(on: date, calendar: calendar)
        let pool = activeEvent?.dailyLevelKeys ?? catalog.dailyLevelKeys
        guard !pool.isEmpty else { return nil }

        let referenceKey = activeEvent?.startDate ?? catalog.referenceDate
        guard let referenceDate = DayKey.date(from: referenceKey, calendar: calendar) else {
            return nil
        }

        let startDay = calendar.startOfDay(for: referenceDate)
        let currentDay = calendar.startOfDay(for: date)
        let dayOffset = max(calendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0, 0)
        let storageKey = pool[dayOffset % pool.count]
        guard let level = level(storageKey: storageKey) else { return nil }

        return DailyChallengeDefinition(
            dayKey: DayKey.string(from: currentDay, calendar: calendar),
            level: level,
            titleKey: activeEvent?.titleKey ?? catalog.titleKey,
            subtitleKey: activeEvent?.bannerKey ?? catalog.subtitleKey,
            albumTitleKey: catalog.albumTitleKey,
            accentHex: activeEvent?.accentHex ?? "FF8A2A",
            event: activeEvent
        )
    }

    private static func loadCatalog(from bundle: Bundle) -> DailyCatalogManifest? {
        guard let url = bundle.url(forResource: "daily_catalog", withExtension: "json", subdirectory: "Journey"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(DailyCatalogManifest.self, from: data)
    }

    private static func loadEvents(from bundle: Bundle) -> [EventManifest] {
        guard let url = bundle.url(forResource: "events", withExtension: "json", subdirectory: "Journey"),
              let data = try? Data(contentsOf: url) else {
            return []
        }

        return (try? JSONDecoder().decode([EventManifest].self, from: data)) ?? []
    }
}

struct DailyChallengeDefinition: Hashable {
    let dayKey: String
    let level: LevelManifest
    let titleKey: String
    let subtitleKey: String
    let albumTitleKey: String
    let accentHex: String
    let event: EventManifest?
}

enum DayKey {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date, calendar: Calendar = .current) -> String {
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: calendar.startOfDay(for: date))
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: key).map { calendar.startOfDay(for: $0) }
    }

    static func displayRange(start: String, end: String, locale: Locale = .current, calendar: Calendar = .current) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.locale = locale
        displayFormatter.timeZone = calendar.timeZone
        displayFormatter.calendar = calendar
        displayFormatter.dateStyle = .medium

        guard let startDate = date(from: start, calendar: calendar),
              let endDate = date(from: end, calendar: calendar) else {
            return "\(start) - \(end)"
        }

        return "\(displayFormatter.string(from: startDate)) - \(displayFormatter.string(from: endDate))"
    }
}
