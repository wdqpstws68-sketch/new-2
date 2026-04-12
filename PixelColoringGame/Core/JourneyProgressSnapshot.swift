import Foundation

struct JourneyLevelProgressValue: Hashable {
    let filledCellCount: Int
    let completedAt: Date?
    let updatedAt: Date?
}

enum JourneyPrimaryCTA: Hashable {
    enum Kind: Hashable {
        case start
        case resume
        case replay
    }

    case level(storageKey: String, kind: Kind)
    case openCollectionBook(chapterID: String?)

    var buttonTitleKey: String {
        switch self {
        case .level(_, .start):
            return "journey.primary.button.startNextArtwork"
        case .level(_, .resume):
            return "journey.primary.button.continueCurrentChapter"
        case .level(_, .replay):
            return "journey.primary.button.replayFavoriteArtwork"
        case .openCollectionBook:
            return "journey.primary.button.openCollectionBook"
        }
    }
}

struct JourneyChapterCompletionState: Hashable {
    let completedLevels: Int
    let totalLevels: Int

    var isCompleted: Bool {
        totalLevels > 0 && completedLevels == totalLevels
    }
}

struct JourneyLevelState: Identifiable, Hashable {
    let level: LevelManifest
    let filledCellCount: Int
    let progressFraction: Double
    let isCompleted: Bool
    let isInProgress: Bool
    let updatedAt: Date?

    var id: String { level.storageKey }

    var buttonTitleKey: String {
        if isCompleted {
            return "home.action.replay"
        }
        if isInProgress {
            return "home.continue"
        }
        return "home.action.start"
    }

    func progressText(using localization: AppLocalization) -> String {
        if isCompleted {
            return localization.string("journey.level.progress.completed")
        }
        if isInProgress {
            return localization.string("journey.level.progress.inProgress", Int(progressFraction * 100))
        }
        return localization.string("journey.level.progress.ready")
    }

    func accessibilityLabel(using localization: AppLocalization) -> String {
        if isCompleted {
            return localization.string(
                "journey.accessibility.level.completed",
                level.localizedTitle(using: localization)
            )
        }
        if isInProgress {
            return localization.string(
                "journey.accessibility.level.inProgress",
                level.localizedTitle(using: localization),
                Int(progressFraction * 100)
            )
        }
        return localization.string(
            "journey.accessibility.level.notStarted",
            level.localizedTitle(using: localization)
        )
    }
}

struct JourneyArtworkSlotState: Identifiable, Hashable {
    let level: LevelManifest
    let isRevealed: Bool
    let isCompleted: Bool

    var id: String { level.storageKey }

    func accessibilityLabel(using localization: AppLocalization) -> String {
        if isRevealed {
            return localization.string(
                "journey.accessibility.artwork.revealed",
                level.localizedTitle(using: localization)
            )
        }
        return localization.string(
            "journey.accessibility.artwork.hidden",
            level.localizedTitle(using: localization)
        )
    }
}

struct JourneyCollectionPageState: Identifiable, Hashable {
    let chapter: JourneyCatalogChapter
    let artworkSlots: [JourneyArtworkSlotState]
    let hasRibbon: Bool

    var id: String { chapter.id }

    var revealedCount: Int {
        artworkSlots.count(where: \.isRevealed)
    }

    func accessibilityLabel(using localization: AppLocalization) -> String {
        let ribbonText = localization.string(
            hasRibbon
                ? "journey.accessibility.collectionPage.ribbonEarned"
                : "journey.accessibility.collectionPage.ribbonPending"
        )
        return localization.string(
            "journey.accessibility.collectionPage",
            chapter.chapter.localizedTitle(using: localization),
            revealedCount,
            artworkSlots.count,
            ribbonText
        )
    }
}

enum JourneyChapterStatus: Hashable {
    case completed
    case unlocked
    case locked

    var titleKey: String {
        switch self {
        case .completed:
            return "journey.chapter.status.completed"
        case .unlocked:
            return "journey.chapter.status.unlocked"
        case .locked:
            return "journey.chapter.status.locked"
        }
    }
}

