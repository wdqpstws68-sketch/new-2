import XCTest
import UIKit
@testable import PixelColoringGame

final class JourneyProgressSnapshotTests: XCTestCase {
    func testJourneyManifestDecodesAndResolvesOrderedLevelKeys() throws {
        let manifest = try JSONDecoder().decode(
            JourneyManifest.self,
            from: Data(
                """
                {
                  "schemaVersion": 2,
                  "titleKey": "journey.test.title",
                  "subtitleKey": "journey.test.subtitle",
                  "collectionTitleKey": "journey.test.collectionTitle",
                  "chapters": [
                    {
                      "id": "chapter-1",
                      "titleKey": "journey.test.chapter.one.title",
                      "subtitleKey": "journey.test.chapter.one.subtitle",
                      "accentHex": "FF8A2A",
                      "badgeTitleKey": "journey.test.chapter.one.badge",
                      "levelKeys": ["beta#1", "alpha#1", "delta#1", "gamma#1"]
                    },
                    {
                      "id": "chapter-2",
                      "titleKey": "journey.test.chapter.two.title",
                      "subtitleKey": "journey.test.chapter.two.subtitle",
                      "accentHex": "5DD64D",
                      "badgeTitleKey": "journey.test.chapter.two.badge",
                      "levelKeys": ["zeta#1", "epsilon#1", "theta#1", "eta#1"]
                    }
                  ]
                }
                """.utf8
            )
        )

        let catalog = JourneyCatalog(
            manifest: manifest,
            levels: [
                makeLevel(id: "alpha", titleKey: "level.alpha.title", sortOrder: 2),
                makeLevel(id: "beta", titleKey: "level.beta.title", sortOrder: 1),
                makeLevel(id: "gamma", titleKey: "level.gamma.title", sortOrder: 3),
                makeLevel(id: "delta", titleKey: "level.delta.title", sortOrder: 4),
                makeLevel(id: "epsilon", titleKey: "level.epsilon.title", sortOrder: 5),
                makeLevel(id: "zeta", titleKey: "level.zeta.title", sortOrder: 6),
                makeLevel(id: "eta", titleKey: "level.eta.title", sortOrder: 7),
                makeLevel(id: "theta", titleKey: "level.theta.title", sortOrder: 8)
            ]
        )

        XCTAssertEqual(catalog.chapters.map(\.id), ["chapter-1", "chapter-2"])
        XCTAssertEqual(catalog.chapters[0].levels.map(\.storageKey), ["beta#1", "alpha#1", "delta#1", "gamma#1"])
    }

