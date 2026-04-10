import Foundation
import Observation

@MainActor
@Observable
final class GameSessionStore {
    enum TapOutcome: Equatable {
        case ignored
        case alreadyFilled
        case incorrect
        case correct
    }

    struct PaletteChipState: Identifiable {
        let entry: LevelPaletteEntry
        let remainingCount: Int
        let isSelected: Bool
        let isCompleted: Bool

        var id: Int { entry.index }
    }

    let level: LevelManifest
    private let hintService: HintService

    var filledCells: Set<Int>
    var selectedColorIndex: Int
    var highlightedIncorrectCell: Int?
    var bannerText: String?
    var completedAt: Date?
    var saveRevision = 0

    init(level: LevelManifest, progress: LevelProgress?, hintService: HintService = HintService()) {
        self.level = level
        self.hintService = hintService
        let restoredFilledCells = FilledCellsCodec.decode(progress?.filledCellsData ?? Data(), cellCount: level.boardCellCount)
        self.filledCells = restoredFilledCells
        self.completedAt = progress?.completedAt
        self.selectedColorIndex = progress?.activeColorIndex ?? hintService.defaultSelectedColor(level: level, filledCells: restoredFilledCells)
        normalizeSelectedColor()
    }

    var completionRatio: Double {
        guard level.paintableCellCount > 0 else { return 0 }
        return Double(filledCells.count) / Double(level.paintableCellCount)
    }

    var completionLabel: String {
        "\(filledCells.count)/\(level.paintableCellCount)"
    }

    var isCompleted: Bool {
        filledCells.count >= level.paintableCellCount
    }

    var encodedFilledCells: Data {
        FilledCellsCodec.encode(filledCells, cellCount: level.boardCellCount)
    }

    var paletteStates: [PaletteChipState] {
        level.orderedPalette.map { entry in
            let remaining = remainingCount(for: entry.index)
            return PaletteChipState(
                entry: entry,
                remainingCount: remaining,
                isSelected: selectedColorIndex == entry.index,
                isCompleted: remaining == 0
            )
        }
    }

    func remainingCount(for colorIndex: Int) -> Int {
        level
            .cellIndices(for: colorIndex)
            .count(where: { !filledCells.contains($0) })
    }

    func tapCell(at index: Int) -> TapOutcome {
        guard let expectedColor = level.colorIndex(at: index) else {
            return .ignored
        }

        guard !filledCells.contains(index) else {
            return .alreadyFilled
        }

        guard expectedColor == selectedColorIndex else {
            highlightedIncorrectCell = index
            return .incorrect
        }

        filledCells.insert(index)
        highlightedIncorrectCell = nil
        saveRevision += 1

        if remainingCount(for: selectedColorIndex) == 0 {
            bannerText = "Color \(selectedColorIndex + 1) complete!"
            selectedColorIndex = hintService.nextIncompleteColor(after: selectedColorIndex, level: level, filledCells: filledCells)
                ?? selectedColorIndex
        }

        if isCompleted {
            completedAt = Date()
            bannerText = "Artwork complete!"
        }

        normalizeSelectedColor()
        return .correct
    }

    @discardableResult
    func applyHint() -> Int? {
        if remainingCount(for: selectedColorIndex) == 0,
           let nextColor = hintService.nextIncompleteColor(after: selectedColorIndex, level: level, filledCells: filledCells) {
            selectedColorIndex = nextColor
        }

        guard let hintCell = hintService.hintCell(for: selectedColorIndex, level: level, filledCells: filledCells) else {
            return nil
        }

        _ = tapCell(at: hintCell)
        bannerText = "Hint placed for color \(selectedColorIndex + 1)"
        return hintCell
    }

    func selectColor(_ colorIndex: Int) {
        selectedColorIndex = colorIndex
        normalizeSelectedColor()
    }

    func clearHighlightedIncorrectCell() {
        highlightedIncorrectCell = nil
    }

    func clearBanner() {
        bannerText = nil
    }

    private func normalizeSelectedColor() {
        guard remainingCount(for: selectedColorIndex) == 0,
              let nextColor = hintService.nextIncompleteColor(after: selectedColorIndex, level: level, filledCells: filledCells) else {
            return
        }
        selectedColorIndex = nextColor
    }
}
