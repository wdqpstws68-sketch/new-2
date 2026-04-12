import SwiftData
import XCTest
@testable import PixelColoringGame

@MainActor
final class JourneyResetCoordinatorTests: XCTestCase {
    func testResetDeletesProgressAndShowsNoticeOnce() throws {
        let defaults = makeDefaults()
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(makeProgress(storageKey: "alpha#1"))
        context.insert(makeProgress(storageKey: "beta#1"))
        try context.save()

        let coordinator = JourneyResetCoordinator(defaults: defaults, schemaVersion: 11)
        let firstResult = try coordinator.applyIfNeeded(in: context)

        XCTAssertTrue(firstResult.didApply)
        XCTAssertEqual(firstResult.deletedCount, 2)
        XCTAssertTrue(firstResult.shouldShowNotice)
        XCTAssertTrue(try context.fetch(FetchDescriptor<LevelProgress>()).isEmpty)

        let secondResult = try coordinator.applyIfNeeded(in: context)

        XCTAssertFalse(secondResult.didApply)
        XCTAssertEqual(secondResult.deletedCount, 0)
        XCTAssertFalse(secondResult.shouldShowNotice)
    }

    func testResetWithoutExistingProgressIsIdempotent() throws {
        let defaults = makeDefaults()
        let container = try makeContainer()
        let context = ModelContext(container)
        let coordinator = JourneyResetCoordinator(defaults: defaults, schemaVersion: 12)

        let firstResult = try coordinator.applyIfNeeded(in: context)
        let secondResult = try coordinator.applyIfNeeded(in: context)

        XCTAssertTrue(firstResult.didApply)
        XCTAssertEqual(firstResult.deletedCount, 0)
        XCTAssertFalse(firstResult.shouldShowNotice)
        XCTAssertFalse(secondResult.didApply)
    }

    func testPendingNoticeCanBeConsumedAfterInterruptedLaunch() throws {
        let defaults = makeDefaults()
        defaults.set(13, forKey: JourneyResetCoordinator.appliedSchemaKey)
        defaults.set(13, forKey: JourneyResetCoordinator.pendingNoticeSchemaKey)

        let coordinator = JourneyResetCoordinator(defaults: defaults, schemaVersion: 13)
        let container = try makeContainer()
        let context = ModelContext(container)
        let result = try coordinator.applyIfNeeded(in: context)

        XCTAssertFalse(result.didApply)
        XCTAssertTrue(result.shouldShowNotice)
        XCTAssertEqual(defaults.integer(forKey: JourneyResetCoordinator.pendingNoticeSchemaKey), 0)
    }

    func testRetryAfterDeleteBeforeSchemaFlagSaveDoesNotShowNoticeAgain() throws {
        let defaults = makeDefaults()
        let container = try makeContainer()
        let context = ModelContext(container)
        let coordinator = JourneyResetCoordinator(defaults: defaults, schemaVersion: 14)

        let result = try coordinator.applyIfNeeded(in: context)

        XCTAssertTrue(result.didApply)
        XCTAssertEqual(result.deletedCount, 0)
        XCTAssertFalse(result.shouldShowNotice)
        XCTAssertEqual(defaults.integer(forKey: JourneyResetCoordinator.appliedSchemaKey), 14)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: LevelProgress.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeProgress(storageKey: String) -> LevelProgress {
        LevelProgress(
            storageKey: storageKey,
            levelID: storageKey,
            levelVersion: 1,
            filledCellsData: Data([1, 0, 1, 0]),
            filledCellCount: 2,
            activeColorIndex: 0,
            completedAt: nil,
            updatedAt: .now
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "JourneyResetCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
