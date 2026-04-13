import SwiftUI
import SwiftData

@main
struct PixelColoringGameApp: App {
    @State private var localization = AppLocalization()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(localization)
                .environment(\.locale, localization.locale)
        }
        .modelContainer(for: [LevelProgress.self, PlayerProfile.self])
    }
}
