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
    let rewardTitleID: String
    let rewardTitleKey: String
    let rewardSubtitleKey: String

    init(
        id: String,
        titleKey: String,
        bannerKey: String,
        startDate: String,
        endDate: String,
        accentHex: String,
        dailyLevelKeys: [String],
        archiveTitleKey: String,
        archiveSubtitleKey: String,
        rewardTitleID: String,
        rewardTitleKey: String,
        rewardSubtitleKey: String
    ) {
        self.id = id
        self.titleKey = titleKey
        self.bannerKey = bannerKey
        self.startDate = startDate
        self.endDate = endDate
        self.accentHex = accentHex
        self.dailyLevelKeys = dailyLevelKeys
        self.archiveTitleKey = archiveTitleKey
        self.archiveSubtitleKey = archiveSubtitleKey
        self.rewardTitleID = rewardTitleID
        self.rewardTitleKey = rewardTitleKey
        self.rewardSubtitleKey = rewardSubtitleKey
    }

    var accentColor: Color {
        Color(hex: accentHex)
    }

    var rewardTitle: EventTitleDefinition {
        EventTitleDefinition(
            id: rewardTitleID,
            titleKey: rewardTitleKey,
            subtitleKey: rewardSubtitleKey,
            eventID: id
        )
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

struct EventTitleDefinition: Hashable, Identifiable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let eventID: String

    func localizedTitle(using localization: AppLocalization) -> String {
        localization.string(titleKey)
    }

    func localizedSubtitle(using localization: AppLocalization) -> String {
        localization.string(subtitleKey)
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

struct EventCollectionState: Identifiable, Hashable {
    let event: EventManifest
    let entries: [DailyAlbumEntryState]
    let isActive: Bool
    let isTitleUnlocked: Bool
    let isTitleEquipped: Bool

    var id: String { event.id }

    var titleDefinition: EventTitleDefinition {
        event.rewardTitle
    }

    var completedEntryCount: Int {
        entries.count(where: \.isCompleted)
    }

    var totalEntryCount: Int {
        entries.count
    }

    var isCompleted: Bool {
        totalEntryCount > 0 && completedEntryCount == totalEntryCount
    }

    func localizedHeaderTitle(using localization: AppLocalization) -> String {
        isActive
            ? event.localizedTitle(using: localization)
            : event.localizedArchiveTitle(using: localization)
    }

    func localizedHeaderSubtitle(using localization: AppLocalization) -> String {
        isActive
            ? event.localizedBanner(using: localization)
            : event.localizedArchiveSubtitle(using: localization)
    }
}

enum DailyChallengeSelectionStore {
    private static let selectedDayKeyKey = "daily.challenge.selected.dayKey"
    private static let selectedStorageKeyKey = "daily.challenge.selected.storageKey"

    static func pinnedStorageKey(for dayKey: String, defaults: UserDefaults = .standard) -> String? {
        guard defaults.string(forKey: selectedDayKeyKey) == dayKey else { return nil }
        return defaults.string(forKey: selectedStorageKeyKey)
    }

    static func persist(storageKey: String, for dayKey: String, defaults: UserDefaults = .standard) {
        defaults.set(dayKey, forKey: selectedDayKeyKey)
        defaults.set(storageKey, forKey: selectedStorageKeyKey)
    }
}

struct HomeProgressSnapshot: Hashable {
    let dailyChallenge: DailyChallengeState?
    let lifeBalance: LifeBalance
    let streak: HomeStreakState
    let badges: [BadgeDefinition]
    let equippedEventTitle: EventTitleDefinition?
    let chapterMissionSummaries: [ChapterMissionSummary]
    let dailyAlbumEntries: [DailyAlbumEntryState]
    let activeEvent: EventManifest?
    let eventCollections: [EventCollectionState]

    func chapterMissionSummary(for chapterID: String?) -> ChapterMissionSummary? {
        guard let chapterID else { return nil }
        return chapterMissionSummaries.first(where: { $0.chapterID == chapterID })
    }

    func eventCollection(eventID: String) -> EventCollectionState? {
        eventCollections.first(where: { $0.id == eventID })
    }

    @MainActor
    init(
        journeySnapshot: JourneyProgressSnapshot,
        dailyRepository: DailyChallengeRepository,
        progressLookup: [String: LevelProgress],
        lifeBalance: LifeBalance,
        profile: PlayerProfile?,
        resolvedDailyChallenge: DailyChallengeDefinition? = nil,
        currentDate: Date = .now
    ) {
        let completedStorageKeys = Set(
            progressLookup.compactMap { storageKey, progress in
                progress.completedAt != nil ? storageKey : nil
            }
        )
        let resolvedDailyChallenge = resolvedDailyChallenge
            ?? dailyRepository.challenge(
                for: currentDate,
                completedStorageKeys: completedStorageKeys
            )
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
        self.equippedEventTitle = dailyRepository.eventTitleDefinition(id: profile?.equippedTitleID)

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
        self.dailyAlbumEntries = dailyRepository.dailyAlbumLevels.compactMap { level in
            let progress = progressLookup[level.storageKey]
            return DailyAlbumEntryState(
                level: level,
                isCompleted: progress?.completedAt != nil,
                bestRank: progress?.bestCompletionRank ?? .normal,
                isToday: level.storageKey == todayStorageKey
            )
        }

        let activeEvent = dailyRepository.activeEvent(on: currentDate)
        self.activeEvent = activeEvent
        let earnedRewardIDs = profile?.earnedBadgeIDs ?? []
        let equippedTitleID = profile?.equippedTitleID
        self.eventCollections = dailyRepository.eventsForCollection(on: currentDate).map { event in
            EventCollectionState(
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
                },
                isActive: event.id == activeEvent?.id,
                isTitleUnlocked: earnedRewardIDs.contains(event.rewardTitleID),
                isTitleEquipped: equippedTitleID == event.rewardTitleID
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

    var eventLevelKeys: Set<String> {
        Set(events.flatMap(\.dailyLevelKeys))
    }

    var dailyAlbumLevels: [LevelManifest] {
        catalog.dailyLevelKeys
            .filter { !eventLevelKeys.contains($0) }
            .compactMap(level(storageKey:))
    }

    func level(storageKey: String) -> LevelManifest? {
        levelRepository.level(storageKey: storageKey)
    }

    func event(id: String) -> EventManifest? {
        events.first(where: { $0.id == id })
    }

    func eventTitleDefinition(id: String?) -> EventTitleDefinition? {
        guard let id else { return nil }
        return events.first(where: { $0.rewardTitleID == id })?.rewardTitle
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

    func eventsForCollection(on date: Date, calendar: Calendar = .current) -> [EventManifest] {
        let active = activeEvent(on: date, calendar: calendar)
        let archived = archivedEvents(on: date, calendar: calendar)
        return [active].compactMap { $0 } + archived.filter { $0.id != active?.id }
    }

    func challenge(
        for date: Date,
        completedStorageKeys: Set<String> = [],
        pinnedStorageKey: String? = nil,
        calendar: Calendar = .current
    ) -> DailyChallengeDefinition? {
        let activeEvent = activeEvent(on: date, calendar: calendar)
        let pool = activeEvent?.dailyLevelKeys ?? catalog.dailyLevelKeys
        guard !pool.isEmpty else { return nil }

        let currentDay = calendar.startOfDay(for: date)
        let dayKey = DayKey.string(from: currentDay, calendar: calendar)

        if let pinnedStorageKey,
           pool.contains(pinnedStorageKey),
           let pinnedLevel = level(storageKey: pinnedStorageKey) {
            return DailyChallengeDefinition(
                dayKey: dayKey,
                level: pinnedLevel,
                titleKey: activeEvent?.titleKey ?? catalog.titleKey,
                subtitleKey: activeEvent?.bannerKey ?? catalog.subtitleKey,
                albumTitleKey: catalog.albumTitleKey,
                accentHex: activeEvent?.accentHex ?? "FF8A2A",
                event: activeEvent
            )
        }

        let unresolvedPool = pool.filter { !completedStorageKeys.contains($0) }
        let selectionPool = unresolvedPool.isEmpty ? pool : unresolvedPool
        let storageKey = selectionPool[deterministicSelectionIndex(for: dayKey, eventID: activeEvent?.id, count: selectionPool.count)]
        guard let level = level(storageKey: storageKey) else { return nil }

        return DailyChallengeDefinition(
            dayKey: dayKey,
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

    private func deterministicSelectionIndex(for dayKey: String, eventID: String?, count: Int) -> Int {
        precondition(count > 0, "count must be positive")
        let salt = eventID ?? catalog.referenceDate
        let seed = "\(dayKey)|\(salt)"
        var hash: UInt64 = 1_469_598_103_934_665_603

        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return Int(hash % UInt64(count))
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