struct JourneyChapterProgress: Identifiable, Hashable {
    let chapter: JourneyCatalogChapter
    let levelStates: [JourneyLevelState]
    let isUnlocked: Bool
    let lockReasonChapterTitleKey: String?

    var id: String { chapter.id }

    var completedLevelCount: Int {
        levelStates.count(where: \.isCompleted)
    }

    var totalLevelCount: Int {
        levelStates.count
    }

    var isCompleted: Bool {
        totalLevelCount > 0 && completedLevelCount == totalLevelCount
    }

    var status: JourneyChapterStatus {
        if isCompleted {
            return .completed
        }
        return isUnlocked ? .unlocked : .locked
    }

    func progressLabel(using localization: AppLocalization) -> String {
        localization.string("journey.chapter.progressLabel", completedLevelCount, totalLevelCount)
    }

    var nextPlayableLevelState: JourneyLevelState? {
        guard isUnlocked else { return nil }

        let inProgressLevels = levelStates
            .filter(\.isInProgress)
            .sorted { lhs, rhs in
                (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
            }

        if let inProgressLevel = inProgressLevels.first {
            return inProgressLevel
        }

        if let incompleteLevel = levelStates.first(where: { !$0.isCompleted }) {
            return incompleteLevel
        }

        return levelStates.first
    }

    var ctaTitleKey: String {
        guard let nextPlayableLevelState else {
            return "journey.chapter.cta.locked"
        }
        if nextPlayableLevelState.isCompleted {
            return "journey.chapter.cta.replay"
        }
        return nextPlayableLevelState.isInProgress
            ? "journey.chapter.cta.continue"
            : "journey.chapter.cta.start"
    }

    func lockReason(using localization: AppLocalization) -> String? {
        guard let lockReasonChapterTitleKey else { return nil }
        return localization.string(
            "journey.chapter.lockReason",
            localization.string(lockReasonChapterTitleKey)
        )
    }

    func accessibilityLabel(using localization: AppLocalization) -> String {
        let reason = lockReason(using: localization).map { " \($0)" } ?? ""
        return localization.string(
            "journey.accessibility.chapter",
            chapter.chapter.localizedTitle(using: localization),
            localization.string(status.titleKey).lowercased(with: localization.locale),
            progressLabel(using: localization),
            reason
        )
    }
}

struct JourneyProgressSnapshot: Hashable {
    let catalog: JourneyCatalog
    let chapters: [JourneyChapterProgress]
    let unlockedChapterIDs: Set<String>
    let currentChapterID: String?
    let chapterCompletionState: [String: JourneyChapterCompletionState]
    let collectionRevealState: [JourneyCollectionPageState]
    let primaryCTA: JourneyPrimaryCTA

    init(catalog: JourneyCatalog, progressLookup: [String: LevelProgress]) {
        self.init(
            catalog: catalog,
            progressValues: Dictionary(
                uniqueKeysWithValues: progressLookup.map { key, progress in
                    (
                        key,
                        JourneyLevelProgressValue(
                            filledCellCount: progress.filledCellCount,
                            completedAt: progress.completedAt,
                            updatedAt: progress.updatedAt
                        )
                    )
                }
            )
        )
    }

