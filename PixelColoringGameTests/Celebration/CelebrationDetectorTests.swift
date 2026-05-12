import XCTest
@testable import PixelColoringGame

final class CelebrationDetectorTests: XCTestCase {
    private func snapshot(
        completedLevels: Int = 0,
        perfectLevels: Int = 0,
        streak: Int = 0,
        completedChapters: Set<String> = [],
        journeyComplete: Bool = false,
        lastChapter: String? = nil,
        lastPerfect: Bool = false,
        lastWasChapterFinal: Bool = false,
        monthlyCompleted: String? = nil
    ) -> PlayerProfileSnapshot {
        PlayerProfileSnapshot(
            completedLevelCount: completedLevels,
            perfectLevelCount: perfectLevels,
            currentStreakDays: streak,
            completedChapterIDs: completedChapters,
            isJourneyComplete: journeyComplete,
            lastLevelChapterID: lastChapter,
            lastLevelWasPerfect: lastPerfect,
            lastLevelWasChapterFinalLevel: lastWasChapterFinal,
            monthlyCompletedYearMonth: monthlyCompleted
        )
    }

    // MARK: levelCompleted

    func test_levelCompleted_firstPerfect_detectedWhenFirstTime() {
        let snap = snapshot(perfectLevels: 1, lastPerfect: true)
        let events = CelebrationDetector.detect(
            trigger: .levelCompleted(profileSnapshot: snap),
            seen: []
        )
        XCTAssertTrue(events.contains(.firstPerfect))
    }

    func test_levelCompleted_firstPerfect_skippedIfSeen() {
        let snap = snapshot(perfectLevels: 1, lastPerfect: true)
        let events = CelebrationDetector.detect(
            trigger: .levelCompleted(profileSnapshot: snap),
            seen: ["firstPerfect"]
        )
        XCTAssertFalse(events.contains(.firstPerfect))
    }

    func test_levelCompleted_chapterClear_detected() {
        let snap = snapshot(
            lastChapter: "berry-meadow",
            lastWasChapterFinal: true
        )
        let events = CelebrationDetector.detect(
            trigger: .levelCompleted(profileSnapshot: snap),
            seen: []
        )
        XCTAssertTrue(events.contains(.chapterClear(chapterID: "berry-meadow")))
    }

    func test_levelCompleted_chapterClear_skippedIfSeen() {
        let snap = snapshot(
            lastChapter: "berry-meadow",
            lastWasChapterFinal: true
        )
        let events = CelebrationDetector.detect(
            trigger: .levelCompleted(profileSnapshot: snap),
            seen: ["chapterClear:berry-meadow"]
        )
        XCTAssertFalse(events.contains(.chapterClear(chapterID: "berry-meadow")))
    }

    func test_levelCompleted_levels10_atExact10() {
        let snap = snapshot(completedLevels: 10)
        let events = CelebrationDetector.detect(
            trigger: .levelCompleted(profileSnapshot: snap),
            seen: []
        )
        XCTAssertTrue(events.contains(.levelCountMilestone(count: 10)))
    }

    func test_levelCompleted_levels9_doesNotEmit() {
        let snap = snapshot(completedLevels: 9)
        let events = CelebrationDetector.detect(
            trigger: .levelCompleted(profileSnapshot: snap),
            seen: []
        )
        XCTAssertFalse(events.contains(.levelCountMilestone(count: 10)))
    }

    func test_levelCompleted_levels100_returnsAll10_50_100() {
        let snap = snapshot(completedLevels: 100)
        let events = CelebrationDetector.detect(
            trigger: .levelCompleted(profileSnapshot: snap),
            seen: []
        )
        XCTAssertTrue(events.contains(.levelCountMilestone(count: 10)))
        XCTAssertTrue(events.contains(.levelCountMilestone(count: 50)))
        XCTAssertTrue(events.contains(.levelCountMilestone(count: 100)))
    }

    func test_levelCompleted_journeyComplete_detected() {
        let snap = snapshot(journeyComplete: true)
        let events = CelebrationDetector.detect(
            trigger: .levelCompleted(profileSnapshot: snap),
            seen: []
        )
        XCTAssertTrue(events.contains(.journeyComplete))
    }

    // MARK: dailyCompleted

    func test_dailyCompleted_streak7_atExactSeven() {
        let snap = snapshot(streak: 7)
        let events = CelebrationDetector.detect(
            trigger: .dailyCompleted(profileSnapshot: snap),
            seen: []
        )
        XCTAssertTrue(events.contains(.streakMilestone(days: 7)))
    }

    func test_dailyCompleted_streak6_doesNotEmit() {
        let snap = snapshot(streak: 6)
        let events = CelebrationDetector.detect(
            trigger: .dailyCompleted(profileSnapshot: snap),
            seen: []
        )
        XCTAssertFalse(events.contains(.streakMilestone(days: 7)))
    }

    func test_dailyCompleted_monthlyComplete_detected() {
        let snap = snapshot(monthlyCompleted: "2026-04")
        let events = CelebrationDetector.detect(
            trigger: .dailyCompleted(profileSnapshot: snap),
            seen: []
        )
        XCTAssertTrue(events.contains(.monthlyComplete(yearMonth: "2026-04")))
    }

    // MARK: appLaunched

    func test_appLaunched_returnsOnlyStreak() {
        let snap = snapshot(
            completedLevels: 100,
            perfectLevels: 1,
            streak: 7,
            lastPerfect: true,
            lastWasChapterFinal: true
        )
        let events = CelebrationDetector.detect(
            trigger: .appLaunched(profileSnapshot: snap),
            seen: []
        )
        XCTAssertFalse(events.contains(.firstPerfect))
        XCTAssertFalse(events.contains(.levelCountMilestone(count: 10)))
        XCTAssertTrue(events.contains(.streakMilestone(days: 7)))
    }

    // MARK: idempotent

    func test_idempotent_sameInput_sameOutput() {
        let snap = snapshot(completedLevels: 50, streak: 14)
        let a = CelebrationDetector.detect(trigger: .dailyCompleted(profileSnapshot: snap), seen: [])
        let b = CelebrationDetector.detect(trigger: .dailyCompleted(profileSnapshot: snap), seen: [])
        XCTAssertEqual(Set(a), Set(b))
    }
}
