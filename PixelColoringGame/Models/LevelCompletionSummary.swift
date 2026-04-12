import Foundation

enum CompletionDestination: Hashable {
    case nextLevel(storageKey: String)
    case chapterUnlocked(chapterID: String)
    case openCollectionBook(chapterID: String?)
    case returnHome
}

struct LevelCompletionSummary: Identifiable, Hashable {
    let id = UUID()
    let level: LevelManifest
    let chapterID: String
    let chapterTitleKey: String
    let filledCells: Int
    let destination: CompletionDestination
}