    func testCurrentChapterIsFirstUnlockedIncompleteChapter() {
        let fixture = makeFixture()
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.beta.storageKey: makeProgressValue(filledCellCount: 2, completed: false)
            ]
        )

        XCTAssertEqual(snapshot.currentChapterID, "chapter-1")
        XCTAssertEqual(snapshot.unlockedChapterIDs, ["chapter-1"])
    }

    func testCompletingChapterUnlocksNextChapterAndKeepsReplayAvailable() {
        let fixture = makeFixture()
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.beta.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.gamma.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.delta.storageKey: makeProgressValue(filledCellCount: 4, completed: true)
            ]
        )

        XCTAssertEqual(snapshot.currentChapterID, "chapter-2")
        XCTAssertTrue(snapshot.unlockedChapterIDs.contains("chapter-2"))
        XCTAssertTrue(snapshot.canPlay(levelStorageKey: fixture.alpha.storageKey))
        XCTAssertEqual(snapshot.chapter(id: "chapter-1")?.nextPlayableLevelState?.level.storageKey, fixture.alpha.storageKey)
    }

    func testNextChapterStaysLockedUntilEveryLevelInCurrentChapterIsComplete() {
        let fixture = makeFixture()
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.beta.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.gamma.storageKey: makeProgressValue(filledCellCount: 4, completed: true)
            ]
        )

        XCTAssertFalse(snapshot.unlockedChapterIDs.contains("chapter-2"))
        XCTAssertEqual(snapshot.currentChapterID, "chapter-1")
        XCTAssertFalse(snapshot.canPlay(levelStorageKey: fixture.epsilon.storageKey))
    }

    func testCompletionDestinationReturnsNextLevelBeforeChapterUnlock() {
        let fixture = makeFixture()
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true)
            ]
        )

        XCTAssertEqual(
            snapshot.completionDestination(afterCompleting: fixture.alpha.storageKey),
            .nextLevel(storageKey: fixture.beta.storageKey)
        )
    }

    func testCompletionDestinationUnlocksNextChapterAtChapterEnd() {
        let fixture = makeFixture()
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.beta.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.gamma.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.delta.storageKey: makeProgressValue(filledCellCount: 4, completed: true)
            ]
        )

        XCTAssertEqual(
            snapshot.completionDestination(afterCompleting: fixture.delta.storageKey),
            .chapterUnlocked(chapterID: "chapter-2")
        )
    }

    func testCompletionDestinationOpensCollectionBookAfterFinalChapter() {
        let fixture = makeFixture()
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.beta.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.gamma.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.delta.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.epsilon.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.zeta.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.eta.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.theta.storageKey: makeProgressValue(filledCellCount: 4, completed: true)
            ]
        )

        XCTAssertEqual(
            snapshot.completionDestination(afterCompleting: fixture.theta.storageKey),
            .openCollectionBook(chapterID: "chapter-2")
        )
    }

    func testCollectionRevealAndAccessibilityStringsReflectProgress() throws {
        let fixture = makeFixture()
        let localization = makeLocalization()
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true)
            ]
        )

        let firstPage = try XCTUnwrap(snapshot.collectionRevealState.first)
        XCTAssertTrue(firstPage.artworkSlots[0].isRevealed)
        XCTAssertFalse(firstPage.artworkSlots[1].isRevealed)
        XCTAssertFalse(firstPage.artworkSlots[2].isRevealed)
        XCTAssertFalse(firstPage.artworkSlots[3].isRevealed)
        XCTAssertTrue(firstPage.accessibilityLabel(using: localization).contains("1 of 4 artworks revealed"))
        XCTAssertTrue(snapshot.chapter(id: "chapter-2")?.accessibilityLabel(using: localization).contains("locked") == true)
    }

    func testHomePreviewPresentationUsesSilhouetteForUnlockedIncompleteLevels() throws {
        let fixture = makeFixture()
        let initialSnapshot = JourneyProgressSnapshot(catalog: fixture.catalog, progressValues: [:])
        let initialLevelState = try XCTUnwrap(initialSnapshot.chapter(id: "chapter-1")?.levelStates.first)

        XCTAssertEqual(
            JourneyHomePreviewPresentation.make(levelState: initialLevelState, isUnlocked: true),
            .silhouette
        )

        let inProgressSnapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.beta.storageKey: makeProgressValue(filledCellCount: 2, completed: false)
            ]
        )
        let inProgressLevelState = try XCTUnwrap(
            inProgressSnapshot.chapter(id: "chapter-1")?.levelStates.first(where: { $0.level.storageKey == fixture.beta.storageKey })
        )

        XCTAssertEqual(
            JourneyHomePreviewPresentation.make(levelState: inProgressLevelState, isUnlocked: true),
            .silhouette
        )
    }

    func testHomePreviewPresentationUsesThumbnailForCompletedUnlockedLevelsAndLockedForFutureChapters() throws {
        let fixture = makeFixture()
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true)
            ]
        )
        let completedLevelState = try XCTUnwrap(
            snapshot.chapter(id: "chapter-1")?.levelStates.first(where: { $0.level.storageKey == fixture.alpha.storageKey })
        )
        let lockedLevelState = try XCTUnwrap(snapshot.chapter(id: "chapter-2")?.levelStates.first)

        XCTAssertEqual(
            JourneyHomePreviewPresentation.make(levelState: completedLevelState, isUnlocked: true),
            .thumbnail
        )
        XCTAssertEqual(
            JourneyHomePreviewPresentation.make(levelState: lockedLevelState, isUnlocked: false),
            .locked
        )
    }

    func testHeroDisplayTracksPrimaryCtaLevelForArtworkPreview() throws {
        let fixture = makeFixture()
        let localization = makeLocalization()
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true),
                fixture.beta.storageKey: makeProgressValue(filledCellCount: 2, completed: false)
            ]
        )

        let display = JourneyHeroDisplayModel.make(
            snapshot: snapshot,
            localization: localization,
            defaultCollectionChapterID: snapshot.currentChapterID ?? snapshot.chapters.last?.id
        )

        switch display.artwork {
        case let .level(levelState):
            XCTAssertEqual(levelState.level.storageKey, fixture.beta.storageKey)
            XCTAssertEqual(
                JourneyHomePreviewPresentation.make(levelState: levelState, isUnlocked: true),
                .silhouette
            )
        case .collection:
            XCTFail("Expected hero artwork to follow the active CTA level.")
        }
    }

    @MainActor
    func testDailyChallengeUsesActiveEventPoolAndArchivesPastEvents() throws {
        let dailyOne = makeLevel(id: "daily-one", titleKey: "Daily One", sortOrder: 1001)
        let dailyTwo = makeLevel(id: "daily-two", titleKey: "Daily Two", sortOrder: 1002)
        let levelRepository = LevelRepository(levels: [dailyOne, dailyTwo])
        let repository = DailyChallengeRepository(
            levelRepository: levelRepository,
            catalog: makeDailyCatalog(
                months: [
                    makeMonth(month: 1, levelKeys: [dailyOne.storageKey], accentHex: "FF8A2A"),
                    makeMonth(month: 4, levelKeys: [dailyTwo.storageKey], accentHex: "5DD64D")
                ]
            )
        )

        let challenge: DailyChallengeDefinition = try XCTUnwrap(
            repository.challenge(for: makeDate("2026-04-12"))
        )

        XCTAssertEqual(challenge.level.storageKey, dailyTwo.storageKey)
        XCTAssertEqual(challenge.event?.id, "month-04")
        XCTAssertEqual(repository.archivedEvents(on: makeDate("2026-04-12")).map { $0.id }, ["month-01"])
    }

    @MainActor
    func testHomeSnapshotBuildsDailyStateAndChapterMissionProgress() throws {
        let fixture = makeFixture()
        let dailyOne = makeLevel(id: "daily-one", titleKey: "Daily One", sortOrder: 1001)
        let levelRepository = LevelRepository(levels: [fixture.alpha, fixture.beta, fixture.gamma, fixture.delta, fixture.epsilon, fixture.zeta, fixture.eta, fixture.theta, dailyOne])
        let dailyRepository = DailyChallengeRepository(
            levelRepository: levelRepository,
            catalog: makeDailyCatalog(months: [makeMonth(month: 4, levelKeys: [dailyOne.storageKey])])
        )

        let today = makeDate("2026-04-12")
        let todayKey = DayKey.string(from: today)
        let progressLookup = [
            fixture.alpha.storageKey: makeLevelProgress(
                for: fixture.alpha,
                completedAt: today,
                rank: .perfect
            ),
            dailyOne.storageKey: makeLevelProgress(
                for: dailyOne,
                completedAt: today,
                rank: .normal
            )
        ]
        let snapshot = JourneyProgressSnapshot(
            catalog: fixture.catalog,
            progressValues: [
                fixture.alpha.storageKey: makeProgressValue(filledCellCount: 4, completed: true, updatedAt: today)
            ]
        )
        let profile = PlayerProfile(
            lastActiveDayKey: todayKey,
            currentStreak: 3,
            bestStreak: 5,
            completedDailyDayKeysRaw: todayKey,
            earnedBadgeIDsRaw: BadgeDefinition.streak7.id,
            claimedMissionRewardIDsRaw: ""
        )

        let homeSnapshot = HomeProgressSnapshot(
            journeySnapshot: snapshot,
            dailyRepository: dailyRepository,
            progressLookup: progressLookup,
            lifeBalance: LifeBalance(
                refillableLives: 3,
                bonusLives: 0,
                maxRefillableLives: PlayerProfileStore.maxRefillableLives,
                refillInterval: PlayerProfileStore.refillInterval,
                nextRefillDate: nil
            ),
            profile: profile,
            currentDate: today
        )

        let dailyChallenge = try XCTUnwrap(homeSnapshot.dailyChallenge)
        let missions = try XCTUnwrap(homeSnapshot.chapterMissionSummary(for: "chapter-1"))

        XCTAssertTrue(dailyChallenge.isCompletedToday)
        XCTAssertEqual(homeSnapshot.streak.current, 3)
        XCTAssertEqual(homeSnapshot.badges.map(\.id), [BadgeDefinition.streak7.id])
        XCTAssertEqual(missions.missions.map(\.progressLabel), ["1/2", "1/1", "1/4"])
        XCTAssertEqual(homeSnapshot.dailyAlbumEntries.first?.level.storageKey, dailyOne.storageKey)
    }

    @MainActor
    func testHomeSnapshotTracksCurrentMonthArchiveAndEquippedTitle() throws {
        let januaryDaily = makeLevel(id: "daily-january", titleKey: "Daily January", sortOrder: 1001)
        let aprilDaily = makeLevel(id: "daily-april", titleKey: "Daily April", sortOrder: 1002)
        let levelRepository = LevelRepository(levels: [januaryDaily, aprilDaily])
        let repository = DailyChallengeRepository(
            levelRepository: levelRepository,
            catalog: makeDailyCatalog(
                months: [
                    makeMonth(month: 1, levelKeys: [januaryDaily.storageKey], accentHex: "7799CC"),
                    makeMonth(month: 4, levelKeys: [aprilDaily.storageKey], accentHex: "FF8A2A")
                ]
            )
        )

        let profile = PlayerProfile(
            earnedBadgeIDsRaw: "event-title.month-04",
            equippedTitleIDRaw: "event-title.month-04"
        )

        let homeSnapshot = HomeProgressSnapshot(
            journeySnapshot: JourneyProgressSnapshot(catalog: makeFixture().catalog, progressValues: [:]),
            dailyRepository: repository,
            progressLookup: [
                aprilDaily.storageKey: makeLevelProgress(for: aprilDaily, completedAt: makeDate("2026-04-12"), rank: .normal)
            ],
            lifeBalance: LifeBalance(
                refillableLives: 3,
                bonusLives: 0,
                maxRefillableLives: PlayerProfileStore.maxRefillableLives,
                refillInterval: PlayerProfileStore.refillInterval,
                nextRefillDate: nil
            ),
            profile: profile,
            currentDate: makeDate("2026-04-12")
        )

        XCTAssertEqual(homeSnapshot.dailyAlbumEntries.map { $0.level.storageKey }, [aprilDaily.storageKey])
        XCTAssertEqual(homeSnapshot.eventCollections.count, 2)
        XCTAssertEqual(homeSnapshot.eventCollections.first?.id, "month-04")
        XCTAssertEqual(homeSnapshot.eventCollections.first?.entries.map { $0.level.storageKey }, [aprilDaily.storageKey])
        XCTAssertTrue(homeSnapshot.eventCollections.first?.isTitleUnlocked == true)
        XCTAssertTrue(homeSnapshot.eventCollections.first?.isTitleEquipped == true)
        XCTAssertEqual(homeSnapshot.equippedEventTitle?.id, "event-title.month-04")
    }

    func testPlayRouteBehaviorSeparatesJourneyDailyAndMonthlyRules() {
        let journeyBehavior = PlayRouteContext.journey.behavior
        XCTAssertEqual(journeyBehavior.entryPolicy(for: .journeyHero), .journey(source: .journeyHero))
        XCTAssertFalse(journeyBehavior.shouldMarkDailyCompletion)
        XCTAssertNil(journeyBehavior.fixedCompletionDestination)
        XCTAssertNil(journeyBehavior.logEventID)

        let dailyBehavior = PlayRouteContext.dailyToday(
            dayKey: "2026-04-12",
            monthID: "month-04",
            monthTitleKey: "April Daily",
            rewardTitleID: "event-title.month-04"
        ).behavior
        XCTAssertEqual(dailyBehavior.entryPolicy(for: .dailyHero), .daily(source: .dailyHero))
        XCTAssertTrue(dailyBehavior.shouldMarkDailyCompletion)
        XCTAssertEqual(dailyBehavior.fixedCompletionDestination, .returnHome)
        XCTAssertEqual(dailyBehavior.logEventID, "month-04")

        let eventBehavior = PlayRouteContext.monthlyFreeplay(
            monthID: "month-04",
            monthTitleKey: "April Daily",
            rewardTitleID: "event-title.month-04"
        ).behavior
        XCTAssertEqual(eventBehavior.entryPolicy(for: .eventDetail), .freeEntry(source: .eventDetail))
        XCTAssertFalse(eventBehavior.shouldMarkDailyCompletion)
        XCTAssertEqual(eventBehavior.fixedCompletionDestination, .returnToMonth(monthID: "month-04"))
        XCTAssertEqual(eventBehavior.logEventID, "month-04")
    }

    @MainActor
    func testHomeSnapshotReturnsNilForUnknownEventDetailLookup() {
        let eventDaily = makeLevel(id: "daily-event", titleKey: "Daily Event", sortOrder: 1002)
        let levelRepository = LevelRepository(levels: [eventDaily])
        let repository = DailyChallengeRepository(
            levelRepository: levelRepository,
            catalog: makeDailyCatalog(months: [makeMonth(month: 4, levelKeys: [eventDaily.storageKey], accentHex: "FF8A2A")])
        )

        let homeSnapshot = HomeProgressSnapshot(
            journeySnapshot: JourneyProgressSnapshot(catalog: makeFixture().catalog, progressValues: [:]),
            dailyRepository: repository,
            progressLookup: [:],
            lifeBalance: LifeBalance(
                refillableLives: 3,
                bonusLives: 0,
                maxRefillableLives: PlayerProfileStore.maxRefillableLives,
                refillInterval: PlayerProfileStore.refillInterval,
                nextRefillDate: nil
            ),
            profile: nil,
            currentDate: makeDate("2026-04-12")
        )

        XCTAssertNil(homeSnapshot.eventCollection(eventID: "missing-event"))
    }

    @MainActor
    func testHomeSnapshotReflectsUnlockedEventTitleAfterAllEventArtworksComplete() throws {
        let firstEventLevel = makeLevel(id: "daily-event-one", titleKey: "Daily Event One", sortOrder: 1001)
        let secondEventLevel = makeLevel(id: "daily-event-two", titleKey: "Daily Event Two", sortOrder: 1002)
        let levelRepository = LevelRepository(levels: [firstEventLevel, secondEventLevel])
        let repository = DailyChallengeRepository(
            levelRepository: levelRepository,
            catalog: makeDailyCatalog(
                months: [makeMonth(month: 4, levelKeys: [firstEventLevel.storageKey, secondEventLevel.storageKey], accentHex: "FF8A2A")]
            )
        )

        let now = makeDate("2026-04-12")
        let profile = PlayerProfile(
            earnedBadgeIDsRaw: "event-title.month-04"
        )

        let homeSnapshot = HomeProgressSnapshot(
            journeySnapshot: JourneyProgressSnapshot(catalog: makeFixture().catalog, progressValues: [:]),
            dailyRepository: repository,
            progressLookup: [
                firstEventLevel.storageKey: makeLevelProgress(for: firstEventLevel, completedAt: now, rank: .normal),
                secondEventLevel.storageKey: makeLevelProgress(for: secondEventLevel, completedAt: now, rank: .perfect)
            ],
            lifeBalance: LifeBalance(
                refillableLives: 3,
                bonusLives: 0,
                maxRefillableLives: PlayerProfileStore.maxRefillableLives,
                refillInterval: PlayerProfileStore.refillInterval,
                nextRefillDate: nil
            ),
            profile: profile,
            currentDate: now
        )

        let eventState = try XCTUnwrap(homeSnapshot.eventCollection(eventID: "month-04"))
        XCTAssertEqual(eventState.completedEntryCount, 2)
        XCTAssertTrue(eventState.isCompleted)
        XCTAssertTrue(eventState.isTitleUnlocked)
    }

    @MainActor
    func testPlayerProfileStoreAdvancesAndResetsStreaks() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile()

        let first = store.registerCompletion(on: makeDate("2026-04-10"), profile: profile)
        let sameDay = store.registerCompletion(on: makeDate("2026-04-10"), profile: profile)
        let second = store.registerCompletion(on: makeDate("2026-04-11"), profile: profile)
        let skipped = store.registerCompletion(on: makeDate("2026-04-13"), profile: profile)

        XCTAssertTrue(first.countedToday)
        XCTAssertFalse(sameDay.countedToday)
        XCTAssertEqual(second.current, 2)
        XCTAssertEqual(skipped.current, 1)
    }

    private func makeFixture() -> (
        catalog: JourneyCatalog,
        alpha: LevelManifest,
        beta: LevelManifest,
        gamma: LevelManifest,
        delta: LevelManifest,
        epsilon: LevelManifest,
        zeta: LevelManifest,
        eta: LevelManifest,
        theta: LevelManifest
    ) {
        let alpha = makeLevel(id: "alpha", titleKey: "level.alpha.title", sortOrder: 1)
        let beta = makeLevel(id: "beta", titleKey: "level.beta.title", sortOrder: 2)
        let gamma = makeLevel(id: "gamma", titleKey: "level.gamma.title", sortOrder: 3)
        let delta = makeLevel(id: "delta", titleKey: "level.delta.title", sortOrder: 4)
        let epsilon = makeLevel(id: "epsilon", titleKey: "level.epsilon.title", sortOrder: 5)
        let zeta = makeLevel(id: "zeta", titleKey: "level.zeta.title", sortOrder: 6)
        let eta = makeLevel(id: "eta", titleKey: "level.eta.title", sortOrder: 7)
        let theta = makeLevel(id: "theta", titleKey: "level.theta.title", sortOrder: 8)

        let manifest = JourneyManifest(
            schemaVersion: 2,
            titleKey: "journey.test.title",
            subtitleKey: "journey.test.subtitle",
            collectionTitleKey: "journey.test.collectionTitle",
            chapters: [
                JourneyChapter(
                    id: "chapter-1",
                    titleKey: "journey.test.chapter.one.title",
                    subtitleKey: "journey.test.chapter.one.subtitle",
                    accentHex: "FF8A2A",
                    badgeTitleKey: "journey.test.chapter.one.badge",
                    levelKeys: [alpha.storageKey, beta.storageKey, gamma.storageKey, delta.storageKey]
                ),
                JourneyChapter(
                    id: "chapter-2",
                    titleKey: "journey.test.chapter.two.title",
                    subtitleKey: "journey.test.chapter.two.subtitle",
                    accentHex: "5DD64D",
                    badgeTitleKey: "journey.test.chapter.two.badge",
                    levelKeys: [epsilon.storageKey, zeta.storageKey, eta.storageKey, theta.storageKey]
                )
            ]
        )

        return (
            JourneyCatalog(manifest: manifest, levels: [alpha, beta, gamma, delta, epsilon, zeta, eta, theta]),
            alpha,
            beta,
            gamma,
            delta,
            epsilon,
            zeta,
            eta,
            theta
        )
    }

    private func makeLevel(id: String, titleKey: String, sortOrder: Int) -> LevelManifest {
        LevelManifest(
            schemaVersion: 2,
            id: id,
            levelVersion: 1,
            titleKey: titleKey,
            prompt: titleKey,
            boardWidth: 2,
            boardHeight: 2,
            difficultyKey: "level.difficulty.easy",
            estimatedMinutes: 3,
            sortOrder: sortOrder,
            categoryKey: "level.category.test",
            paintableCellCount: 4,
            palette: [
                LevelPaletteEntry(index: 0, hex: "#FF0000", targetCellCount: 4)
            ],
            cells: [0, 0, 0, 0],
            perColorCellIndices: [
                LevelColorCellIndexGroup(index: 0, cellIndices: [0, 1, 2, 3])
            ],
            thumbnailAsset: "\(id)-thumb",
            solvedAsset: "\(id)-solved"
        )
    }

    private func makeProgressValue(filledCellCount: Int, completed: Bool, updatedAt: Date = .now) -> JourneyLevelProgressValue {
        JourneyLevelProgressValue(
            filledCellCount: filledCellCount,
            completedAt: completed ? updatedAt : nil,
            updatedAt: updatedAt
        )
    }

    private func makeLocalization() -> AppLocalization {
        let suiteName = "JourneyProgressSnapshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }

        return AppLocalization(
            defaults: defaults,
            preferredLanguages: [AppLanguage.english.rawValue],
            persistSelection: false
        )
    }

    private func makeDate(_ rawValue: String) -> Date {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents()
        components.calendar = Calendar.current
        components.timeZone = Calendar.current.timeZone
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        return components.date!
    }

    private func makeLevelProgress(
        for level: LevelManifest,
        completedAt: Date,
        rank: CompletionRank
    ) -> LevelProgress {
        LevelProgress(
            storageKey: level.storageKey,
            levelID: level.id,
            levelVersion: level.levelVersion,
            filledCellsData: FilledCellsCodec.encode(Set(level.perColorCellIndices?.first?.cellIndices ?? []), cellCount: level.boardCellCount),
            filledCellCount: level.paintableCellCount,
            activeColorIndex: level.palette.first?.index,
            hintCount: 0,
            incorrectPaintAttemptCount: rank == .perfect ? 0 : 1,
            firstCompletedAt: completedAt,
            completedAt: completedAt,
            lastPlayedAt: completedAt,
            bestCompletionRankRaw: rank.rawValue,
            updatedAt: completedAt
        )
    }

    private func makeDailyCatalog(months: [EventManifest]) -> DailyCatalogManifest {
        DailyCatalogManifest(
            titleKey: "Monthly Daily",
            subtitleKey: "A fresh hand-picked pixel artwork every day.",
            albumTitleKey: "Monthly Album",
            months: months
        )
    }

    private func makeMonth(month: Int, levelKeys: [String], accentHex: String = "FF8A2A") -> EventManifest {
        EventManifest(
            id: String(format: "month-%02d", month),
            month: month,
            titleKey: "Month \(month)",
            bannerKey: "Monthly banner \(month)",
            accentHex: accentHex,
            archiveTitleKey: "Archive \(month)",
            archiveSubtitleKey: "Archive subtitle \(month)",
            rewardTitleID: String(format: "event-title.month-%02d", month),
            rewardTitleKey: "Reward \(month)",
            rewardSubtitleKey: "Reward subtitle \(month)",
            entries: levelKeys.enumerated().map { index, levelKey in
                MonthlyDailyEntryManifest(
                    index: index + 1,
                    levelKey: levelKey,
                    difficulty: "Easy",
                    selectionPhase: index < 10 ? .early : (index < 20 ? .mid : .late),
                    availability: .always
                )
            }
        )
    }
}

