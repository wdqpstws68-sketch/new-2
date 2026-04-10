import Foundation

struct LevelCatalogItem: Identifiable {
    let level: LevelManifest
    let progress: LevelProgress?

    var id: String { level.storageKey }

    var progressFraction: Double {
        guard level.paintableCellCount > 0 else { return 0 }
        let filledCount = progress?.filledCellCount ?? 0
        return Double(filledCount) / Double(level.paintableCellCount)
    }

    var isCompleted: Bool {
        progress?.completedAt != nil
    }

    var isInProgress: Bool {
        (progress?.filledCellCount ?? 0) > 0 && !isCompleted
    }

    var updatedAt: Date? {
        progress?.updatedAt
    }
}
