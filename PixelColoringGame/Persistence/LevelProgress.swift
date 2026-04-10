import Foundation
import SwiftData

@Model
final class LevelProgress {
    @Attribute(.unique) var storageKey: String
    var levelID: String
    var levelVersion: Int
    var filledCellsData: Data
    var filledCellCount: Int
    var activeColorIndex: Int?
    var completedAt: Date?
    var updatedAt: Date

    init(
        storageKey: String,
        levelID: String,
        levelVersion: Int,
        filledCellsData: Data,
        filledCellCount: Int,
        activeColorIndex: Int?,
        completedAt: Date?,
        updatedAt: Date
    ) {
        self.storageKey = storageKey
        self.levelID = levelID
        self.levelVersion = levelVersion
        self.filledCellsData = filledCellsData
        self.filledCellCount = filledCellCount
        self.activeColorIndex = activeColorIndex
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }
}