final class LevelPreviewRendererTests: XCTestCase {
    @MainActor
    func testRenderSilhouetteProducesVisibleDarkImageWithStableRasterShape() throws {
        let compact = try XCTUnwrap(
            LevelPreviewRenderer.renderSilhouette(level: makeSingleCellLevel(), side: 40)
        )
        let expanded = try XCTUnwrap(
            LevelPreviewRenderer.renderSilhouette(level: makeSingleCellLevel(), side: 120)
        )
        let centerPixel = try XCTUnwrap(centerPixel(in: compact))

        XCTAssertEqual(compact.size.width, 30, accuracy: 0.01)
        XCTAssertEqual(compact.size.height, 30, accuracy: 0.01)
        XCTAssertEqual(expanded.size.width, 30, accuracy: 0.01)
        XCTAssertEqual(expanded.size.height, 30, accuracy: 0.01)
        XCTAssertEqual(compact.pngData(), expanded.pngData())
        XCTAssertGreaterThan(centerPixel.a, 200)
        XCTAssertLessThan(centerPixel.r, 25)
        XCTAssertLessThan(centerPixel.g, 25)
        XCTAssertLessThan(centerPixel.b, 25)
    }

    private func makeSingleCellLevel() -> LevelManifest {
        LevelManifest(
            schemaVersion: 2,
            id: "single",
            levelVersion: 1,
            titleKey: "level.single.title",
            prompt: "single",
            boardWidth: 1,
            boardHeight: 1,
            difficultyKey: "level.difficulty.easy",
            estimatedMinutes: 1,
            sortOrder: 1,
            categoryKey: "level.category.test",
            paintableCellCount: 1,
            palette: [
                LevelPaletteEntry(index: 0, hex: "#FF0000", targetCellCount: 1)
            ],
            cells: [0],
            perColorCellIndices: [
                LevelColorCellIndexGroup(index: 0, cellIndices: [0])
            ],
            thumbnailAsset: "single-thumb",
            solvedAsset: "single-solved"
        )
    }

