import XCTest
@testable import PixelColoringGame

@MainActor
final class GameSessionStoreTests: XCTestCase {
    func testCorrectTapCompletesColorAndAutoAdvances() {
        let level = makeLevel()
        let store = GameSessionStore(level: level, progress: nil)

        XCTAssertEqual(store.selectedColorIndex, 0)

        XCTAssertEqual(store.tapCell(at: 0), .correct)
        XCTAssertEqual(store.tapCell(at: 1), .correct)
        XCTAssertEqual(store.remainingCount(for: 0), 0)
        XCTAssertEqual(store.selectedColorIndex, 1)
        XCTAssertEqual(store.filledCells.count, 2)
    }

    func testIncorrectTapLeavesBoardUntouched() {
        let level = makeLevel()
        let store = GameSessionStore(level: level, progress: nil)

        XCTAssertEqual(store.tapCell(at: 2), .incorrect)
        XCTAssertTrue(store.filledCells.isEmpty)
        XCTAssertEqual(store.highlightedIncorrectCell, 2)
    }

    func testHintFillsNextCellForSelectedColor() {
        let level = makeLevel()
        let store = GameSessionStore(level: level, progress: nil)

        let hintedCell = store.applyHint()

        XCTAssertEqual(hintedCell, 0)
        XCTAssertTrue(store.filledCells.contains(0))
        XCTAssertEqual(store.remainingCount(for: 0), 1)
    }

    func testCompletionSetsCompletedAt() {
        let level = makeLevel()
        let store = GameSessionStore(level: level, progress: nil)

        _ = store.tapCell(at: 0)
        _ = store.tapCell(at: 1)
        _ = store.tapCell(at: 2)
        _ = store.tapCell(at: 3)

        XCTAssertTrue(store.isCompleted)
        XCTAssertNotNil(store.completedAt)
    }

    private func makeLevel() -> LevelManifest {
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
                LevelPaletteEntry(index: 0, hex: "#FF0000", targetCellCount: 2),
                LevelPaletteEntry(index: 1, hex: "#00FF00", targetCellCount: 2)
            ],
            cells: [0, 0, 1, 1],
            perColorCellIndices: [
                LevelColorCellIndexGroup(index: 0, cellIndices: [0, 1]),
                LevelColorCellIndexGroup(index: 1, cellIndices: [2, 3])
            ],
            thumbnailAsset: "test-thumb",
            solvedAsset: "test-solved"
        )
    }
}
