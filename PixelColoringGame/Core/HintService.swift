import Foundation

struct HintService {
    func hintCell(
        for selectedColorIndex: Int,
        level: LevelManifest,
        filledCells: Set<Int>
    ) -> Int? {
        level
            .cellIndices(for: selectedColorIndex)
            .first(where: { !filledCells.contains($0) })
    }

    func defaultSelectedColor(level: LevelManifest, filledCells: Set<Int>) -> Int {
        nextIncompleteColor(after: nil, level: level, filledCells: filledCells) ?? level.orderedPalette.first?.index ?? 0
    }

    func nextIncompleteColor(
        after currentColorIndex: Int?,
        level: LevelManifest,
        filledCells: Set<Int>
    ) -> Int? {
        let palette = level.orderedPalette
        guard !palette.isEmpty else { return nil }

        let orderedIndices = palette.map(\.index)
        let startOffset: Int
        if let currentColorIndex, let currentPosition = orderedIndices.firstIndex(of: currentColorIndex) {
            startOffset = currentPosition + 1
        } else {
            startOffset = 0
        }

        let rotated = Array(orderedIndices[startOffset...]) + orderedIndices[..<startOffset]
        return rotated.first(where: { colorIndex in
            level.cellIndices(for: colorIndex).contains(where: { !filledCells.contains($0) })
        })
    }
}
