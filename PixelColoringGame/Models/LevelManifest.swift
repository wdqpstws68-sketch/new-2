import Foundation
import SwiftUI

struct LevelManifest: Decodable, Identifiable, Hashable {
    let schemaVersion: Int
    let id: String
    let levelVersion: Int
    let titleKey: String
    let prompt: String
    let boardWidth: Int
    let boardHeight: Int
    let difficultyKey: String
    let estimatedMinutes: Int
    let sortOrder: Int
    let categoryKey: String
    let paintableCellCount: Int
    let palette: [LevelPaletteEntry]
    let cells: [Int]
    let perColorCellIndices: [LevelColorCellIndexGroup]?
    let thumbnailAsset: String
    let solvedAsset: String

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case levelVersion
        case title
        case titleKey
        case prompt
        case boardWidth
        case boardHeight
        case difficulty
        case difficultyKey
        case estimatedMinutes
        case sortOrder
        case category
        case categoryKey
        case paintableCellCount
        case palette
        case cells
        case perColorCellIndices
        case thumbnailAsset
        case solvedAsset
    }

    init(
        schemaVersion: Int,
        id: String,
        levelVersion: Int,
        titleKey: String,
        prompt: String,
        boardWidth: Int,
        boardHeight: Int,
        difficultyKey: String,
        estimatedMinutes: Int,
        sortOrder: Int,
        categoryKey: String,
        paintableCellCount: Int,
        palette: [LevelPaletteEntry],
        cells: [Int],
        perColorCellIndices: [LevelColorCellIndexGroup]?,
        thumbnailAsset: String,
        solvedAsset: String
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.levelVersion = levelVersion
        self.titleKey = titleKey
        self.prompt = prompt
        self.boardWidth = boardWidth
        self.boardHeight = boardHeight
        self.difficultyKey = difficultyKey
        self.estimatedMinutes = estimatedMinutes
        self.sortOrder = sortOrder
        self.categoryKey = categoryKey
        self.paintableCellCount = paintableCellCount
        self.palette = palette
        self.cells = cells
        self.perColorCellIndices = perColorCellIndices
        self.thumbnailAsset = thumbnailAsset
        self.solvedAsset = solvedAsset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        levelVersion = try container.decode(Int.self, forKey: .levelVersion)
        titleKey = try container.decodeIfPresent(String.self, forKey: .titleKey)
            ?? container.decode(String.self, forKey: .title)
        prompt = try container.decode(String.self, forKey: .prompt)
        boardWidth = try container.decode(Int.self, forKey: .boardWidth)
        boardHeight = try container.decode(Int.self, forKey: .boardHeight)
        difficultyKey = try container.decodeIfPresent(String.self, forKey: .difficultyKey)
            ?? container.decode(String.self, forKey: .difficulty)
        estimatedMinutes = try container.decode(Int.self, forKey: .estimatedMinutes)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        categoryKey = try container.decodeIfPresent(String.self, forKey: .categoryKey)
            ?? container.decode(String.self, forKey: .category)
        paintableCellCount = try container.decode(Int.self, forKey: .paintableCellCount)
        palette = try container.decode([LevelPaletteEntry].self, forKey: .palette)
        cells = try container.decode([Int].self, forKey: .cells)
        perColorCellIndices = try container.decodeIfPresent([LevelColorCellIndexGroup].self, forKey: .perColorCellIndices)
        thumbnailAsset = try container.decode(String.self, forKey: .thumbnailAsset)
        solvedAsset = try container.decode(String.self, forKey: .solvedAsset)
    }

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

    func localizedTitle(using localization: AppLocalization) -> String {
        localization.string(titleKey)
    }

    func localizedDifficulty(using localization: AppLocalization) -> String {
        localization.string(difficultyKey)
    }

    func localizedCategory(using localization: AppLocalization) -> String {
        localization.string(categoryKey)
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
