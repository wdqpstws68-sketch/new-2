import Foundation
import SwiftUI

struct DailyCatalogManifest: Decodable, Hashable {
    let schemaVersion: Int
    let titleKey: String
    let subtitleKey: String
    let albumTitleKey: String
    let months: [EventManifest]

    init(
        schemaVersion: Int = 1,
        titleKey: String,
        subtitleKey: String,
        albumTitleKey: String,
        months: [EventManifest]
    ) {
        self.schemaVersion = schemaVersion
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.albumTitleKey = albumTitleKey
        self.months = months
    }
}

enum MonthlyDailySelectionPhase: String, Decodable, Hashable {
    case early
    case mid
    case late
}

enum MonthlyDailyAvailability: String, Decodable, Hashable {
    case always
    case leapYearOnly = "leap_year_only"
}

struct MonthlyDailyEntryManifest: Decodable, Hashable, Identifiable {
    let index: Int
    let levelKey: String
    let difficulty: String
    let selectionPhase: MonthlyDailySelectionPhase
    let availability: MonthlyDailyAvailability

    var id: String { "\(index)-\(levelKey)" }

    func isAvailable(on date: Date, calendar: Calendar = .current) -> Bool {
        switch availability {
        case .always:
            return true
        case .leapYearOnly:
            return calendar.range(of: .day, in: .month, for: date)?.count == 29
        }
    }
}

struct EventManifest: Decodable, Hashable, Identifiable {
    let id: String
    let month: Int
    let titleKey: String
    let bannerKey: String
    let accentHex: String
    let archiveTitleKey: String
    let archiveSubtitleKey: String
    let rewardTitleID: String
    let rewardTitleKey: String
    let rewardSubtitleKey: String
    let entries: [MonthlyDailyEntryManifest]

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

    var dailyLevelKeys: [String] {
        entries.map(\.levelKey)
    }

