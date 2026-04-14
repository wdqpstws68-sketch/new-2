import XCTest
@testable import PixelColoringGame

@MainActor
final class DailyExperienceTests: XCTestCase {
    func testChallengePrefersUnfinishedLevels() throws {
        let levels = [
            makeLevel(id: "daily-a", sortOrder: 1),
            makeLevel(id: "daily-b", sortOrder: 2),
            makeLevel(id: "daily-c", sortOrder: 3),
        ]
        let repository = makeRepository(levels: levels)

        let challenge = try XCTUnwrap(
            repository.challenge(
                for: makeDate("2026-04-13"),
                completedStorageKeys: [levels[0].storageKey, levels[1].storageKey]
            )
        )

        XCTAssertEqual(challenge.level.storageKey, levels[2].storageKey)
    }

    func testChallengeKeepsPinnedArtworkForSameDay() throws {
        let levels = [
            makeLevel(id: "daily-a", sortOrder: 1),
            makeLevel(id: "daily-b", sortOrder: 2),
            makeLevel(id: "daily-c", sortOrder: 3),
        ]
        let repository = makeRepository(levels: levels)

        let challenge = try XCTUnwrap(
            repository.challenge(
                for: makeDate("2026-04-13"),
                completedStorageKeys: [levels[1].storageKey],
                pinnedStorageKey: levels[1].storageKey
            )
        )

        XCTAssertEqual(challenge.level.storageKey, levels[1].storageKey)
    }

    private func makeRepository(levels: [LevelManifest]) -> DailyChallengeRepository {
        let catalog = DailyCatalogManifest(
            titleKey: "daily.catalog.title",
            subtitleKey: "daily.catalog.subtitle",
            albumTitleKey: "daily.catalog.albumTitle",
            referenceDate: "2026-01-01",
            dailyLevelKeys: levels.map(\.storageKey)
        )

        return DailyChallengeRepository(
            levelRepository: LevelRepository(bundle: .main, levels: levels),
            catalog: catalog,
            events: []
        )
    }

    private func makeLevel(id: String, sortOrder: Int) -> LevelManifest {
        LevelManifest(
            schemaVersion: 2,
            id: id,
            levelVersion: 1,
            titleKey: "level.\(id).title",
            prompt: id,
            boardWidth: 2,
            boardHeight: 2,
            difficultyKey: "level.difficulty.daily",
            estimatedMinutes: 3,
            sortOrder: sortOrder,
            categoryKey: "level.category.daily",
            paintableCellCount: 4,
            palette: [
                LevelPaletteEntry(index: 0, hex: "#FFAA00", targetCellCount: 4)
            ],
            cells: [0, 0, 0, 0],
            perColorCellIndices: [
                LevelColorCellIndexGroup(index: 0, cellIndices: [0, 1, 2, 3])
            ],
            thumbnailAsset: "\(id)-thumb",
            solvedAsset: "\(id)-solved"
        )
    }

    private func makeDate(_ dayKey: String) -> Date {
        DayKey.date(from: dayKey) ?? .now
    }
}
