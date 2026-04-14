import SwiftUI
import SwiftData

@main
struct PixelColoringGameApp: App {
    @State private var localization = AppLocalization()
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try PixelColoringGamePersistence.makeSharedContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(localization)
                .environment(\.locale, localization.locale)
        }
        .modelContainer(modelContainer)
    }
}
