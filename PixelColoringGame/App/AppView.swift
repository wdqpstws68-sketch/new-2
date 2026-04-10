import SwiftUI
import SwiftData

struct AppView: View {
    @Query(sort: \LevelProgress.updatedAt, order: .reverse)
    private var progressRecords: [LevelProgress]

    @State private var activeLevel: LevelManifest?
    @State private var completionSummary: LevelCompletionSummary?

    private let repository = LevelRepository()
    private let progressStore = ProgressStore()

    var body: some View {
        ZStack {
            AppBackgroundView()

            if let completionSummary {
                CompletionView(
                    summary: completionSummary,
                    repository: repository,
                    onReturnHome: { self.completionSummary = nil },
                    onPlayNext: {
                        let nextLevel = completionSummary.nextLevel
                        self.completionSummary = nil
                        self.activeLevel = nextLevel
                    }
                )
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            } else if let activeLevel {
                GameView(
                    level: activeLevel,
                    nextLevel: nextLevel(after: activeLevel),
                    existingProgress: progressStore.record(for: activeLevel, in: progressRecords),
                    progressStore: progressStore,
                    onClose: { self.activeLevel = nil },
                    onComplete: { summary in
                        self.activeLevel = nil
                        self.completionSummary = summary
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                HomeView(
                    repository: repository,
                    catalogItems: catalogItems,
                    continueItem: continueItem,
                    onSelectLevel: { level in
                        activeLevel = level
                    }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.92), value: activeLevel?.storageKey)
        .animation(.spring(response: 0.38, dampingFraction: 0.92), value: completionSummary?.id)
    }

    private var catalogItems: [LevelCatalogItem] {
        let lookup = progressStore.lookup(from: progressRecords)

        return repository.levels
            .sorted { lhs, rhs in
                let leftProgress = lookup[lhs.storageKey]
                let rightProgress = lookup[rhs.storageKey]

                let leftInProgress = (leftProgress?.filledCellCount ?? 0) > 0 && leftProgress?.completedAt == nil
                let rightInProgress = (rightProgress?.filledCellCount ?? 0) > 0 && rightProgress?.completedAt == nil

                if leftInProgress != rightInProgress {
                    return leftInProgress
                }

                if leftProgress?.completedAt == nil, rightProgress?.completedAt != nil {
                    return true
                }

                if leftProgress?.completedAt != nil, rightProgress?.completedAt == nil {
                    return false
                }

                return lhs.sortOrder < rhs.sortOrder
            }
            .map { LevelCatalogItem(level: $0, progress: lookup[$0.storageKey]) }
    }

    private var continueItem: LevelCatalogItem? {
        catalogItems
            .filter(\.isInProgress)
            .sorted { lhs, rhs in
                (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
            }
            .first
    }

    private func nextLevel(after level: LevelManifest) -> LevelManifest? {
        guard let currentIndex = repository.levels.firstIndex(where: { $0.storageKey == level.storageKey }) else {
            return nil
        }
        let nextIndex = repository.levels.index(after: currentIndex)
        guard repository.levels.indices.contains(nextIndex) else {
            return nil
        }
        return repository.levels[nextIndex]
    }
}

#Preview {
    AppView()
        .modelContainer(for: [LevelProgress.self], inMemory: true)
}
