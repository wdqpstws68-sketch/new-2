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
    case eventDetail
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

    static func freeEntry(source: LevelEntrySource) -> LevelEntryPolicy {
        LevelEntryPolicy(source: source, consumesLife: false, isDailyFreeEntry: false)
    }
}

enum PlayRouteContext: Hashable {
    case journey
    case dailyToday(dayKey: String, monthID: String, monthTitleKey: String, rewardTitleID: String?)
    case monthlyFreeplay(monthID: String, monthTitleKey: String, rewardTitleID: String?)
}

enum CompletionSourceContext: Hashable {
    case journey(chapterID: String, chapterTitleKey: String)
    case dailyToday(dayKey: String, monthID: String, monthTitleKey: String)
    case monthlyFreeplay(monthID: String, monthTitleKey: String)
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
    case returnToMonth(monthID: String)
}

enum PlayRouteEntryMode: Hashable {
    case journey
    case dailyToday
    case monthlyFreeplay
}

struct PlayRouteBehavior: Hashable {
    let entryMode: PlayRouteEntryMode
    let shouldMarkDailyCompletion: Bool
    let fixedCompletionDestination: CompletionDestination?
    let logEventID: String?

    func entryPolicy(for source: LevelEntrySource) -> LevelEntryPolicy {
        switch entryMode {
        case .journey:
            return .journey(source: source)
        case .dailyToday:
            return .daily(source: source)
        case .monthlyFreeplay:
            return .freeEntry(source: source)
        }
    }
}

extension PlayRouteContext {
    var behavior: PlayRouteBehavior {
        switch self {
        case .journey:
            return PlayRouteBehavior(
                entryMode: .journey,
                shouldMarkDailyCompletion: false,
                fixedCompletionDestination: nil,
                logEventID: nil
            )
        case let .dailyToday(_, monthID, _, _):
            return PlayRouteBehavior(
                entryMode: .dailyToday,
                shouldMarkDailyCompletion: true,
                fixedCompletionDestination: .returnHome,
                logEventID: monthID
            )
        case let .monthlyFreeplay(monthID, _, _):
            return PlayRouteBehavior(
                entryMode: .monthlyFreeplay,
                shouldMarkDailyCompletion: false,
                fixedCompletionDestination: .returnToMonth(monthID: monthID),
                logEventID: monthID
            )
        }
    }
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
    let unlockedEventTitle: EventTitleDefinition?
}