    init(catalog: JourneyCatalog, progressValues: [String: JourneyLevelProgressValue]) {
        self.catalog = catalog

        var unlockedChapterIDs = Set<String>()
        var chapterProgressItems: [JourneyChapterProgress] = []
        var completionState: [String: JourneyChapterCompletionState] = [:]
        var shouldUnlockCurrentChapter = true

        for (index, chapter) in catalog.chapters.enumerated() {
            let levelStates = chapter.levels.map { level in
                let progress = progressValues[level.storageKey]
                let filledCellCount = progress?.filledCellCount ?? 0
                let progressFraction = level.paintableCellCount > 0
                    ? Double(filledCellCount) / Double(level.paintableCellCount)
                    : 0

                return JourneyLevelState(
                    level: level,
                    filledCellCount: filledCellCount,
                    progressFraction: progressFraction,
                    isCompleted: progress?.completedAt != nil,
                    isInProgress: filledCellCount > 0 && progress?.completedAt == nil,
                    updatedAt: progress?.updatedAt
                )
            }

            let completedLevelCount = levelStates.count(where: \.isCompleted)
            let state = JourneyChapterCompletionState(
                completedLevels: completedLevelCount,
                totalLevels: levelStates.count
            )
            completionState[chapter.id] = state

            let isUnlocked = index == 0 || shouldUnlockCurrentChapter
            if isUnlocked {
                unlockedChapterIDs.insert(chapter.id)
            }

            let previousChapterTitleKey = index > 0 ? catalog.chapters[index - 1].chapter.titleKey : nil

            chapterProgressItems.append(
                JourneyChapterProgress(
                    chapter: chapter,
                    levelStates: levelStates,
                    isUnlocked: isUnlocked,
                    lockReasonChapterTitleKey: isUnlocked ? nil : previousChapterTitleKey
                )
            )

            shouldUnlockCurrentChapter = shouldUnlockCurrentChapter && state.isCompleted
        }

        let currentChapterID = chapterProgressItems.first(where: { $0.isUnlocked && !$0.isCompleted })?.id
        let collectionRevealState = chapterProgressItems.map { chapterProgress in
            JourneyCollectionPageState(
                chapter: chapterProgress.chapter,
                artworkSlots: chapterProgress.levelStates.map { levelState in
                    JourneyArtworkSlotState(
                        level: levelState.level,
                        isRevealed: levelState.isCompleted,
                        isCompleted: levelState.isCompleted
                    )
                },
                hasRibbon: chapterProgress.isCompleted
            )
        }

        let primaryCTA: JourneyPrimaryCTA
        if let currentChapter = chapterProgressItems.first(where: { $0.id == currentChapterID }),
           let nextLevel = currentChapter.nextPlayableLevelState {
            let kind: JourneyPrimaryCTA.Kind
            if nextLevel.isCompleted {
                kind = .replay
            } else if nextLevel.isInProgress {
                kind = .resume
            } else {
                kind = .start
            }

            primaryCTA = .level(storageKey: nextLevel.level.storageKey, kind: kind)
        } else {
            primaryCTA = .openCollectionBook(chapterID: chapterProgressItems.last?.id)
        }

        self.chapters = chapterProgressItems
        self.unlockedChapterIDs = unlockedChapterIDs
        self.currentChapterID = currentChapterID
        self.chapterCompletionState = completionState
        self.collectionRevealState = collectionRevealState
        self.primaryCTA = primaryCTA
    }

    var allChaptersCompleted: Bool {
        chapters.allSatisfy(\.isCompleted)
    }

    func chapter(id: String) -> JourneyChapterProgress? {
        chapters.first(where: { $0.id == id })
    }

    func canPlay(levelStorageKey: String) -> Bool {
        guard let chapter = chapters.first(where: { chapter in
            chapter.levelStates.contains(where: { $0.level.storageKey == levelStorageKey })
        }) else {
            return false
        }

        return chapter.isUnlocked
    }

    func nextChapter(after chapterID: String) -> JourneyChapterProgress? {
        guard let index = chapters.firstIndex(where: { $0.id == chapterID }) else {
            return nil
        }

        let nextIndex = chapters.index(after: index)
        guard chapters.indices.contains(nextIndex) else {
            return nil
        }

        return chapters[nextIndex]
    }

    func completionDestination(afterCompleting levelStorageKey: String) -> CompletionDestination {
        guard let chapterProgress = chapters.first(where: { chapter in
            chapter.levelStates.contains(where: { $0.level.storageKey == levelStorageKey })
        }) else {
            return .returnHome
        }

        if !chapterProgress.isCompleted,
           let nextLevel = chapterProgress.levelStates.first(where: { !$0.isCompleted }) {
            return .nextLevel(storageKey: nextLevel.level.storageKey)
        }

        if let nextChapter = nextChapter(after: chapterProgress.id) {
            return .chapterUnlocked(chapterID: nextChapter.id)
        }

        if allChaptersCompleted {
            return .openCollectionBook(chapterID: chapterProgress.id)
        }

        return .returnHome
    }
}
