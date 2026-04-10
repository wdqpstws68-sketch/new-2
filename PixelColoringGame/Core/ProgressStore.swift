import Foundation
import SwiftData

@MainActor
struct ProgressStore {
    func record(for level: LevelManifest, in records: [LevelProgress]) -> LevelProgress? {
        records.first(where: { $0.storageKey == level.storageKey })
    }

    func lookup(from records: [LevelProgress]) -> [String: LevelProgress] {
        Dictionary(uniqueKeysWithValues: records.map { ($0.storageKey, $0) })
    }

    @discardableResult
    func persist(
        session: GameSessionStore,
        existingProgress: LevelProgress?,
        in context: ModelContext
    ) throws -> LevelProgress {
        let progress = existingProgress ?? LevelProgress(
            storageKey: session.level.storageKey,
            levelID: session.level.id,
            levelVersion: session.level.levelVersion,
            filledCellsData: Data(),
            filledCellCount: 0,
            activeColorIndex: nil,
            completedAt: nil,
            updatedAt: .now
        )

        progress.filledCellsData = session.encodedFilledCells
        progress.filledCellCount = session.filledCells.count
        progress.activeColorIndex = session.selectedColorIndex
        progress.completedAt = session.completedAt
        progress.updatedAt = .now

        if existingProgress == nil {
            context.insert(progress)
        }

        try context.save()
        return progress
    }
}
