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

    func testLegacyStoreMigratesProgressIntoCurrentSchema() throws {
        let storeURL = try makeStoreURL(name: "legacy-migration")
        let legacySchema = Schema(versionedSchema: PixelColoringGameSchemaV1.self)
        let legacyConfiguration = ModelConfiguration(
            "Legacy",
            schema: legacySchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let legacyContainer = try ModelContainer(for: legacySchema, configurations: [legacyConfiguration])
        let legacyContext = ModelContext(legacyContainer)
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_123)
        let legacyProgress = PixelColoringGameSchemaV1.LevelProgress(
            storageKey: "alpha#1",
            levelID: "alpha",
            levelVersion: 1,
            filledCellsData: Data([1, 0, 1, 0]),
            filledCellCount: 2,
            activeColorIndex: 0,
            completedAt: completedAt,
            updatedAt: updatedAt
        )
        legacyContext.insert(legacyProgress)
        try legacyContext.save()

        let migratedContainer = try PixelColoringGamePersistence.makeContainer(at: storeURL)
        let migratedContext = ModelContext(migratedContainer)
        let records = try migratedContext.fetch(FetchDescriptor<LevelProgress>())
        let record = try XCTUnwrap(records.first)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record.storageKey, "alpha#1")
        XCTAssertEqual(record.completedAt, completedAt)
        XCTAssertEqual(record.firstCompletedAt, completedAt)
        XCTAssertEqual(record.lastPlayedAt, updatedAt)
        XCTAssertEqual(record.hintCount, 0)
        XCTAssertEqual(record.incorrectPaintAttemptCount, 0)
        XCTAssertEqual(record.bestCompletionRankRaw, CompletionRank.normal.rawValue)
        XCTAssertEqual(record.filledCellsData, Data([1, 0, 1, 0]))
    }

    func testPersistedCompletedArtworkSurvivesContainerReload() throws {
        let storeURL = try makeStoreURL(name: "progress-reload")
        let container = try PixelColoringGamePersistence.makeContainer(at: storeURL)
        let context = ModelContext(container)
        let level = makeTestLevel()
        let session = GameSessionStore(level: level, progress: nil)
        _ = session.tapCell(at: 0)
        _ = session.tapCell(at: 1)
        _ = session.tapCell(at: 2)
        _ = session.tapCell(at: 3)

        let progressStore = ProgressStore()
        _ = try progressStore.persist(session: session, existingProgress: nil, in: context)

        let reloadedContainer = try PixelColoringGamePersistence.makeContainer(at: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let records = try reloadedContext.fetch(FetchDescriptor<LevelProgress>())
        let record = try XCTUnwrap(records.first)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record.storageKey, level.storageKey)
        XCTAssertEqual(record.filledCellCount, level.paintableCellCount)
        XCTAssertNotNil(record.completedAt)
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

    private func makeTestLevel() -> LevelManifest {
        LevelManifest(
            schemaVersion: 2,
            id: "test-level",
            levelVersion: 1,
            titleKey: "level.test.title",
            prompt: "Test",
            boardWidth: 2,
            boardHeight: 2,
            difficultyKey: "level.difficulty.easy",
            estimatedMinutes: 1,
            sortOrder: 0,
            categoryKey: "level.category.test",
            paintableCellCount: 4,
            palette: [
                LevelPaletteEntry(index: 0, hex: "#FF0000", targetCellCount: 4)
            ],
            cells: [0, 0, 0, 0],
            perColorCellIndices: [
                LevelColorCellIndexGroup(index: 0, cellIndices: [0, 1, 2, 3])
            ],
            thumbnailAsset: "test-thumb",
            solvedAsset: "test-solved"
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

    private func makeStoreURL(name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "JourneyResetCoordinatorTests.\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("\(name).store")
    }
}
