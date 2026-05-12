import XCTest
@testable import PixelColoringGame

@MainActor
final class DailyExperienceTests: XCTestCase {
    func testChallengePrefersUnfinishedLevels() throws {
        let levels = [
            makeLevel(id: "daily-a", sortOrder: 1),
            makeLevel(id: "daily-b", sortOrder: 2),
            makeLevel(id: "daily-c", sortOrder: 3),
        ]
        let repository = makeRepository(levels: levels)

        let challenge = try XCTUnwrap(
            repository.challenge(
                for: makeDate("2026-04-13"),
                completedStorageKeys: [levels[0].storageKey, levels[1].storageKey]
            )
        )

        XCTAssertEqual(challenge.level.storageKey, levels[2].storageKey)
        XCTAssertEqual(challenge.month.id, "month-04")
        XCTAssertFalse(challenge.isReplayPick)
    }

    func testChallengeKeepsPinnedArtworkForSameDay() throws {
        let levels = [
            makeLevel(id: "daily-a", sortOrder: 1),
            makeLevel(id: "daily-b", sortOrder: 2),
            makeLevel(id: "daily-c", sortOrder: 3),
        ]
        let repository = makeRepository(levels: levels)
        let dayKey = "2026-04-13"

        let challenge = try XCTUnwrap(
            repository.challenge(
                for: makeDate(dayKey),
                completedStorageKeys: [levels[1].storageKey],
                pinnedSelection: MonthlyDailySelectionRecord(
                    profileKey: "primary",
                    dayKey: dayKey,
                    monthID: "month-04",
                    storageKey: levels[1].storageKey,
                    timeZoneID: "Asia/Shanghai"
                )
            )
        )

        XCTAssertEqual(challenge.level.storageKey, levels[1].storageKey)
    }

    func testChallengeFallsBackToReplayPickAfterMonthCompletion() throws {
        let levels = [
            makeLevel(id: "daily-a", sortOrder: 1),
            makeLevel(id: "daily-b", sortOrder: 2),
            makeLevel(id: "daily-c", sortOrder: 3),
        ]
        let repository = makeRepository(levels: levels)

        let challenge = try XCTUnwrap(
            repository.challenge(
                for: makeDate("2026-04-23"),
                completedStorageKeys: Set(levels.map(\.storageKey))
            )
        )

        XCTAssertTrue(challenge.isReplayPick)
        XCTAssertTrue(levels.map(\.storageKey).contains(challenge.level.storageKey))
    }

    func testHomeSnapshotTracksCompletedMonthAndUnlockedRewardState() throws {
        let levels = [
            makeLevel(id: "daily-a", sortOrder: 1),
            makeLevel(id: "daily-b", sortOrder: 2),
            makeLevel(id: "daily-c", sortOrder: 3),
        ]
        let repository = makeRepository(levels: levels)
        let date = makeDate("2026-04-23")
        let challenge = try XCTUnwrap(
            repository.challenge(
                for: date,
                completedStorageKeys: Set(levels.map(\.storageKey))
            )
        )
        let rewardID = try XCTUnwrap(repository.event(id: "month-04")?.rewardTitleID)
        let progressLookup = Dictionary(
            uniqueKeysWithValues: levels.map { level in
                (level.storageKey, makeCompletedProgress(for: level, completedAt: date))
            }
        )
        let profile = PlayerProfile(
            completedDailyDayKeysRaw: StoredStringSetCodec.encode([challenge.dayKey]),
            earnedBadgeIDsRaw: StoredStringSetCodec.encode([rewardID]),
            completedMonthlyRewardIDsRaw: StoredStringSetCodec.encode([rewardID])
        )

        let snapshot = HomeProgressSnapshot(
            journeySnapshot: makeJourneySnapshot(),
            dailyRepository: repository,
            progressLookup: progressLookup,
            lifeBalance: makeLifeBalance(),
            profile: profile,
            resolvedDailyChallenge: challenge,
            currentDate: date
        )

        let dailyChallenge = try XCTUnwrap(snapshot.dailyChallenge)
        let monthCollection = try XCTUnwrap(snapshot.eventCollection(eventID: "month-04"))

        XCTAssertTrue(dailyChallenge.isReplayPick)
        XCTAssertTrue(dailyChallenge.isMonthCompleted)
        XCTAssertEqual(dailyChallenge.completedMonthCount, levels.count)
        XCTAssertEqual(dailyChallenge.totalMonthCount, levels.count)
        XCTAssertTrue(dailyChallenge.isMonthlyRewardUnlocked)
        XCTAssertTrue(monthCollection.isCompleted)
        XCTAssertEqual(monthCollection.completedEntryCount, levels.count)
    }

