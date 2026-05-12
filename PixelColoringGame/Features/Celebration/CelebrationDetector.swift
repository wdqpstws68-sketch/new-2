import Foundation

struct PlayerProfileSnapshot {
    let completedLevelCount: Int
    let perfectLevelCount: Int
    let currentStreakDays: Int
    let completedChapterIDs: Set<String>
    let isJourneyComplete: Bool
    let lastLevelChapterID: String?
    let lastLevelWasPerfect: Bool
    let lastLevelWasChapterFinalLevel: Bool
    let monthlyCompletedYearMonth: String?
}

enum CelebrationTrigger {
    case levelCompleted(profileSnapshot: PlayerProfileSnapshot)
    case dailyCompleted(profileSnapshot: PlayerProfileSnapshot)
    case appLaunched(profileSnapshot: PlayerProfileSnapshot)
}

enum CelebrationDetector {
    static func detect(
        trigger: CelebrationTrigger,
        seen: Set<String>
    ) -> [CelebrationEvent] {
        switch trigger {
        case .levelCompleted(let snapshot):
            return detectLevelCompleted(snapshot: snapshot, seen: seen)
        case .dailyCompleted(let snapshot):
            return detectDailyCompleted(snapshot: snapshot, seen: seen)
        case .appLaunched(let snapshot):
            return detectAppLaunched(snapshot: snapshot, seen: seen)
        }
    }

    private static func detectLevelCompleted(
        snapshot s: PlayerProfileSnapshot,
        seen: Set<String>
    ) -> [CelebrationEvent] {
        var out: [CelebrationEvent] = []

        if s.isJourneyComplete, !seen.contains("journeyComplete") {
            out.append(.journeyComplete)
        }

        if s.lastLevelWasChapterFinalLevel, let chapterID = s.lastLevelChapterID {
            let key = "chapterClear:\(chapterID)"
            if !seen.contains(key) {
                out.append(.chapterClear(chapterID: chapterID))
            }
        }

        if s.lastLevelWasPerfect, !seen.contains("firstPerfect") {
            out.append(.firstPerfect)
        }

        for threshold in [10, 50, 100] where s.completedLevelCount >= threshold {
            let key = "levels:\(threshold)"
            if !seen.contains(key) {
                out.append(.levelCountMilestone(count: threshold))
            }
        }

        return out
    }

    private static func detectDailyCompleted(
        snapshot s: PlayerProfileSnapshot,
        seen: Set<String>
    ) -> [CelebrationEvent] {
        var out: [CelebrationEvent] = []

        if let ym = s.monthlyCompletedYearMonth {
            let key = "monthlyComplete:\(ym)"
            if !seen.contains(key) {
                out.append(.monthlyComplete(yearMonth: ym))
            }
        }

        for threshold in [7, 14, 30] where s.currentStreakDays >= threshold {
            let key = "streak:\(threshold)"
            if !seen.contains(key) {
                out.append(.streakMilestone(days: threshold))
            }
        }

        if s.lastLevelWasPerfect, !seen.contains("firstPerfect") {
            out.append(.firstPerfect)
        }

        for threshold in [10, 50, 100] where s.completedLevelCount >= threshold {
            let key = "levels:\(threshold)"
            if !seen.contains(key) {
                out.append(.levelCountMilestone(count: threshold))
            }
        }

        return out
    }

    private static func detectAppLaunched(
        snapshot s: PlayerProfileSnapshot,
        seen: Set<String>
    ) -> [CelebrationEvent] {
        // Spec: appLaunched detects streak only — completion-derived events fire from their own triggers.
        var out: [CelebrationEvent] = []
        for threshold in [7, 14, 30] where s.currentStreakDays >= threshold {
            let key = "streak:\(threshold)"
            if !seen.contains(key) {
                out.append(.streakMilestone(days: threshold))
            }
        }
        return out
    }
}
