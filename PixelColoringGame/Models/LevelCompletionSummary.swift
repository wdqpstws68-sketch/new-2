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
    case daily(dayKey: String, titleKey: String, eventID: String?, eventTitleKey: String?)
    case event(eventID: String, eventTitleKey: String)
}

enum CompletionSourceContext: Hashable {
    case journey(chapterID: String, chapterTitleKey: String)
    case daily(dayKey: String, titleKey: String, eventTitleKey: String?)
    case event(eventID: String, eventTitleKey: String)
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
    case returnToEvent(eventID: String)
}

enum PlayRouteEntryMode: Hashable {
    case journey
    case daily
    case freeEvent
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
        case .daily:
            return .daily(source: source)
        case .freeEvent:
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
        case let .daily(_, _, eventID, _):
            return PlayRouteBehavior(
                entryMode: .daily,
                shouldMarkDailyCompletion: true,
                fixedCompletionDestination: .returnHome,
                logEventID: eventID
            )
        case let .event(eventID, _):
            return PlayRouteBehavior(
                entryMode: .freeEvent,
                shouldMarkDailyCompletion: false,
                fixedCompletionDestination: .returnToEvent(eventID: eventID),
                logEventID: eventID
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
