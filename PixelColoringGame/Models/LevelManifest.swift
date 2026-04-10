import Foundation
import SwiftUI

struct LevelManifest: Codable, Identifiable, Hashable {
    let schemaVersion: Int
    let id: String
    let levelVersion: Int
    let title: String
    let prompt: String
    let boardWidth: Int
    let boardHeight: Int
    let difficulty: String
    let estimatedMinutes: Int
    let sortOrder: Int
    let category: String
    let paintableCellCount: Int
    let palette: [LevelPaletteEntry]
    let cells: [Int]
    let perColorCellIndices: [LevelColorCellIndexGroup]?
    let thumbnailAsset: String
    let solvedAsset: String

    var storageKey: String {
        "\(id)#\(levelVersion)"
    }

    var boardCellCount: Int {
        boardWidth * boardHeight
    }

    var paletteEntriesByIndex: [Int: LevelPaletteEntry] {
        Dictionary(uniqueKeysWithValues: palette.map { ($0.index, $0) })
    }

    var orderedPalette: [LevelPaletteEntry] {
        palette.sorted(by: { $0.index < $1.index })
    }

    func colorIndex(at cellIndex: Int) -> Int? {
        guard cells.indices.contains(cellIndex) else { return nil }
        let value = cells[cellIndex]
        return value >= 0 ? value : nil
    }

    func cellIndices(for colorIndex: Int) -> [Int] {
        if let grouped = perColorCellIndices?.first(where: { $0.index == colorIndex }) {
            return grouped.cellIndices
        }

        return cells.enumerated().compactMap { index, value in
            value == colorIndex ? index : nil
        }
    }
}

struct LevelPaletteEntry: Codable, Hashable, Identifiable {
    let index: Int
    let hex: String
    let targetCellCount: Int

    var id: Int { index }

    var color: Color {
        Color(hex: hex)
    }
}

struct LevelColorCellIndexGroup: Codable, Hashable {
    let index: Int
    let cellIndices: [Int]
}