    private func makeRepository(levels: [LevelManifest]) -> DailyChallengeRepository {
        let catalog = DailyCatalogManifest(
            titleKey: "Monthly Daily",
            subtitleKey: "A fresh hand-picked pixel artwork every day.",
            albumTitleKey: "Monthly Album",
            months: [
                EventManifest(
                    id: "month-04",
                    month: 4,
                    titleKey: "April Daily",
                    bannerKey: "Fresh notebooks, flower trails, and bright new starts.",
                    accentHex: "F2B84B",
                    archiveTitleKey: "April Archive",
                    archiveSubtitleKey: "Revisit April's bright and breezy collection.",
                    rewardTitleID: "event-title.month-04",
                    rewardTitleKey: "Bloom Scout",
                    rewardSubtitleKey: "Complete every April artwork to unlock this title.",
                    entries: levels.enumerated().map { index, level in
                        MonthlyDailyEntryManifest(
                            index: index + 1,
                            levelKey: level.storageKey,
                            difficulty: "Easy",
                            selectionPhase: index == 0 ? .early : (index == 1 ? .mid : .late),
                            availability: .always
                        )
                    }
                )
            ]
        )

        return DailyChallengeRepository(
            levelRepository: LevelRepository(bundle: .main, levels: levels),
            catalog: catalog
        )
    }

    private func makeLevel(id: String, sortOrder: Int) -> LevelManifest {
        LevelManifest(
            schemaVersion: 2,
            id: id,
            levelVersion: 1,
            titleKey: "level.\(id).title",
            prompt: id,
            boardWidth: 2,
            boardHeight: 2,
            difficultyKey: "level.difficulty.easy",
            estimatedMinutes: 3,
            sortOrder: sortOrder,
            categoryKey: "level.category.test",
            paintableCellCount: 4,
            palette: [
                LevelPaletteEntry(index: 0, hex: "#FFAA00", targetCellCount: 4)
            ],
            cells: [0, 0, 0, 0],
            perColorCellIndices: [
                LevelColorCellIndexGroup(index: 0, cellIndices: [0, 1, 2, 3])
            ],
            thumbnailAsset: "\(id)-thumb",
            solvedAsset: "\(id)-solved"
        )
    }

    private func makeDate(_ dayKey: String) -> Date {
        DayKey.date(from: dayKey) ?? .now
    }

    private func makeCompletedProgress(for level: LevelManifest, completedAt: Date) -> LevelProgress {
        LevelProgress(
            storageKey: level.storageKey,
            levelID: level.id,
            levelVersion: level.levelVersion,
            filledCellsData: Data([1, 1, 1, 1]),
            filledCellCount: level.paintableCellCount,
            activeColorIndex: nil,
            completedAt: completedAt,
            updatedAt: completedAt
        )
    }

    private func makeJourneySnapshot() -> JourneyProgressSnapshot {
        let manifest = JourneyManifest(
            schemaVersion: 2,
            titleKey: "journey.test.title",
            subtitleKey: "journey.test.subtitle",
            collectionTitleKey: "journey.test.collectionTitle",
            chapters: []
        )
        return JourneyProgressSnapshot(
            catalog: JourneyCatalog(manifest: manifest, levels: []),
            progressValues: [:]
        )
    }

    private func makeLifeBalance() -> LifeBalance {
        LifeBalance(
            refillableLives: 3,
            bonusLives: 0,
            maxRefillableLives: PlayerProfileStore.maxRefillableLives,
            refillInterval: PlayerProfileStore.refillInterval,
            nextRefillDate: nil
        )
    }
}
