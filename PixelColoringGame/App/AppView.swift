import SwiftUI
import SwiftData

private enum AppRoute: Hashable {
    case game(String)
    case completion(LevelCompletionSummary)
    case collectionBook(String?)
}

private enum JourneyResetNotice: Identifiable {
    case journeyReset

    var id: Int { 0 }
}

struct AppView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LevelProgress.updatedAt, order: .reverse)
    private var progressRecords: [LevelProgress]

    @State private var path: [AppRoute] = []
    @State private var hasBootstrapped = false
    @State private var resetNotice: JourneyResetNotice?

    private let levelRepository: LevelRepository
    private let journeyRepository: JourneyRepository
    private let progressStore = ProgressStore()
    private let resetCoordinator = JourneyResetCoordinator()

    init() {
        let levelRepository = LevelRepository()
        self.levelRepository = levelRepository
        self.journeyRepository = JourneyRepository(levelRepository: levelRepository)
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            NavigationStack(path: $path) {
                JourneyHomeView(
                    manifest: journeyRepository.manifest,
                    snapshot: journeySnapshot,
                    repository: levelRepository,
                    onSelectLevel: openLevel,
                    onOpenCollectionBook: openCollectionBook
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self, destination: destinationView)
            }
        }
        .task {
            bootstrapIfNeeded()
        }
        .alert(item: $resetNotice) { notice in
            Alert(
                title: Text(localization.string("alert.journeyReset.title")),
                message: Text(resetNoticeMessage(for: notice)),
                dismissButton: .default(Text(localization.string("alert.journeyReset.action")))
            )
        }
    }

    private var progressLookup: [String: LevelProgress] {
        progressStore.lookup(from: progressRecords)
    }

    private var progressValues: [String: JourneyLevelProgressValue] {
        Dictionary(
            uniqueKeysWithValues: progressRecords.map { progress in
                (
                    progress.storageKey,
                    JourneyLevelProgressValue(
                        filledCellCount: progress.filledCellCount,
                        completedAt: progress.completedAt,
                        updatedAt: progress.updatedAt
                    )
                )
            }
        )
    }

    private var journeySnapshot: JourneyProgressSnapshot {
        JourneyProgressSnapshot(catalog: journeyRepository.catalog, progressValues: progressValues)
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case let .game(storageKey):
            if let level = journeyRepository.level(storageKey: storageKey) {
                GameView(
                    level: level,
                    existingProgress: progressLookup[level.storageKey],
                    progressStore: progressStore,
                    onClose: dismissTopRoute,
                    onComplete: handleLevelCompletion
                )
                .toolbar(.hidden, for: .navigationBar)
            } else {
                MissingContentView(message: localization.string("error.artworkMissing"))
                    .toolbar(.hidden, for: .navigationBar)
            }
        case let .completion(summary):
            CompletionView(
                summary: summary,
                repository: levelRepository,
                journeyRepository: journeyRepository,
                onPrimaryAction: {
                    handleCompletionDestination(summary.destination)
                },
                onReturnHome: {
                    path = []
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        case let .collectionBook(chapterID):
            CollectionBookView(
                manifest: journeyRepository.manifest,
                snapshot: journeySnapshot,
                repository: levelRepository,
                initialChapterID: chapterID
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        do {
            let result = try resetCoordinator.applyIfNeeded(in: modelContext)
            if result.shouldShowNotice {
                resetNotice = .journeyReset
            }
        } catch {
            assertionFailure("Failed to apply journey reset: \(error)")
        }
    }

    private func openLevel(_ level: LevelManifest) {
        let chapterID = journeyRepository.chapter(containingLevelStorageKey: level.storageKey)?.id
        AppLogger.levelStarted(storageKey: level.storageKey, chapterID: chapterID)
        path.append(.game(level.storageKey))
    }

    private func openCollectionBook(_ chapterID: String?) {
        AppLogger.collectionBookOpened(chapterID: chapterID)
        path.append(.collectionBook(chapterID))
    }

    private func dismissTopRoute() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    private func handleLevelCompletion(level: LevelManifest, filledCells: Int) {
        guard let chapter = journeyRepository.chapter(containingLevelStorageKey: level.storageKey) else {
            path = []
            return
        }

        var updatedProgressValues = progressValues
        updatedProgressValues[level.storageKey] = JourneyLevelProgressValue(
            filledCellCount: filledCells,
            completedAt: .now,
            updatedAt: .now
        )

        let updatedSnapshot = JourneyProgressSnapshot(
            catalog: journeyRepository.catalog,
            progressValues: updatedProgressValues
        )
        let destination = updatedSnapshot.completionDestination(afterCompleting: level.storageKey)
        let summary = LevelCompletionSummary(
            level: level,
            chapterID: chapter.id,
            chapterTitleKey: chapter.chapter.titleKey,
            filledCells: filledCells,
            destination: destination
        )

        AppLogger.levelCompleted(storageKey: level.storageKey, chapterID: chapter.id)
        if case let .chapterUnlocked(chapterID) = destination {
            AppLogger.chapterUnlocked(chapterID: chapterID)
        }

        replaceTopRoute(with: .completion(summary))
    }

    private func handleCompletionDestination(_ destination: CompletionDestination) {
        switch destination {
        case let .nextLevel(storageKey):
            path = [.game(storageKey)]
        case .chapterUnlocked:
            path = []
        case let .openCollectionBook(chapterID):
            path = [.collectionBook(chapterID)]
            AppLogger.collectionBookOpened(chapterID: chapterID)
        case .returnHome:
            path = []
        }
    }

    private func replaceTopRoute(with route: AppRoute) {
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(route)
    }

    private func resetNoticeMessage(for notice: JourneyResetNotice) -> String {
        switch notice {
        case .journeyReset:
            return localization.string("alert.journeyReset.message")
        }
    }
}

private struct MissingContentView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundStyle(AppTheme.accentOrange)

            Text(message)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

#Preview {
    AppView()
        .modelContainer(for: [LevelProgress.self], inMemory: true)
        .environment(AppLocalization.preview)
}
