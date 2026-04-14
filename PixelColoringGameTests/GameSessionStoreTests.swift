import XCTest
@testable import PixelColoringGame

@MainActor
final class GameSessionStoreTests: XCTestCase {
    func testCorrectTapCompletesColorAndAutoAdvances() {
        let level = makeLevel()
        let store = GameSessionStore(level: level, progress: nil)

        XCTAssertEqual(store.selectedColorIndex, 0)

        XCTAssertEqual(store.tapCell(at: 0), .correct)
        XCTAssertEqual(store.tapCell(at: 1), .correct)
        XCTAssertEqual(store.remainingCount(for: 0), 0)
        XCTAssertEqual(store.selectedColorIndex, 1)
        XCTAssertEqual(store.filledCells.count, 2)
    }

    func testIncorrectTapLeavesBoardUntouched() {
        let level = makeLevel()
        let store = GameSessionStore(level: level, progress: nil)

        XCTAssertEqual(store.tapCell(at: 2), .incorrect)
        XCTAssertTrue(store.filledCells.isEmpty)
        XCTAssertEqual(store.highlightedIncorrectCell, 2)
    }

    func testHintFillsNextCellForSelectedColor() {
        let level = makeLevel()
        let store = GameSessionStore(level: level, progress: nil)

        let hintedCell = store.applyHint()

        XCTAssertEqual(hintedCell, 0)
        XCTAssertTrue(store.filledCells.contains(0))
        XCTAssertEqual(store.remainingCount(for: 0), 1)
    }

    func testCompletionSetsCompletedAt() {
        let level = makeLevel()
        let store = GameSessionStore(level: level, progress: nil)

        _ = store.tapCell(at: 0)
        _ = store.tapCell(at: 1)
        _ = store.tapCell(at: 2)
        _ = store.tapCell(at: 3)

        XCTAssertTrue(store.isCompleted)
        XCTAssertNotNil(store.completedAt)
    }

    func testPerfectRankRequiresNoHintsAndNoIncorrectAttempts() {
        let level = makeLevel()
        let perfectStore = GameSessionStore(level: level, progress: nil)

        _ = perfectStore.tapCell(at: 0)
        _ = perfectStore.tapCell(at: 1)
        _ = perfectStore.tapCell(at: 2)
        _ = perfectStore.tapCell(at: 3)

        XCTAssertEqual(perfectStore.completionRank, .perfect)

        let hintedStore = GameSessionStore(level: level, progress: nil)
        _ = hintedStore.applyHint()
        _ = hintedStore.tapCell(at: 1)
        _ = hintedStore.tapCell(at: 2)
        _ = hintedStore.tapCell(at: 3)

        XCTAssertEqual(hintedStore.completionRank, .normal)

        let mistakenStore = GameSessionStore(level: level, progress: nil)
        _ = mistakenStore.tapCell(at: 2)
        _ = mistakenStore.tapCell(at: 0)
        _ = mistakenStore.tapCell(at: 1)
        _ = mistakenStore.tapCell(at: 2)
        _ = mistakenStore.tapCell(at: 3)

        XCTAssertEqual(mistakenStore.completionRank, .normal)
        XCTAssertEqual(mistakenStore.incorrectPaintAttemptCount, 1)
    }

    func testStartFreshIgnoresCompletedProgressDuringReplay() {
        let level = makeLevel()
        let completedProgress = LevelProgress(
            storageKey: level.storageKey,
            levelID: level.id,
            levelVersion: level.levelVersion,
            filledCellsData: FilledCellsCodec.encode(Set([0, 1, 2, 3]), cellCount: level.boardCellCount),
            filledCellCount: 4,
            activeColorIndex: 1,
            hintCount: 2,
            incorrectPaintAttemptCount: 1,
            firstCompletedAt: .now,
            completedAt: .now,
            lastPlayedAt: .now,
            bestCompletionRankRaw: CompletionRank.normal.rawValue,
            updatedAt: .now
        )

        let replayStore = GameSessionStore(level: level, progress: completedProgress, startFresh: true)

        XCTAssertTrue(replayStore.filledCells.isEmpty)
        XCTAssertNil(replayStore.completedAt)
        XCTAssertEqual(replayStore.hintCount, 0)
        XCTAssertEqual(replayStore.incorrectPaintAttemptCount, 0)
    }

    private func makeLevel() -> LevelManifest {
        LevelManifest(
            schemaVersion: 2,
            id: "test-level",
            levelVersion: 1,
            titleKey: "level.test.title",
            prompt: "Test",
            boardWidth: 2,
            boardHeight: 2,
            difficultyKey: "level.difficulty.easy",
            estimatedMinutes: 1,
            sortOrder: 0,
            categoryKey: "level.category.test",
            paintableCellCount: 4,
            palette: [
                LevelPaletteEntry(index: 0, hex: "#FF0000", targetCellCount: 2),
                LevelPaletteEntry(index: 1, hex: "#00FF00", targetCellCount: 2)
            ],
            cells: [0, 0, 1, 1],
            perColorCellIndices: [
                LevelColorCellIndexGroup(index: 0, cellIndices: [0, 1]),
                LevelColorCellIndexGroup(index: 1, cellIndices: [2, 3])
            ],
            thumbnailAsset: "test-thumb",
            solvedAsset: "test-solved"
        )
    }
}

