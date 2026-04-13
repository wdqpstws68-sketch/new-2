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

    enum Banner: Equatable {
        case colorCompleted(colorIndex: Int)
        case artworkCompleted
        case hintPlaced(colorIndex: Int)

        func text(using localization: AppLocalization) -> String {
            switch self {
            case let .colorCompleted(colorIndex):
                return localization.string("game.banner.colorComplete", colorIndex + 1)
            case .artworkCompleted:
                return localization.string("game.banner.artworkComplete")
            case let .hintPlaced(colorIndex):
                return localization.string("game.banner.hintPlaced", colorIndex + 1)
            }
        }
    }

    let level: LevelManifest
    private let hintService: HintService

    var filledCells: Set<Int>
    var selectedColorIndex: Int
    var highlightedIncorrectCell: Int?
    var banner: Banner?
    var completedAt: Date?
    var hintCount = 0
    var incorrectPaintAttemptCount = 0
    var saveRevision = 0

    init(
        level: LevelManifest,
        progress: LevelProgress?,
        hintService: HintService = HintService(),
        startFresh: Bool = false
    ) {
        self.level = level
        self.hintService = hintService
        let restoredFilledCells = startFresh
            ? Set<Int>()
            : FilledCellsCodec.decode(progress?.filledCellsData ?? Data(), cellCount: level.boardCellCount)
        self.filledCells = restoredFilledCells
        self.completedAt = startFresh ? nil : progress?.completedAt
        self.hintCount = startFresh ? 0 : (progress?.hintCount ?? 0)
        self.incorrectPaintAttemptCount = startFresh ? 0 : (progress?.incorrectPaintAttemptCount ?? 0)
        self.selectedColorIndex = startFresh
            ? hintService.defaultSelectedColor(level: level, filledCells: restoredFilledCells)
            : (progress?.activeColorIndex ?? hintService.defaultSelectedColor(level: level, filledCells: restoredFilledCells))
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

    var completionRank: CompletionRank {
        guard isCompleted, hintCount == 0, incorrectPaintAttemptCount == 0 else {
            return .normal
        }
        return .perfect
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
            incorrectPaintAttemptCount += 1
            return .incorrect
        }

        filledCells.insert(index)
        highlightedIncorrectCell = nil
        saveRevision += 1

        if remainingCount(for: selectedColorIndex) == 0 {
            banner = .colorCompleted(colorIndex: selectedColorIndex)
            selectedColorIndex = hintService.nextIncompleteColor(after: selectedColorIndex, level: level, filledCells: filledCells)
                ?? selectedColorIndex
        }

        if isCompleted {
            completedAt = Date()
            banner = .artworkCompleted
        }

        normalizeSelectedColor()
        return .correct
    }

    @discardableResult
    func applyHint() -> Int? {
        let hintedColorIndex = selectedColorIndex

        if remainingCount(for: selectedColorIndex) == 0,
           let nextColor = hintService.nextIncompleteColor(after: selectedColorIndex, level: level, filledCells: filledCells) {
            selectedColorIndex = nextColor
        }

        guard let hintCell = hintService.hintCell(for: selectedColorIndex, level: level, filledCells: filledCells) else {
            return nil
        }

        _ = tapCell(at: hintCell)
        hintCount += 1
        banner = .hintPlaced(colorIndex: hintedColorIndex)
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
        banner = nil
    }

    private func normalizeSelectedColor() {
        guard remainingCount(for: selectedColorIndex) == 0,
              let nextColor = hintService.nextIncompleteColor(after: selectedColorIndex, level: level, filledCells: filledCells) else {
            return
        }
        selectedColorIndex = nextColor
    }
}
