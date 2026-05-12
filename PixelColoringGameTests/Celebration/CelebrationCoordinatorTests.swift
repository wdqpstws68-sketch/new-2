import XCTest
@testable import PixelColoringGame

@MainActor
final class CelebrationCoordinatorTests: XCTestCase {
    private final class SeenBox {
        var value: Set<String>
        init(_ initial: Set<String> = []) { value = initial }
    }

    private func makeCoordinator(initialSeen: Set<String> = []) -> (CelebrationCoordinator, SeenBox) {
        let box = SeenBox(initialSeen)
        let coordinator = CelebrationCoordinator(
            initialSeen: initialSeen,
            persist: { box.value = $0 }
        )
        return (coordinator, box)
    }

    func test_enqueue_singleFullScreen_setsCurrent() {
        let (coordinator, box) = makeCoordinator()
        coordinator.enqueue([.chapterClear(chapterID: "berry-meadow")])
        XCTAssertEqual(coordinator.currentFullScreenEvent, .chapterClear(chapterID: "berry-meadow"))
        XCTAssertNil(coordinator.currentToast)
        XCTAssertTrue(box.value.contains("chapterClear:berry-meadow"))
    }

    func test_enqueue_journeyComplete_supersedesAll() {
        let (coordinator, box) = makeCoordinator()
        coordinator.enqueue([
            .firstPerfect,
            .levelCountMilestone(count: 100),
            .chapterClear(chapterID: "berry-meadow"),
            .journeyComplete,
            .streakMilestone(days: 30)
        ])
        XCTAssertEqual(coordinator.currentFullScreenEvent, .journeyComplete)
        XCTAssertNil(coordinator.currentToast)
        // Journey ate everyone — all seenKeys saved
        XCTAssertTrue(box.value.contains("journeyComplete"))
        XCTAssertTrue(box.value.contains("chapterClear:berry-meadow"))
        XCTAssertTrue(box.value.contains("firstPerfect"))
        XCTAssertTrue(box.value.contains("levels:100"))
        XCTAssertTrue(box.value.contains("streak:30"))
    }

    func test_enqueue_streak30_supersedesStreak7And14() {
        let (coordinator, box) = makeCoordinator()
        coordinator.enqueue([
            .streakMilestone(days: 7),
            .streakMilestone(days: 14),
            .streakMilestone(days: 30)
        ])
        XCTAssertEqual(coordinator.currentToast, .streakMilestone(days: 30))
        XCTAssertTrue(box.value.contains("streak:7"))
        XCTAssertTrue(box.value.contains("streak:14"))
        XCTAssertTrue(box.value.contains("streak:30"))
    }

    func test_enqueue_levels100_supersedesLevels10And50() {
        let (coordinator, box) = makeCoordinator()
        coordinator.enqueue([
            .levelCountMilestone(count: 10),
            .levelCountMilestone(count: 50),
            .levelCountMilestone(count: 100)
        ])
        XCTAssertEqual(coordinator.currentToast, .levelCountMilestone(count: 100))
        XCTAssertTrue(box.value.contains("levels:10"))
        XCTAssertTrue(box.value.contains("levels:50"))
        XCTAssertTrue(box.value.contains("levels:100"))
    }

    func test_enqueue_duplicate_doesNotPresent() {
        let (coordinator, _) = makeCoordinator(initialSeen: ["firstPerfect"])
        coordinator.enqueue([.firstPerfect])
        XCTAssertNil(coordinator.currentToast)
        XCTAssertNil(coordinator.currentFullScreenEvent)
    }

    func test_dismissCurrent_advancesQueue() {
        let (coordinator, _) = makeCoordinator()
        coordinator.enqueue([
            .chapterClear(chapterID: "a"),
            .chapterClear(chapterID: "b")
        ])
        XCTAssertEqual(coordinator.currentFullScreenEvent, .chapterClear(chapterID: "a"))
        coordinator.dismissCurrent()
        XCTAssertEqual(coordinator.currentFullScreenEvent, .chapterClear(chapterID: "b"))
        coordinator.dismissCurrent()
        XCTAssertNil(coordinator.currentFullScreenEvent)
    }

    func test_isCompletionFlowActive() {
        let (coordinator, _) = makeCoordinator()
        XCTAssertFalse(coordinator.isCompletionFlowActive)
        coordinator.enqueue([.chapterClear(chapterID: "a")])
        XCTAssertTrue(coordinator.isCompletionFlowActive)
        coordinator.dismissCurrent()
        XCTAssertFalse(coordinator.isCompletionFlowActive)
    }

    func test_fullScreenAndToast_independentSlots() {
        let (coordinator, _) = makeCoordinator()
        coordinator.enqueue([
            .chapterClear(chapterID: "a"),
            .firstPerfect
        ])
        XCTAssertEqual(coordinator.currentFullScreenEvent, .chapterClear(chapterID: "a"))
        XCTAssertEqual(coordinator.currentToast, .firstPerfect)
    }
}