    func availableEntries(on date: Date, calendar: Calendar = .current) -> [MonthlyDailyEntryManifest] {
        entries.filter { $0.isAvailable(on: date, calendar: calendar) }
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
    let monthID: String
    let level: LevelManifest
    let titleKey: String
    let subtitleKey: String
    let albumTitleKey: String
    let accentHex: String
    let eventTitleKey: String?
    let isCompletedToday: Bool
    let isCompletedEver: Bool
    let bestRank: CompletionRank
    let completedMonthCount: Int
    let totalMonthCount: Int
    let isMonthCompleted: Bool
    let isMonthlyRewardUnlocked: Bool
    let isReplayPick: Bool

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
        let currentMonth = dailyRepository.activeEvent(on: currentDate)
        let recentHistory = currentMonth.map {
            profile?.monthlyDailyRecentHistory[$0.id] ?? []
        } ?? []
        let resolvedDailyChallenge = resolvedDailyChallenge
            ?? dailyRepository.challenge(
                for: currentDate,
                profileKey: profile?.profileKey ?? "primary",
                completedStorageKeys: completedStorageKeys,
                pinnedSelection: profile?.currentMonthlyDailySelection,
                recentHistory: recentHistory
            )
        let dayKey = resolvedDailyChallenge?.dayKey ?? DayKey.string(from: currentDate)
        self.lifeBalance = lifeBalance

        let earnedRewardIDs = profile?.earnedBadgeIDs ?? []
        let equippedTitleID = profile?.equippedTitleID
        let resolvedEventCollections = dailyRepository.eventsForCollection(on: currentDate).map { event in
            EventCollectionState(
                event: event,
                entries: event.availableEntries(on: currentDate).compactMap { entry in
                    guard let level = dailyRepository.level(storageKey: entry.levelKey) else {
                        return nil
                    }
                    let progress = progressLookup[level.storageKey]
                    return DailyAlbumEntryState(
                        level: level,
                        isCompleted: progress?.completedAt != nil,
                        bestRank: progress?.bestCompletionRank ?? .normal,
                        isToday: level.storageKey == resolvedDailyChallenge?.level.storageKey
                    )
                },
                isActive: event.id == currentMonth?.id,
                isTitleUnlocked: earnedRewardIDs.contains(event.rewardTitleID),
                isTitleEquipped: equippedTitleID == event.rewardTitleID
            )
        }
        self.activeEvent = currentMonth
        self.eventCollections = resolvedEventCollections

        let currentMonthCollection = currentMonth.flatMap { month in
            resolvedEventCollections.first(where: { $0.id == month.id })
        }

        if let challenge = resolvedDailyChallenge {
            let progress = progressLookup[challenge.level.storageKey]
            self.dailyChallenge = DailyChallengeState(
                dayKey: challenge.dayKey,
                monthID: challenge.month.id,
                level: challenge.level,
                titleKey: challenge.titleKey,
                subtitleKey: challenge.subtitleKey,
                albumTitleKey: challenge.albumTitleKey,
                accentHex: challenge.accentHex,
                eventTitleKey: challenge.event?.titleKey,
                isCompletedToday: profile?.completedDailyDayKeys.contains(challenge.dayKey) ?? false,
                isCompletedEver: progress?.completedAt != nil,
                bestRank: progress?.bestCompletionRank ?? .normal,
                completedMonthCount: currentMonthCollection?.completedEntryCount ?? 0,
                totalMonthCount: currentMonthCollection?.totalEntryCount ?? 0,
                isMonthCompleted: currentMonthCollection?.isCompleted ?? false,
                isMonthlyRewardUnlocked: currentMonthCollection?.isTitleUnlocked ?? false,
                isReplayPick: challenge.isReplayPick
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

        self.dailyAlbumEntries = currentMonthCollection?.entries ?? []
    }
}

@MainActor
struct DailyChallengeRepository {
    private static let fallbackCatalog = DailyCatalogManifest(
        titleKey: "Monthly Daily",
        subtitleKey: "Paint one cozy artwork each day.",
        albumTitleKey: "This Month",
        months: []
    )

    let bundle: Bundle
    let levelRepository: LevelRepository
    let catalog: DailyCatalogManifest

    init(bundle: Bundle = .main, levelRepository: LevelRepository) {
        self.bundle = bundle
        self.levelRepository = levelRepository
        self.catalog = Self.loadCatalog(from: bundle) ?? Self.fallbackCatalog
    }

    init(
        bundle: Bundle = .main,
        levelRepository: LevelRepository,
        catalog: DailyCatalogManifest
    ) {
        self.bundle = bundle
        self.levelRepository = levelRepository
        self.catalog = catalog
    }

    var events: [EventManifest] {
        catalog.months.sorted { lhs, rhs in lhs.month < rhs.month }
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
        let monthID = MonthKey.id(for: date, calendar: calendar)
        return events.first(where: { $0.id == monthID })
    }

    func archivedEvents(on date: Date, calendar: Calendar = .current) -> [EventManifest] {
        let activeMonthID = MonthKey.id(for: date, calendar: calendar)
        return events.filter { $0.id != activeMonthID }
    }

    func eventsForCollection(on date: Date, calendar: Calendar = .current) -> [EventManifest] {
        let activeMonthID = MonthKey.id(for: date, calendar: calendar)
        return events.sorted { lhs, rhs in
            if lhs.id == activeMonthID { return true }
            if rhs.id == activeMonthID { return false }
            return lhs.month < rhs.month
        }
    }

    func challenge(
        for date: Date,
        profileKey: String = "primary",
        completedStorageKeys: Set<String> = [],
        pinnedSelection: MonthlyDailySelectionRecord? = nil,
        pinnedStorageKey: String? = nil,
        recentHistory: [String] = [],
        calendar: Calendar = .current
    ) -> DailyChallengeDefinition? {
        guard let activeEvent = activeEvent(on: date, calendar: calendar) else {
            return nil
        }

        let currentDay = calendar.startOfDay(for: date)
        let dayKey = DayKey.string(from: currentDay, calendar: calendar)
        let availableEntries = activeEvent.availableEntries(on: date, calendar: calendar)
        guard !availableEntries.isEmpty else { return nil }

        if let pinnedSelection,
           pinnedSelection.profileKey == profileKey,
           pinnedSelection.dayKey == dayKey,
           pinnedSelection.monthID == activeEvent.id,
           let pinnedEntry = availableEntries.first(where: { $0.levelKey == pinnedSelection.storageKey }),
           let pinnedLevel = level(storageKey: pinnedEntry.levelKey) {
            return DailyChallengeDefinition(
                dayKey: dayKey,
                level: pinnedLevel,
                titleKey: activeEvent.titleKey,
                subtitleKey: activeEvent.bannerKey,
                albumTitleKey: catalog.albumTitleKey,
                accentHex: activeEvent.accentHex,
                event: activeEvent,
                month: activeEvent,
                isReplayPick: false
            )
        }

        if let pinnedStorageKey,
           let pinnedEntry = availableEntries.first(where: { $0.levelKey == pinnedStorageKey }),
           let pinnedLevel = level(storageKey: pinnedEntry.levelKey) {
            return DailyChallengeDefinition(
                dayKey: dayKey,
                level: pinnedLevel,
                titleKey: activeEvent.titleKey,
                subtitleKey: activeEvent.bannerKey,
                albumTitleKey: catalog.albumTitleKey,
                accentHex: activeEvent.accentHex,
                event: activeEvent,
                month: activeEvent,
                isReplayPick: false
            )
        }

        let phase = selectionPhase(for: currentDay, calendar: calendar)
        let unresolvedPhase = availableEntries.filter {
            $0.selectionPhase == phase && !completedStorageKeys.contains($0.levelKey)
        }
        let unresolvedAll = availableEntries.filter { !completedStorageKeys.contains($0.levelKey) }

        let candidateEntries = filteredCandidateEntries(from: unresolvedPhase, recentHistory: recentHistory)
            ?? unresolvedPhase.nonEmpty
            ?? filteredCandidateEntries(from: unresolvedAll, recentHistory: recentHistory)
            ?? unresolvedAll.nonEmpty
        let isReplayPick = candidateEntries == nil
        let replayEntries = filteredCandidateEntries(
            from: availableEntries.filter { completedStorageKeys.contains($0.levelKey) },
            recentHistory: recentHistory
        )
        ?? availableEntries.filter { completedStorageKeys.contains($0.levelKey) }.nonEmpty

        let selectionPool = candidateEntries ?? replayEntries ?? availableEntries
        guard let selectedEntry = deterministicEntry(
            from: selectionPool,
            dayKey: dayKey,
            monthID: activeEvent.id,
            profileKey: profileKey
        ),
        let level = level(storageKey: selectedEntry.levelKey) else {
            return nil
        }

        return DailyChallengeDefinition(
            dayKey: dayKey,
            level: level,
            titleKey: activeEvent.titleKey,
            subtitleKey: activeEvent.bannerKey,
            albumTitleKey: catalog.albumTitleKey,
            accentHex: activeEvent.accentHex,
            event: activeEvent,
            month: activeEvent,
            isReplayPick: isReplayPick
        )
    }

    private static func loadCatalog(from bundle: Bundle) -> DailyCatalogManifest? {
        guard let url = bundle.url(forResource: "monthly_daily_events", withExtension: "json", subdirectory: "Journey"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("Missing monthly_daily_events.json")
            return nil
        }

        do {
            return try JSONDecoder().decode(DailyCatalogManifest.self, from: data)
        } catch {
            assertionFailure("Failed to decode monthly_daily_events.json: \(error)")
            return nil
        }
    }

    private func selectionPhase(for date: Date, calendar: Calendar) -> MonthlyDailySelectionPhase {
        let day = calendar.component(.day, from: date)
        switch day {
        case 1 ... 10:
            return .early
        case 11 ... 20:
            return .mid
        default:
            return .late
        }
    }

    private func filteredCandidateEntries(
        from entries: [MonthlyDailyEntryManifest],
        recentHistory: [String]
    ) -> [MonthlyDailyEntryManifest]? {
        guard entries.count >= 4 else { return nil }
        let filtered = entries.filter { !recentHistory.contains($0.levelKey) }
        return filtered.nonEmpty
    }

    private func deterministicEntry(
        from entries: [MonthlyDailyEntryManifest],
        dayKey: String,
        monthID: String,
        profileKey: String
    ) -> MonthlyDailyEntryManifest? {
        entries.min { lhs, rhs in
            deterministicHash(
                seed: "\(dayKey)|\(monthID)|\(profileKey)|\(lhs.levelKey)"
            ) < deterministicHash(
                seed: "\(dayKey)|\(monthID)|\(profileKey)|\(rhs.levelKey)"
            )
        }
    }

    private func deterministicHash(seed: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603

        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return hash
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
    let month: EventManifest
    let isReplayPick: Bool
}

enum MonthKey {
    static func id(for date: Date, calendar: Calendar = .current) -> String {
        let month = calendar.component(.month, from: date)
        return String(format: "month-%02d", month)
    }

    static func monthNumber(from id: String) -> Int? {
        guard id.hasPrefix("month-") else { return nil }
        return Int(id.replacingOccurrences(of: "month-", with: ""))
    }
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
        formatter.calendar = calendar
        return formatter.string(from: calendar.startOfDay(for: date))
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        formatter.timeZone = calendar.timeZone
        formatter.calendar = calendar
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

private extension Array {
    var nonEmpty: Self? {
        isEmpty ? nil : self
    }
}
