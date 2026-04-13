import Foundation

enum CompletionRank: Int, Codable, Hashable, Comparable {
    case normal = 0
    case perfect = 1

    static func < (lhs: CompletionRank, rhs: CompletionRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum LevelEntrySource: String, Hashable {
    case journeyHero
    case chapterRail
    case completionNextLevel
    case dailyHero
    case dailyPopup
}

struct LevelEntryPolicy: Hashable {
    let source: LevelEntrySource
    let consumesLife: Bool
    let isDailyFreeEntry: Bool

    static func journey(source: LevelEntrySource) -> LevelEntryPolicy {
        LevelEntryPolicy(source: source, consumesLife: true, isDailyFreeEntry: false)
    }

    static func daily(source: LevelEntrySource) -> LevelEntryPolicy {
        LevelEntryPolicy(source: source, consumesLife: false, isDailyFreeEntry: true)
    }
}

enum PlayRouteContext: Hashable {
    case journey
    case daily(dayKey: String, titleKey: String, eventID: String?, eventTitleKey: String?)
}

enum CompletionSourceContext: Hashable {
    case journey(chapterID: String, chapterTitleKey: String)
    case daily(dayKey: String, titleKey: String, eventTitleKey: String?)
}

struct StreakProgressSummary: Hashable {
    let current: Int
    let best: Int
    let countedToday: Bool
    let awardedBadgeID: String?
}

enum CompletionDestination: Hashable {
    case nextLevel(storageKey: String)
    case chapterUnlocked(chapterID: String)
    case openCollectionBook(chapterID: String?)
    case returnHome
}

struct LevelCompletionSummary: Identifiable, Hashable {
    let id = UUID()
    let level: LevelManifest
    let filledCells: Int
    let completionRank: CompletionRank
    let sourceContext: CompletionSourceContext
    let destination: CompletionDestination
    let streakSummary: StreakProgressSummary
    let chapterMissionSummary: ChapterMissionSummary?
}