@MainActor
final class PlayerProfileStoreTests: XCTestCase {
    func testInitialSeedAddsRefillableAndBonusLivesOnce() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile()

        XCTAssertTrue(store.seedInitialLivesIfNeeded(profile: profile))
        XCTAssertEqual(profile.refillableLives, 3)
        XCTAssertEqual(profile.bonusLives, 3)
        XCTAssertFalse(store.seedInitialLivesIfNeeded(profile: profile))
        XCTAssertEqual(profile.refillableLives, 3)
        XCTAssertEqual(profile.bonusLives, 3)
    }

    func testLifeConsumptionUsesBonusBeforeRefillable() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile(
            refillableLives: 3,
            bonusLives: 2,
            didSeedInitialLives: true
        )

        let first = store.consumeLifeIfNeeded(
            for: .journey(source: .journeyHero),
            at: makeDate("2026-04-12T08:00:00Z"),
            profile: profile
        )
        let second = store.consumeLifeIfNeeded(
            for: .journey(source: .journeyHero),
            at: makeDate("2026-04-12T08:01:00Z"),
            profile: profile
        )
        let third = store.consumeLifeIfNeeded(
            for: .journey(source: .journeyHero),
            at: makeDate("2026-04-12T08:02:00Z"),
            profile: profile
        )

        XCTAssertEqual(first.balance.bonusLives, 1)
        XCTAssertEqual(first.balance.refillableLives, 3)
        XCTAssertEqual(second.balance.bonusLives, 0)
        XCTAssertEqual(second.balance.refillableLives, 3)
        XCTAssertEqual(third.balance.bonusLives, 0)
        XCTAssertEqual(third.balance.refillableLives, 2)
        XCTAssertNotNil(profile.lifeRefillAnchorAt)
    }

    func testResolveLivesRecoversOneEveryEightHours() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile(
            refillableLives: 0,
            bonusLives: 0,
            lifeRefillAnchorAt: makeDate("2026-04-12T00:00:00Z"),
            didSeedInitialLives: true
        )

        let sevenHours = store.resolveLives(
            at: makeDate("2026-04-12T07:59:59Z"),
            profile: profile
        )
        XCTAssertEqual(sevenHours.refillableLives, 0)

        let eightHours = store.resolveLives(
            at: makeDate("2026-04-12T08:00:00Z"),
            profile: profile
        )
        XCTAssertEqual(eightHours.refillableLives, 1)

        let twentyFourHours = store.resolveLives(
            at: makeDate("2026-04-13T00:00:00Z"),
            profile: profile
        )
        XCTAssertEqual(twentyFourHours.refillableLives, 3)
        XCTAssertNil(profile.lifeRefillAnchorAt)
    }

    func testRewardedLifeAddsSingleRefillableLife() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile(
            refillableLives: 0,
            bonusLives: 0,
            lifeRefillAnchorAt: makeDate("2026-04-12T00:00:00Z"),
            didSeedInitialLives: true
        )

        let balance = store.grantRewardedLife(
            at: makeDate("2026-04-12T04:00:00Z"),
            profile: profile
        )

        XCTAssertEqual(balance.refillableLives, 1)
        XCTAssertEqual(balance.bonusLives, 0)
        XCTAssertNotNil(profile.lifeRefillAnchorAt)
    }

    func testDailyPopupPresentationUsesDayKey() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile(didSeedInitialLives: true)

        XCTAssertTrue(store.shouldPresentDailyPopup(dayKey: "2026-04-12", profile: profile))
        store.markDailyPopupPresented(dayKey: "2026-04-12", profile: profile)
        XCTAssertFalse(store.shouldPresentDailyPopup(dayKey: "2026-04-12", profile: profile))
        XCTAssertTrue(store.shouldPresentDailyPopup(dayKey: "2026-04-13", profile: profile))
    }

    func testEventTitlesUnlockOnceAndEquipPersistently() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile()
        let title = EventTitleDefinition(
            id: "event-title.lantern",
            titleKey: "event.test.active.rewardTitle",
            subtitleKey: "event.test.active.rewardSubtitle",
            eventID: "lantern"
        )

        XCTAssertTrue(store.unlockEventTitle(title, profile: profile))
        XCTAssertFalse(store.unlockEventTitle(title, profile: profile))

        store.equipEventTitle(title, profile: profile)

        XCTAssertTrue(profile.earnedBadgeIDs.contains(title.id))
        XCTAssertEqual(profile.equippedTitleID, title.id)
    }

    private func makeDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }
}
