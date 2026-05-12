import Foundation

enum CelebrationEvent: Hashable, Identifiable {
    case journeyComplete
    case monthlyComplete(yearMonth: String)
    case chapterClear(chapterID: String)
    case firstPerfect
    case streakMilestone(days: Int)
    case levelCountMilestone(count: Int)

    var id: String { seenKey }

    var priority: Int {
        switch self {
        case .journeyComplete: return 100
        case .monthlyComplete: return 90
        case .chapterClear: return 80
        case .firstPerfect: return 70
        case .streakMilestone(let days):
            switch days {
            case 30: return 62
            case 14: return 61
            case 7: return 60
            default: return 60
            }
        case .levelCountMilestone(let count):
            switch count {
            case 100: return 52
            case 50: return 51
            case 10: return 50
            default: return 50
            }
        }
    }

    var seenKey: String {
        switch self {
        case .journeyComplete: return "journeyComplete"
        case .monthlyComplete(let ym): return "monthlyComplete:\(ym)"
        case .chapterClear(let id): return "chapterClear:\(id)"
        case .firstPerfect: return "firstPerfect"
        case .streakMilestone(let days): return "streak:\(days)"
        case .levelCountMilestone(let count): return "levels:\(count)"
        }
    }

    var presentationKind: CelebrationPresentationKind {
        switch self {
        case .journeyComplete, .monthlyComplete, .chapterClear:
            return .fullScreen
        case .firstPerfect, .streakMilestone, .levelCountMilestone:
            return .toast
        }
    }

    /// Patterns this event supersedes. Coordinator removes any queued event whose seenKey
    /// matches one of these patterns (wildcard support: "streak:*").
    var supersedesPatterns: [String] {
        switch self {
        case .journeyComplete:
            return ["chapterClear:*", "firstPerfect", "levels:*", "streak:*", "monthlyComplete:*"]
        case .monthlyComplete:
            return ["firstPerfect", "levels:*", "streak:*"]
        case .streakMilestone(let days):
            switch days {
            case 30: return ["streak:14", "streak:7"]
            case 14: return ["streak:7"]
            default: return []
            }
        case .levelCountMilestone(let count):
            switch count {
            case 100: return ["levels:50", "levels:10"]
            case 50: return ["levels:10"]
            default: return []
            }
        default:
            return []
        }
    }
}

enum CelebrationPresentationKind {
    case fullScreen
    case toast
}

extension String {
    /// Wildcard pattern match for celebration keys. "streak:*" matches any key starting with "streak:".
    /// Exact match otherwise.
    func celebrationMatches(pattern: String) -> Bool {
        if pattern.hasSuffix(":*") {
            let prefix = String(pattern.dropLast()) // "streak:"
            return hasPrefix(prefix)
        }
        return self == pattern
    }
}
