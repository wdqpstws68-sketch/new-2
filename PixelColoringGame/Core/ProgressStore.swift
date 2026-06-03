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
            hintCount: 0,
            incorrectPaintAttemptCount: 0,
            firstCompletedAt: nil,
            completedAt: nil,
            lastPlayedAt: nil,
            bestCompletionRankRaw: CompletionRank.normal.rawValue,
            updatedAt: .now
        )

        progress.filledCellsData = session.encodedFilledCells
        progress.filledCellCount = session.filledCells.count
        progress.activeColorIndex = session.selectedColorIndex
        progress.hintCount = session.hintCount
        progress.incorrectPaintAttemptCount = session.incorrectPaintAttemptCount
        progress.firstCompletedAt = progress.firstCompletedAt ?? progress.completedAt
        progress.completedAt = session.completedAt
        progress.lastPlayedAt = .now
        progress.updatedAt = .now

        if progress.firstCompletedAt == nil, session.isCompleted {
            progress.firstCompletedAt = session.completedAt ?? .now
        }
        if session.isCompleted {
            progress.bestCompletionRank = max(progress.bestCompletionRank, session.completionRank)
        }

        if existingProgress == nil {
            context.insert(progress)
        }

        try context.save()
        return progress
    }

    /// Mark a level as "entered" by ensuring a progress record exists, without touching
    /// painted state. Used so re-entering an already-opened stage does not re-consume a life.
    @discardableResult
    func markEntered(
        level: LevelManifest,
        existingProgress: LevelProgress?,
        in context: ModelContext
    ) throws -> LevelProgress {
        if let existingProgress {
            existingProgress.lastPlayedAt = .now
            existingProgress.updatedAt = .now
            try context.save()
            return existingProgress
        }

        let progress = LevelProgress(
            storageKey: level.storageKey,
            levelID: level.id,
            levelVersion: level.levelVersion,
            filledCellsData: Data(),
            filledCellCount: 0,
            activeColorIndex: nil,
            hintCount: 0,
            incorrectPaintAttemptCount: 0,
            firstCompletedAt: nil,
            completedAt: nil,
            lastPlayedAt: .now,
            bestCompletionRankRaw: CompletionRank.normal.rawValue,
            updatedAt: .now
        )
        context.insert(progress)
        try context.save()
        return progress
    }
}
