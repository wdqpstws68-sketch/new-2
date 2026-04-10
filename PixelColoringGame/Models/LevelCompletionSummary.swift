import Foundation

struct LevelCompletionSummary: Identifiable {
    let id = UUID()
    let level: LevelManifest
    let nextLevel: LevelManifest?
    let filledCells: Int
}
