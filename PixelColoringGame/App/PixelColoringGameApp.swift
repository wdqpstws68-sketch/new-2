import SwiftUI
import SwiftData

@main
struct PixelColoringGameApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
        }
        .modelContainer(for: [LevelProgress.self])
    }
}
