import SwiftData
import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

private enum JourneyResetNotice: Identifiable {
    case journeyReset
    case persistenceRecovered

    var id: Int {
        switch self {
        case .journeyReset:
            return 0
        case .persistenceRecovered:
            return 1
        }
    }
}

private enum ActiveSheet: Identifiable {
    case dailyMission
    case lifeDepleted

    var id: Int {
        switch self {
        case .dailyMission:
            return 0
        case .lifeDepleted:
            return 1
        }
    }
}

private struct PendingLevelEntry: Hashable {
    let storageKey: String
    let routeContext: PlayRouteContext
    let source: LevelEntrySource
}

struct AppView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \LevelProgress.updatedAt, order: .reverse)
    private var progressRecords: [LevelProgress]
    @Query private var playerProfiles: [PlayerProfile]

    @State private var hasStarted = false
    @State private var selectedTab: RootTab = .journey
    @State private var journeyPath: [AppRoute] = []
    @State private var dailyPath: [AppRoute] = []
    @State private var libraryPath: [AppRoute] = []
    @State private var hasBootstrapped = false
    @State private var resetNotice: JourneyResetNotice?
    @State private var activeSheet: ActiveSheet?
    @State private var pendingLevelEntry: PendingLevelEntry?
    @State private var currentDate = Date.now
    @State private var currentDailyChallenge: DailyChallengeDefinition?
    @State private var lifeBalance = LifeBalance(
        refillableLives: 0,
        bonusLives: 0,
        maxRefillableLives: PlayerProfileStore.maxRefillableLives,
        refillInterval: PlayerProfileStore.refillInterval,
        nextRefillDate: nil
    )
    @State private var audioSettings: AudioSettings
    @State private var audioService: AudioPlayerService
    @State private var celebrationCoordinator: CelebrationCoordinator?
    @State private var didFireAppLaunchedTrigger: Bool = false

    private let levelRepository: LevelRepository
    private let journeyRepository: JourneyRepository
    private let dailyRepository: DailyChallengeRepository
    private let progressStore = ProgressStore()
    private let playerProfileStore = PlayerProfileStore()
    private let resetCoordinator = JourneyResetCoordinator()

    @State private var rewardedAdService = RewardedAdService()
    @State private var rewardedAdQuota = RewardedAdQuota()

    init() {
        let levelRepository = LevelRepository()
        self.levelRepository = levelRepository
        self.journeyRepository = JourneyRepository(levelRepository: levelRepository)
        self.dailyRepository = DailyChallengeRepository(levelRepository: levelRepository)

        let settings = AudioSettings()
        self._audioSettings = State(initialValue: settings)
        self._audioService = State(initialValue: AudioPlayerService(settings: settings))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            if hasStarted {
                RootTabView(
                    selectedTab: $selectedTab,
                    journeyPath: $journeyPath,
                    dailyPath: $dailyPath,
                    libraryPath: $libraryPath,
                    manifest: journeyRepository.manifest,
                    snapshot: journeySnapshot,
                    homeSnapshot: homeSnapshot,
                    repository: levelRepository,
                    onSelectLevel: openJourneyLevel,
                    onOpenDailyChallenge: openDailyChallenge,
                    onOpenCollectionBook: openCollectionBook,
                    onOpenMonthDetail: openMonthDetail,
                    onOpenMonthArtwork: openMonthArtwork,
                    onEquipEventTitle: handleEquipEventTitle,
                    destinationView: { AnyView(destinationView(for: $0)) }
                )
                .transition(.opacity)
            } else {
                titleScreen
                    .transition(.opacity)
            }

            if let coordinator = celebrationCoordinator {
                MilestoneToastHost(coordinator: coordinator)
                    .allowsHitTesting(coordinator.currentToast != nil)
            }
        }
        .environment(audioService)
        .environment(audioSettings)
        .onAppear { audioService.playBGM(.bgmHome) }
        .onChange(of: journeyPath) { _, _ in playHomeBGMIfReturnedToRoot() }
        .onChange(of: dailyPath) { _, _ in playHomeBGMIfReturnedToRoot() }
        .onChange(of: libraryPath) { _, _ in playHomeBGMIfReturnedToRoot() }
        .onChange(of: selectedTab) { _, _ in playHomeBGMIfReturnedToRoot() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: audioService.stopBGM()
            case .active:
                if currentPath.isEmpty { audioService.playBGM(.bgmHome) }
            default: break
            }
        }
        .task {
            bootstrapIfNeeded()
            await refreshCurrentContext(presentDailyPopup: true)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await refreshCurrentContext(presentDailyPopup: true)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await refreshCurrentContext(presentDailyPopup: false)
            }
        }
        .sheet(item: $activeSheet, onDismiss: handleSheetDismissed, content: sheetView)
        .alert(item: $resetNotice) { notice in
            Alert(
                title: Text(resetNoticeTitle(for: notice)),
                message: Text(resetNoticeMessage(for: notice)),
                dismissButton: .default(Text(localization.string("alert.journeyReset.action")))
            )
        }
        .fullScreenCover(item: celebrationFullScreenBinding) { event in
            celebrationFullScreenView(for: event)
        }
        // v1.0: no banner ads. AdMob banner integration is wired but disabled
        // until v1.1 release (post-launch AdMob production setup pending).
    }

    @ViewBuilder
    private var titleScreen: some View {
        #if DEBUG
        TitleScreenView(
            collectionTitle: journeyRepository.manifest.localizedCollectionTitle(using: localization),
            defaultCollectionChapterID: journeySnapshot.currentChapterID ?? journeySnapshot.chapters.last?.id,
            onOpenCollectionBook: { chapterID in
                selectedTab = .library
                if let chapterID {
                    libraryPath = [.collectionBook(chapterID)]
                }
                withAnimation(.easeInOut(duration: 0.45)) { hasStarted = true }
            },
            onStart: {
                withAnimation(.easeInOut(duration: 0.45)) { hasStarted = true }
            },
            celebrationCoordinator: celebrationCoordinator
        )
        #else
        TitleScreenView(
            collectionTitle: journeyRepository.manifest.localizedCollectionTitle(using: localization),
            defaultCollectionChapterID: journeySnapshot.currentChapterID ?? journeySnapshot.chapters.last?.id,
            onOpenCollectionBook: { chapterID in
                selectedTab = .library
                if let chapterID {
                    libraryPath = [.collectionBook(chapterID)]
                }
                withAnimation(.easeInOut(duration: 0.45)) { hasStarted = true }
            },
            onStart: {
                withAnimation(.easeInOut(duration: 0.45)) { hasStarted = true }
            }
        )
        #endif
    }

    private var celebrationFullScreenBinding: Binding<CelebrationEvent?> {
        Binding(
            get: { celebrationCoordinator?.currentFullScreenEvent },
            set: { newValue in
                if newValue == nil {
                    celebrationCoordinator?.dismissCurrent()
                }
            }
        )
    }

    @ViewBuilder
    private func celebrationFullScreenView(for event: CelebrationEvent) -> some View {
        switch event {
        case let .chapterClear(chapterID):
            let chapter = journeyRepository.chapter(id: chapterID)
            let nextChapter = chapter.flatMap { c -> JourneyChapter? in
                let chapters = journeyRepository.manifest.chapters
                guard let idx = chapters.firstIndex(where: { $0.id == c.id }),
                      idx + 1 < chapters.count else { return nil }
                return chapters[idx + 1]
            }
            ChapterClearView(
                chapterTitleKey: chapter?.chapter.titleKey ?? "chapter.clear.title",
                nextChapterTitleKey: nextChapter?.titleKey,
                onDismiss: { celebrationCoordinator?.dismissCurrent() }
            )
            .environment(localization)
        case .journeyComplete:
            JourneyCompleteView(onDismiss: { celebrationCoordinator?.dismissCurrent() })
                .environment(localization)
        case let .monthlyComplete(yearMonth):
            MonthlyCompleteView(
                yearMonth: yearMonth,
                hasNextMonth: hasNextMonthContent(after: yearMonth),
                onContinue: { celebrationCoordinator?.dismissCurrent() },
                onGoToNextMonth: {
                    selectedTab = .daily
                    celebrationCoordinator?.dismissCurrent()
                }
            )
            .environment(localization)
        case .firstPerfect, .streakMilestone, .levelCountMilestone:
            // Toasts shouldn't reach the fullScreen handler; dismiss defensively
            Color.clear.onAppear {
                celebrationCoordinator?.dismissCurrent()
            }
        }
    }

    private func hasNextMonthContent(after yearMonth: String) -> Bool {
        // yearMonth format "YYYY-MM"
        let parts = yearMonth.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return false }
        let nextMonth = month == 12 ? 1 : month + 1
        let nextYear = month == 12 ? year + 1 : year
        let nextYearMonth = String(format: "%04d-%02d", nextYear, nextMonth)
        return dailyRepository.event(id: nextYearMonth) != nil
    }

    private var appCalendar: Calendar {
        .autoupdatingCurrent
    }

    private var todayQuotaKey: String {
        let components = appCalendar.dateComponents([.year, .month, .day], from: Date.now)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
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

    private var playerProfile: PlayerProfile? {
        playerProfiles.first
    }

    private var currentProfile: PlayerProfile? {
        playerProfile ?? (try? playerProfileStore.ensureProfile(in: modelContext))
    }

    private var completedLevelStorageKeys: Set<String> {
        Set(
            progressLookup.compactMap { storageKey, progress in
                progress.completedAt != nil ? storageKey : nil
            }
        )
    }

    private var homeSnapshot: HomeProgressSnapshot {
        HomeProgressSnapshot(
            journeySnapshot: journeySnapshot,
            dailyRepository: dailyRepository,
            progressLookup: progressLookup,
            lifeBalance: lifeBalance,
            profile: playerProfile,
            resolvedDailyChallenge: currentDailyChallenge,
            currentDate: currentDate
        )
    }

    private var currentPath: [AppRoute] {
        switch selectedTab {
        case .journey: return journeyPath
        case .daily: return dailyPath
        case .library: return libraryPath
        }
    }

    private func playHomeBGMIfReturnedToRoot() {
        if currentPath.isEmpty {
            audioService.playBGM(.bgmHome)
        }
    }

    private func tabForRouteContext(_ context: PlayRouteContext) -> RootTab {
        switch context {
        case .journey: return .journey
        case .dailyToday, .monthlyFreeplay: return .daily
        }
    }

    private func setPath(_ newPath: [AppRoute], for tab: RootTab) {
        switch tab {
        case .journey: journeyPath = newPath
        case .daily: dailyPath = newPath
        case .library: libraryPath = newPath
        }
    }

    private func appendPath(_ route: AppRoute, for tab: RootTab) {
        switch tab {
        case .journey: journeyPath.append(route)
        case .daily: dailyPath.append(route)
        case .library: libraryPath.append(route)
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case let .game(storageKey, context):
            if let level = levelRepository.level(storageKey: storageKey) {
                let existingProgress = progressLookup[level.storageKey]
                let chapterID = journeyRepository.chapter(containingLevelStorageKey: level.storageKey)?.id
                GameView(
                    level: level,
                    existingProgress: existingProgress,
                    playContext: context,
                    chapterID: chapterID,
                    startFresh: existingProgress?.completedAt != nil,
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
                    setPath([], for: selectedTab)
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        case let .collectionBook(chapterID):
            CollectionBookView(
                manifest: journeyRepository.manifest,
                snapshot: journeySnapshot,
                homeSnapshot: homeSnapshot,
                repository: levelRepository,
                initialChapterID: chapterID,
                onEquipEventTitle: handleEquipEventTitle
            )
            .navigationBarTitleDisplayMode(.inline)
        case let .monthDetail(monthID):
            MonthDetailView(
                monthID: monthID,
                eventState: homeSnapshot.eventCollection(eventID: monthID),
                repository: levelRepository,
                onOpenArtwork: openMonthArtwork,
                onEquipEventTitle: handleEquipEventTitle,
                onDismissMissing: dismissTopRoute
            )
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .dailyMission:
            if let dailyChallenge = homeSnapshot.dailyChallenge {
                DailyMissionPopupView(
                    challenge: dailyChallenge,
                    onStart: {
                        activeSheet = nil
                        openDailyChallenge(source: .dailyPopup)
                    },
                    onClose: {
                        activeSheet = nil
                    }
                )
                .presentationDetents([.fraction(0.52)])
                .presentationDragIndicator(.visible)
            } else {
                EmptyView()
            }
        case .lifeDepleted:
            LifeDepletedSheet(
                balance: lifeBalance,
                dailyChallenge: homeSnapshot.dailyChallenge,
                adService: rewardedAdService,
                canWatchMore: rewardedAdQuota.canWatch(on: todayQuotaKey),
                onClose: {
                    pendingLevelEntry = nil
                    activeSheet = nil
                },
                onWatchAd: {
                    Task { await handleRewardedLifeRequest() }
                },
                onPlayDaily: {
                    pendingLevelEntry = nil
                    activeSheet = nil
                    openDailyChallenge(source: .dailyHero)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .task { await rewardedAdService.refreshConsentAndLoadAds() }
        }
    }

    private func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        do {
            let result = try resetCoordinator.applyIfNeeded(in: modelContext)
            let profile = try playerProfileStore.ensureProfile(in: modelContext)
            ensureCelebrationCoordinator(for: profile)
            if PixelColoringGamePersistence.consumePendingRecoveryNotice() {
                resetNotice = .persistenceRecovered
            }
            if result.shouldShowNotice {
                resetNotice = .journeyReset
            }
        } catch {
            assertionFailure("Failed to apply journey reset: \(error)")
        }
    }

    private func ensureCelebrationCoordinator(for profile: PlayerProfile) {
        guard celebrationCoordinator == nil else { return }
        celebrationCoordinator = CelebrationCoordinator(
            initialSeen: profile.celebrationsSeen,
            persist: { [weak profile] newSeen in
                guard let profile else { return }
                profile.celebrationsSeen = newSeen
            }
        )
    }

    private var completedLevelCount: Int {
        progressRecords.filter { $0.completedAt != nil }.count
    }

    private var perfectLevelCount: Int {
        progressRecords.filter { $0.bestCompletionRank == .perfect }.count
    }

    private func fireJourneyCelebration(
        snapshot: JourneyProgressSnapshot,
        chapter: JourneyCatalogChapter,
        destination: CompletionDestination,
        completionRank: CompletionRank
    ) {
        guard let coordinator = celebrationCoordinator, let profile = currentProfile else { return }

        let wasChapterFinal: Bool
        switch destination {
        case .chapterUnlocked, .openCollectionBook:
            wasChapterFinal = true
        case .nextLevel, .returnHome, .returnToMonth:
            wasChapterFinal = false
        }

        let isJourneyComplete = snapshot.allChaptersCompleted

        let snap = PlayerProfileSnapshot(
            completedLevelCount: completedLevelCount,
            perfectLevelCount: perfectLevelCount,
            currentStreakDays: profile.currentStreak,
            completedChapterIDs: Set(),
            isJourneyComplete: isJourneyComplete,
            lastLevelChapterID: chapter.id,
            lastLevelWasPerfect: completionRank == .perfect,
            lastLevelWasChapterFinalLevel: wasChapterFinal,
            monthlyCompletedYearMonth: nil
        )
        coordinator.handle(trigger: .levelCompleted(profileSnapshot: snap))
    }

    private func fireDailyCelebration(
        monthID: String,
        profile: PlayerProfile?,
        completionRank: CompletionRank
    ) {
        guard let coordinator = celebrationCoordinator, let profile else { return }

        let completedThisMonth = profile.completedDailyDayKeys
            .filter { $0.hasPrefix(monthID) }
            .count
        let monthlyComplete = completedThisMonth >= 28
            ? monthID
            : nil // approximate threshold; 28+ days indicates month complete

        let snap = PlayerProfileSnapshot(
            completedLevelCount: completedLevelCount,
            perfectLevelCount: perfectLevelCount,
            currentStreakDays: profile.currentStreak,
            completedChapterIDs: Set(),
            isJourneyComplete: false,
            lastLevelChapterID: nil,
            lastLevelWasPerfect: completionRank == .perfect,
            lastLevelWasChapterFinalLevel: false,
            monthlyCompletedYearMonth: monthlyComplete
        )
        coordinator.handle(trigger: .dailyCompleted(profileSnapshot: snap))
    }

    private func refreshCurrentContext(
        presentDailyPopup: Bool
    ) async {
        let now = Date.now
        currentDate = now
        currentDailyChallenge = resolveDailyChallenge(for: now)

        guard let profile = currentProfile else { return }

        lifeBalance = playerProfileStore.resolveLives(
            at: now,
            profile: profile,
            calendar: appCalendar
        )

        if presentDailyPopup,
           hasStarted,
           currentPath.isEmpty,
           activeSheet == nil,
           let challenge = currentDailyChallenge,
           playerProfileStore.shouldPresentDailyPopup(dayKey: challenge.dayKey, profile: profile) {
            playerProfileStore.markDailyPopupPresented(dayKey: challenge.dayKey, profile: profile)
            activeSheet = .dailyMission
        }

        saveContext(reason: "refresh_current_context")
    }

    private func openJourneyLevel(_ level: LevelManifest, source: LevelEntrySource) {
        attemptOpenLevel(
            level: level,
            routeContext: .journey,
            source: source
        )
    }

    private func openDailyChallenge(source: LevelEntrySource) {
        guard let dailyChallenge = currentDailyChallenge else { return }

        attemptOpenLevel(
            level: dailyChallenge.level,
            routeContext: .dailyToday(
                dayKey: dailyChallenge.dayKey,
                monthID: dailyChallenge.month.id,
                monthTitleKey: dailyChallenge.month.titleKey,
                rewardTitleID: dailyChallenge.month.rewardTitleID
            ),
            source: source
        )
    }

    private func openMonthDetail(monthID: String) {
        if currentPath.last == .monthDetail(monthID: monthID) { return }
        AppLogger.eventDetailOpened(eventID: monthID)
        appendPath(.monthDetail(monthID: monthID), for: selectedTab)
    }

    private func openMonthArtwork(level: LevelManifest, monthID: String, monthTitleKey: String) {
        attemptOpenLevel(
            level: level,
            routeContext: .monthlyFreeplay(
                monthID: monthID,
                monthTitleKey: monthTitleKey,
                rewardTitleID: dailyRepository.event(id: monthID)?.rewardTitleID
            ),
            source: .eventDetail
        )
    }

    private func attemptOpenLevel(
        level: LevelManifest,
        routeContext: PlayRouteContext,
        source: LevelEntrySource
    ) {
        if hasOpenGameRoute(for: level.storageKey) {
            return
        }

        let now = Date.now
        currentDate = now
        let behavior = routeContext.behavior
        let policy = behavior.entryPolicy(for: source)

        guard let profile = currentProfile else { return }
        let consumeResult = playerProfileStore.consumeLifeIfNeeded(
            for: policy,
            at: now,
            profile: profile,
            calendar: appCalendar
        )
        lifeBalance = consumeResult.balance

        switch consumeResult {
        case .notRequired, .consumed:
            pushLevelRoute(
                level: level,
                routeContext: routeContext,
                source: source
            )
            saveContext(reason: "attempt_open_level.success")
        case .unavailable:
            pendingLevelEntry = PendingLevelEntry(
                storageKey: level.storageKey,
                routeContext: routeContext,
                source: source
            )
            activeSheet = .lifeDepleted
            saveContext(reason: "attempt_open_level.unavailable")
        }
    }

    private func handleRewardedLifeRequest() async {
        guard let profile = currentProfile else { return }
        let dayKey = todayQuotaKey
        guard rewardedAdQuota.canWatch(on: dayKey) else {
            await refreshCurrentContext(presentDailyPopup: false)
            return
        }

        let outcome = await rewardedAdService.presentRewardedAd()

        switch outcome {
        case .rewarded:
            rewardedAdQuota.recordWatch(on: dayKey)
            _ = playerProfileStore.grantRewardedLife(
                at: Date.now,
                profile: profile,
                calendar: appCalendar
            )
            saveContext(reason: "rewarded_life")
            await refreshCurrentContext(presentDailyPopup: false)

            if let pendingLevelEntry,
               let level = levelRepository.level(storageKey: pendingLevelEntry.storageKey) {
                activeSheet = nil
                self.pendingLevelEntry = nil
                attemptOpenLevel(
                    level: level,
                    routeContext: pendingLevelEntry.routeContext,
                    source: pendingLevelEntry.source
                )
            } else {
                activeSheet = nil
            }
        case .cancelled, .failed:
            await refreshCurrentContext(presentDailyPopup: false)
        }
    }

    private func pushLevelRoute(
        level: LevelManifest,
        routeContext: PlayRouteContext,
        source: LevelEntrySource
    ) {
        switch routeContext {
        case .journey:
            let chapterID = journeyRepository.chapter(containingLevelStorageKey: level.storageKey)?.id
            AppLogger.levelStarted(storageKey: level.storageKey, chapterID: chapterID)
        case let .dailyToday(dayKey, monthID, _, _):
            AppLogger.dailyChallengeOpened(
                dayKey: dayKey,
                storageKey: level.storageKey,
                eventID: monthID
            )
        case let .monthlyFreeplay(monthID, _, _):
            AppLogger.eventArtworkStarted(eventID: monthID, storageKey: level.storageKey)
        }

        pendingLevelEntry = nil

        let targetTab = tabForRouteContext(routeContext)
        selectedTab = targetTab

        if source == .completionNextLevel {
            setPath([.game(level.storageKey, routeContext)], for: targetTab)
        } else {
            appendPath(.game(level.storageKey, routeContext), for: targetTab)
        }
    }

    private func openCollectionBook(_ chapterID: String?) {
        AppLogger.collectionBookOpened(chapterID: chapterID)
        appendPath(.collectionBook(chapterID), for: selectedTab)
    }

    private func dismissTopRoute() {
        switch selectedTab {
        case .journey:
            if !journeyPath.isEmpty { journeyPath.removeLast() }
        case .daily:
            if !dailyPath.isEmpty { dailyPath.removeLast() }
        case .library:
            if !libraryPath.isEmpty { libraryPath.removeLast() }
        }
    }

    private func handleLevelCompletion(
        level: LevelManifest,
        playContext: PlayRouteContext,
        filledCells: Int,
        completionRank: CompletionRank
    ) {
        let now = Date.now
        currentDate = now
        let profile = currentProfile
        let streakSummary = profile.map {
            playerProfileStore.registerCompletion(on: now, profile: $0, calendar: appCalendar)
        } ?? StreakProgressSummary(current: 0, best: 0, countedToday: false, awardedBadgeID: nil)
        let behavior = playContext.behavior

        switch playContext {
        case .journey:
            guard let chapter = journeyRepository.chapter(containingLevelStorageKey: level.storageKey) else {
                setPath([], for: selectedTab)
                return
            }

            var updatedProgressValues = progressValues
            updatedProgressValues[level.storageKey] = JourneyLevelProgressValue(
                filledCellCount: filledCells,
                completedAt: now,
                updatedAt: now
            )

            let updatedSnapshot = JourneyProgressSnapshot(
                catalog: journeyRepository.catalog,
                progressValues: updatedProgressValues
            )
            let destination = updatedSnapshot.completionDestination(afterCompleting: level.storageKey)
            let summary = LevelCompletionSummary(
                level: level,
                filledCells: filledCells,
                completionRank: completionRank,
                sourceContext: .journey(chapterID: chapter.id, chapterTitleKey: chapter.chapter.titleKey),
                destination: destination,
                streakSummary: streakSummary,
                chapterMissionSummary: makeChapterMissionSummary(
                    for: chapter.id,
                    overridingLevel: level,
                    completionRank: completionRank
                ),
                unlockedEventTitle: nil
            )

            AppLogger.levelCompleted(storageKey: level.storageKey, chapterID: chapter.id)
            if case let .chapterUnlocked(chapterID) = destination {
                AppLogger.chapterUnlocked(chapterID: chapterID)
            }
            saveContext(reason: "handle_level_completion.journey")
            replaceTopRoute(with: .completion(summary))
            fireJourneyCelebration(
                snapshot: updatedSnapshot,
                chapter: chapter,
                destination: destination,
                completionRank: completionRank
            )
        case let .dailyToday(dayKey, monthID, monthTitleKey, rewardTitleID):
            if behavior.shouldMarkDailyCompletion, let profile {
                _ = playerProfileStore.markDailyCompleted(dayKey: dayKey, profile: profile)
            }

            let unlockedEventTitle = profile.flatMap { profile in
                resolveUnlockedEventTitle(
                    eventID: monthID,
                    completedLevel: level,
                    profile: profile
                )
            }

            let summary = LevelCompletionSummary(
                level: level,
                filledCells: filledCells,
                completionRank: completionRank,
                sourceContext: .dailyToday(
                    dayKey: dayKey,
                    monthID: monthID,
                    monthTitleKey: monthTitleKey
                ),
                destination: behavior.fixedCompletionDestination ?? .returnHome,
                streakSummary: streakSummary,
                chapterMissionSummary: nil,
                unlockedEventTitle: unlockedEventTitle
            )

            _ = rewardTitleID
            AppLogger.dailyChallengeCompleted(dayKey: dayKey, storageKey: level.storageKey, eventID: monthID)
            saveContext(reason: "handle_level_completion.daily")
            replaceTopRoute(with: .completion(summary))
            fireDailyCelebration(
                monthID: monthID,
                profile: profile,
                completionRank: completionRank
            )
        case let .monthlyFreeplay(monthID, monthTitleKey, _):
            let unlockedEventTitle = profile.flatMap { profile in
                resolveUnlockedEventTitle(
                    eventID: monthID,
                    completedLevel: level,
                    profile: profile
                )
            }

            let summary = LevelCompletionSummary(
                level: level,
                filledCells: filledCells,
                completionRank: completionRank,
                sourceContext: .monthlyFreeplay(
                    monthID: monthID,
                    monthTitleKey: monthTitleKey
                ),
                destination: behavior.fixedCompletionDestination ?? .returnHome,
                streakSummary: streakSummary,
                chapterMissionSummary: nil,
                unlockedEventTitle: unlockedEventTitle
            )

            AppLogger.eventArtworkCompleted(eventID: monthID, storageKey: level.storageKey)
            saveContext(reason: "handle_level_completion.event")
            replaceTopRoute(with: .completion(summary))
        }
    }

    private func handleCompletionDestination(_ destination: CompletionDestination) {
        switch destination {
        case let .nextLevel(storageKey):
            guard let level = levelRepository.level(storageKey: storageKey) else {
                setPath([], for: selectedTab)
                return
            }
            setPath([], for: selectedTab)
            attemptOpenLevel(
                level: level,
                routeContext: .journey,
                source: .completionNextLevel
            )
        case .chapterUnlocked:
            setPath([], for: selectedTab)
        case let .openCollectionBook(chapterID):
            setPath([.collectionBook(chapterID)], for: selectedTab)
            AppLogger.collectionBookOpened(chapterID: chapterID)
        case .returnHome:
            setPath([], for: selectedTab)
        case let .returnToMonth(monthID):
            returnToMonthDetail(monthID: monthID)
        }
    }

    private func resolveDailyChallenge(for date: Date) -> DailyChallengeDefinition? {
        guard let profile = currentProfile else { return nil }
        let monthID = MonthKey.id(for: date, calendar: appCalendar)
        let challenge = dailyRepository.challenge(
            for: date,
            profileKey: profile.profileKey,
            completedStorageKeys: completedLevelStorageKeys,
            pinnedSelection: profile.currentMonthlyDailySelection,
            recentHistory: playerProfileStore.monthlyDailyRecentHistory(monthID: monthID, profile: profile),
            calendar: appCalendar
        )

        if let challenge {
            let selection = MonthlyDailySelectionRecord(
                profileKey: profile.profileKey,
                dayKey: challenge.dayKey,
                monthID: challenge.month.id,
                storageKey: challenge.level.storageKey,
                timeZoneID: appCalendar.timeZone.identifier
            )
            if profile.currentMonthlyDailySelection != selection {
                playerProfileStore.persistMonthlyDailySelection(selection, profile: profile)
                playerProfileStore.recordMonthlyDailySelection(
                    storageKey: challenge.level.storageKey,
                    monthID: challenge.month.id,
                    profile: profile
                )
            }
        }

        return challenge
    }

    private func handleSheetDismissed() {
        if activeSheet == nil {
            pendingLevelEntry = nil
        }
    }

    private func hasOpenGameRoute(for storageKey: String) -> Bool {
        (journeyPath + dailyPath + libraryPath).contains { route in
            if case let .game(currentStorageKey, _) = route {
                return currentStorageKey == storageKey
            }
            return false
        }
    }

    private func replaceTopRoute(with route: AppRoute) {
        switch selectedTab {
        case .journey:
            if !journeyPath.isEmpty { journeyPath.removeLast() }
            journeyPath.append(route)
        case .daily:
            if !dailyPath.isEmpty { dailyPath.removeLast() }
            dailyPath.append(route)
        case .library:
            if !libraryPath.isEmpty { libraryPath.removeLast() }
            libraryPath.append(route)
        }
    }

    private func returnToMonthDetail(monthID: String) {
        let path = currentPath
        if path.count >= 2,
           path[path.count - 2] == .monthDetail(monthID: monthID) {
            switch selectedTab {
            case .journey: journeyPath.removeLast()
            case .daily: dailyPath.removeLast()
            case .library: libraryPath.removeLast()
            }
            return
        }

        AppLogger.eventDetailOpened(eventID: monthID)
        setPath([.monthDetail(monthID: monthID)], for: selectedTab)
    }

    private func handleEquipEventTitle(_ titleID: String) {
        guard
            let profile = currentProfile,
            let title = dailyRepository.eventTitleDefinition(id: titleID)
        else {
            return
        }

        playerProfileStore.equipEventTitle(title, profile: profile)
        saveContext(reason: "equip_event_title")
    }

    private func resolveUnlockedEventTitle(
        eventID: String?,
        completedLevel: LevelManifest,
        profile: PlayerProfile
    ) -> EventTitleDefinition? {
        guard
            let eventID,
            let event = dailyRepository.event(id: eventID)
        else {
            return nil
        }

        let completedAllLevels = event.dailyLevelKeys.allSatisfy { storageKey in
            if storageKey == completedLevel.storageKey {
                return true
            }
            return progressLookup[storageKey]?.completedAt != nil
        }

        guard completedAllLevels else {
            return nil
        }

        let unlocked = playerProfileStore.unlockMonthlyReward(event.rewardTitle, profile: profile)
        return unlocked ? event.rewardTitle : nil
    }

    private func makeChapterMissionSummary(
        for chapterID: String,
        overridingLevel level: LevelManifest,
        completionRank: CompletionRank
    ) -> ChapterMissionSummary? {
        guard let chapter = journeyRepository.chapter(id: chapterID) else {
            return nil
        }

        let completedCount = chapter.levels.count { chapterLevel in
            if chapterLevel.storageKey == level.storageKey {
                return true
            }
            return progressLookup[chapterLevel.storageKey]?.completedAt != nil
        }
        let perfectCount = chapter.levels.count { chapterLevel in
            if chapterLevel.storageKey == level.storageKey {
                return completionRank == .perfect
            }
            return progressLookup[chapterLevel.storageKey]?.bestCompletionRank == .perfect
        }

        let twoArtworksTarget = min(2, max(chapter.levels.count, 1))
        return ChapterMissionSummary(
            chapterID: chapter.id,
            chapterTitleKey: chapter.chapter.titleKey,
            missions: [
                ChapterMissionProgress(
                    id: "\(chapter.id).finish-two",
                    kind: .finishArtworks,
                    progressValue: completedCount,
                    targetValue: twoArtworksTarget
                ),
                ChapterMissionProgress(
                    id: "\(chapter.id).perfect-one",
                    kind: .earnPerfects,
                    progressValue: perfectCount,
                    targetValue: 1
                ),
                ChapterMissionProgress(
                    id: "\(chapter.id).finish-all",
                    kind: .finishAllArtworks,
                    progressValue: completedCount,
                    targetValue: max(chapter.levels.count, 1)
                )
            ]
        )
    }

    private func resetNoticeMessage(for notice: JourneyResetNotice) -> String {
        switch notice {
        case .journeyReset:
            return localization.string("alert.journeyReset.message")
        case .persistenceRecovered:
            return localization.string("alert.persistenceRecovered.message")
        }
    }

    private func resetNoticeTitle(for notice: JourneyResetNotice) -> String {
        switch notice {
        case .journeyReset:
            return localization.string("alert.journeyReset.title")
        case .persistenceRecovered:
            return localization.string("alert.persistenceRecovered.title")
        }
    }

    private func saveContext(reason: String) {
        do {
            try modelContext.save()
        } catch {
            AppLogger.persistenceSaveFailed(reason: reason, error: error)
            assertionFailure("ModelContext save failed (\(reason)): \(error)")
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

private struct DailyMissionPopupView: View {
    @Environment(AppLocalization.self) private var localization

    let challenge: DailyChallengeState
    let onStart: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.string("daily.popup.eyebrow"))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(challenge.accentColor)

            Text(challenge.level.localizedTitle(using: localization))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text(challenge.localizedSubtitle(using: localization))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)

            Label(localization.string("daily.popup.freeEntry"), systemImage: "heart.fill")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.accentGreen)

            VStack(spacing: 10) {
                Button(action: onStart) {
                    Text(localization.string("daily.popup.start"))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(challenge.accentColor)
                        )
                }

                Button(action: onClose) {
                    Text(localization.string("daily.popup.close"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                        )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .presentationBackground(.clear)
    }
}

private struct LifeDepletedSheet: View {
    @Environment(AppLocalization.self) private var localization

    let balance: LifeBalance
    let dailyChallenge: DailyChallengeState?
    let adService: RewardedAdService
    let canWatchMore: Bool
    let onClose: () -> Void
    let onWatchAd: () -> Void
    let onPlayDaily: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.string("life.depleted.title"))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text(localization.string("life.depleted.subtitle"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 12) {
                Label(
                    localization.string("life.depleted.count", balance.totalLives),
                    systemImage: "heart.fill"
                )
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.accentOrange)

                if let nextRefillDate = balance.nextRefillDate {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(
                            localization.string(
                                "life.depleted.timer",
                                countdownLabel(until: nextRefillDate, now: context.date)
                            )
                        )
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            if adService.canRequestAds {
                if canWatchMore {
                    Button(action: onWatchAd) {
                        HStack {
                            Text(localization.string(adService.rewardButtonTitleKey))
                            Spacer(minLength: 0)
                            Image(systemName: "play.rectangle.fill")
                        }
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(AppTheme.accentOrange)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!adService.isRewardButtonEnabled)
                } else {
                    Text(localization.string("life.depleted.adLimitReached"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let dailyChallenge {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localization.string("life.depleted.dailyCta"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.accentGreen)
                    Text(dailyChallenge.level.localizedTitle(using: localization))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(localization.string("life.depleted.dailyDescription"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)

                    Button(action: onPlayDaily) {
                        Text(localization.string("life.depleted.playDaily"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.92))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                )
            }

            Button(action: onClose) {
                Text(localization.string("life.depleted.close"))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    private func countdownLabel(until nextRefillDate: Date, now: Date) -> String {
        let remaining = max(Int(nextRefillDate.timeIntervalSince(now)), 0)
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

@MainActor
@Observable
final class RewardedAdService: NSObject {
    enum Availability: Hashable {
        case unavailable
        case loading
        case ready
        case failed
    }

    enum RewardOutcome: Hashable {
        case rewarded
        case cancelled
        case failed
    }

    private static let testRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    var canRequestAds = false
    var availability: Availability = .unavailable
    var isPresenting = false
    var lastErrorMessage: String?

    private let rewardedAdUnitID: String
    private var hasStartedSDK = false

#if canImport(GoogleMobileAds)
    private var rewardedAd: RewardedAd?
    private var rewardContinuation: CheckedContinuation<RewardOutcome, Never>?
    private var didEarnReward = false
#endif

    init(rewardedAdUnitID: String = RewardedAdService.testRewardedAdUnitID) {
        self.rewardedAdUnitID = rewardedAdUnitID
        super.init()
    }

    var isRewardButtonEnabled: Bool {
        canRequestAds && availability != .loading && !isPresenting
    }

    var rewardButtonTitleKey: String {
        switch availability {
        case .ready:
            return "life.depleted.watchAd"
        case .loading:
            return "life.depleted.loadingAd"
        case .failed, .unavailable:
            return "life.depleted.retryAd"
        }
    }

    /// SDK を起動し、UMP 同意を取得してから広告をプリロードする。
    /// SDK 未導入時（canImport=false）は何もせず canRequestAds=false のまま。
    func refreshConsentAndLoadAds() async {
        lastErrorMessage = nil
#if canImport(GoogleMobileAds)
        await startSDKIfNeeded()
#if canImport(UserMessagingPlatform)
        do {
            let parameters = RequestParameters()
            try await requestConsentInfoUpdate(with: parameters)
            try await loadAndPresentConsentFormIfRequired()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        canRequestAds = ConsentInformation.shared.canRequestAds
#else
        canRequestAds = true
#endif
        if canRequestAds {
            await preloadRewardedAd(force: true)
        } else {
            availability = .unavailable
        }
#else
        canRequestAds = false
        availability = .unavailable
#endif
    }

    func presentRewardedAd() async -> RewardOutcome {
        guard canRequestAds else {
            return .failed
        }

        guard !isPresenting else {
            return .failed
        }

#if canImport(GoogleMobileAds)
        if availability != .ready {
            await preloadRewardedAd(force: true)
        }

        guard let rewardedAd else {
            return .failed
        }

        isPresenting = true
        didEarnReward = false

        return await withCheckedContinuation { continuation in
            rewardContinuation = continuation
            rewardedAd.present(from: nil) { [weak self] in
                self?.didEarnReward = true
            }
        }
#else
        return .failed
#endif
    }

#if canImport(GoogleMobileAds)
    private func startSDKIfNeeded() async {
        guard !hasStartedSDK else { return }
        hasStartedSDK = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            MobileAds.shared.start { _ in
                continuation.resume()
            }
        }
    }

    private func preloadRewardedAd(force: Bool) async {
        guard canRequestAds else {
            availability = .unavailable
            rewardedAd = nil
            return
        }

        if !force, rewardedAd != nil, availability == .ready {
            return
        }

        availability = .loading

        do {
            let rewardedAd = try await RewardedAd.load(
                with: rewardedAdUnitID,
                request: Request()
            )
            rewardedAd.fullScreenContentDelegate = self
            self.rewardedAd = rewardedAd
            availability = .ready
            lastErrorMessage = nil
        } catch {
            rewardedAd = nil
            availability = .failed
            lastErrorMessage = error.localizedDescription
        }
    }

    private func finishPresentation(with outcome: RewardOutcome) {
        let continuation = rewardContinuation
        rewardContinuation = nil
        continuation?.resume(returning: outcome)
    }
#endif

#if canImport(UserMessagingPlatform)
    private func requestConsentInfoUpdate(with parameters: RequestParameters) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func loadAndPresentConsentFormIfRequired() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentForm.loadAndPresentIfRequired(from: nil) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
#endif
}

#if canImport(GoogleMobileAds)
extension RewardedAdService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isPresenting = false
        let outcome: RewardOutcome = didEarnReward ? .rewarded : .cancelled
        rewardedAd = nil
        availability = .unavailable
        finishPresentation(with: outcome)

        Task {
            await preloadRewardedAd(force: true)
        }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        isPresenting = false
        rewardedAd = nil
        availability = .failed
        lastErrorMessage = error.localizedDescription
        finishPresentation(with: .failed)

        Task {
            await preloadRewardedAd(force: true)
        }
    }
}
#endif

#Preview {
    AppView()
        .modelContainer(PixelColoringGamePersistence.makeInMemoryContainer())
        .environment(AppLocalization.preview)
}