    private func centerPixel(in image: UIImage) -> (r: Int, g: Int, b: Int, a: Int)? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let x = cgImage.width / 2
        let y = cgImage.height / 2
        let offset = y * bytesPerRow + x * bytesPerPixel
        return (
            r: Int(bytes[offset]),
            g: Int(bytes[offset + 1]),
            b: Int(bytes[offset + 2]),
            a: Int(bytes[offset + 3])
        )
    }
}

@MainActor
final class GrantRewardedLifeTests: XCTestCase {
    func test_grantFromDepleted_addsOneRefillableLife() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile()
        // 枯渇状態を作る
        profile.didSeedInitialLives = true
        profile.refillableLives = 0
        profile.bonusLives = 0
        profile.lifeRefillAnchorAt = Date.now

        let balance = store.grantRewardedLife(at: Date.now, profile: profile, calendar: .current)

        XCTAssertEqual(profile.refillableLives, 1)
        XCTAssertEqual(balance.totalLives, 1)
    }

    func test_grantNeverExceedsMaxRefillable() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile()
        profile.didSeedInitialLives = true
        profile.refillableLives = PlayerProfileStore.maxRefillableLives
        profile.bonusLives = 0
        profile.lifeRefillAnchorAt = nil

        _ = store.grantRewardedLife(at: Date.now, profile: profile, calendar: .current)

        XCTAssertEqual(profile.refillableLives, PlayerProfileStore.maxRefillableLives)
    }
}
