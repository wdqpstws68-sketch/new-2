import SwiftUI

enum RootTab: Hashable {
    case journey
    case daily
    case library
}

enum AppRoute: Hashable {
    case game(String, PlayRouteContext)
    case completion(LevelCompletionSummary)
    case collectionBook(String?)
    case monthDetail(monthID: String)
}

struct RootTabView: View {
    @Environment(AppLocalization.self) private var localization

    @Binding var selectedTab: RootTab
    @Binding var journeyPath: [AppRoute]
    @Binding var dailyPath: [AppRoute]
    @Binding var libraryPath: [AppRoute]

    let manifest: JourneyManifest
    let snapshot: JourneyProgressSnapshot
    let homeSnapshot: HomeProgressSnapshot
    let repository: LevelRepository
    let onSelectLevel: (LevelManifest, LevelEntrySource) -> Void
    let onOpenDailyChallenge: (LevelEntrySource) -> Void
    let onOpenCollectionBook: (String?) -> Void
    let onOpenMonthDetail: (String) -> Void
    let onOpenMonthArtwork: (LevelManifest, String, String) -> Void
    let onEquipEventTitle: (String) -> Void
    let destinationView: (AppRoute) -> AnyView

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $journeyPath) {
                JourneyHomeView(
                    manifest: manifest,
                    snapshot: snapshot,
                    homeSnapshot: homeSnapshot,
                    repository: repository,
                    onSelectLevel: onSelectLevel,
                    onOpenDailyChallenge: onOpenDailyChallenge,
                    onOpenCollectionBook: onOpenCollectionBook,
                    onOpenMonthDetail: onOpenMonthDetail
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self, destination: destinationView)
            }
            .tabItem {
                tabLabel(
                    asset: .tabJourney,
                    titleKey: "tab.journey"
                )
            }
            .tag(RootTab.journey)

            NavigationStack(path: $dailyPath) {
                DailyHubView(
                    manifest: manifest,
                    snapshot: snapshot,
                    homeSnapshot: homeSnapshot,
                    repository: repository,
                    onOpenDailyChallenge: onOpenDailyChallenge,
                    onOpenMonthDetail: onOpenMonthDetail,
                    onOpenCollectionBook: onOpenCollectionBook
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self, destination: destinationView)
            }
            .tabItem {
                tabLabel(
                    asset: .tabDaily,
                    titleKey: "tab.daily"
                )
            }
            .tag(RootTab.daily)

            NavigationStack(path: $libraryPath) {
                CollectionBookView(
                    manifest: manifest,
                    snapshot: snapshot,
                    homeSnapshot: homeSnapshot,
                    repository: repository,
                    initialChapterID: snapshot.currentChapterID ?? snapshot.chapters.last?.id,
                    onEquipEventTitle: onEquipEventTitle
                )
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: AppRoute.self, destination: destinationView)
            }
            .tabItem {
                tabLabel(
                    asset: .tabLibrary,
                    titleKey: "tab.library"
                )
            }
            .tag(RootTab.library)
        }
        .tint(AppTheme.accentBerry)
    }

    @ViewBuilder
    private func tabLabel(asset: IconAsset, titleKey: String) -> some View {
        if asset.hasCustomArt {
            Label {
                Text(localization.string(titleKey))
            } icon: {
                Image(asset.assetName)
                    .renderingMode(.template)
            }
        } else {
            Label(localization.string(titleKey), systemImage: asset.sfSymbolFallback)
        }
    }
}
