import XCTest
import CoreGraphics
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

    func testPaintCellFillsMatchingColorAndSkipsOthersWithoutPenalty() {
        let store = GameSessionStore(level: makeLevel(), progress: nil)

        XCTAssertEqual(store.paintCell(at: 0, color: 0), .correct)
        XCTAssertTrue(store.filledCells.contains(0))

        // Re-painting an already filled cell is a no-op.
        XCTAssertEqual(store.paintCell(at: 0, color: 0), .alreadyFilled)

        // Sweeping over a non-matching cell is ignored — never a penalty.
        XCTAssertEqual(store.paintCell(at: 2, color: 0), .ignored)
        XCTAssertFalse(store.filledCells.contains(2))
        XCTAssertEqual(store.incorrectPaintAttemptCount, 0)
        XCTAssertNil(store.highlightedIncorrectCell)
    }

    func testPaintCellLocksColorUntilStrokeAdvances() {
        let store = GameSessionStore(level: makeLevel(), progress: nil)

        XCTAssertEqual(store.paintCell(at: 0, color: 0), .correct)
        XCTAssertEqual(store.paintCell(at: 1, color: 0), .correct)
        XCTAssertEqual(store.remainingCount(for: 0), 0)

        // A drag stays locked to its starting colour; selection only moves on
        // once the stroke explicitly advances.
        XCTAssertEqual(store.selectedColorIndex, 0)
        store.advanceSelectionIfColorCompleted()
        XCTAssertEqual(store.selectedColorIndex, 1)
    }

    func testDragPaintCompletesArtworkWithPerfectRank() {
        let store = GameSessionStore(level: makeLevel(), progress: nil)

        // Stroke locked to colour 0, sweeping across a colour-1 cell too.
        _ = store.paintCell(at: 0, color: 0)
        _ = store.paintCell(at: 2, color: 0) // ignored (wrong colour)
        _ = store.paintCell(at: 1, color: 0)
        store.advanceSelectionIfColorCompleted()
        XCTAssertEqual(store.selectedColorIndex, 1)

        _ = store.paintCell(at: 2, color: 1)
        _ = store.paintCell(at: 3, color: 1)

        XCTAssertTrue(store.isCompleted)
        XCTAssertNotNil(store.completedAt)
        XCTAssertEqual(store.incorrectPaintAttemptCount, 0)
        XCTAssertEqual(store.completionRank, .perfect)
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

    func testMonthlyRewardUnlocksOnceAndEquipsPersistently() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile()
        let title = EventTitleDefinition(
            id: "event-title.month-04",
            titleKey: "event.test.active.rewardTitle",
            subtitleKey: "event.test.active.rewardSubtitle",
            eventID: "month-04"
        )

        XCTAssertTrue(store.unlockMonthlyReward(title, profile: profile))
        XCTAssertFalse(store.unlockMonthlyReward(title, profile: profile))

        store.equipEventTitle(title, profile: profile)

        XCTAssertTrue(profile.completedMonthlyRewardIDs.contains(title.id))
        XCTAssertTrue(profile.earnedBadgeIDs.contains(title.id))
        XCTAssertEqual(profile.equippedTitleID, title.id)
    }

    func testMonthlyDailyHistoryKeepsLatestUniqueThreeSelections() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile()

        store.recordMonthlyDailySelection(storageKey: "alpha#1", monthID: "month-04", profile: profile)
        store.recordMonthlyDailySelection(storageKey: "beta#1", monthID: "month-04", profile: profile)
        store.recordMonthlyDailySelection(storageKey: "gamma#1", monthID: "month-04", profile: profile)
        store.recordMonthlyDailySelection(storageKey: "delta#1", monthID: "month-04", profile: profile)
        store.recordMonthlyDailySelection(storageKey: "delta#1", monthID: "month-04", profile: profile)
        store.recordMonthlyDailySelection(storageKey: "beta#1", monthID: "month-04", profile: profile)

        XCTAssertEqual(
            store.monthlyDailyRecentHistory(monthID: "month-04", profile: profile),
            ["beta#1", "delta#1", "gamma#1"]
        )
    }

    private func makeDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }
}

final class BoardTransformTests: XCTestCase {
    private let area = CGSize(width: 300, height: 300)
    private let side: CGFloat = 1000
    private var fit: CGFloat { min(area.width, area.height) / side } // 0.3
    private var maxScale: CGFloat { fit * 4 }

    func testFitOffsetCentersContent() {
        let offset = BoardTransform.clampOffset(.zero, scale: fit, area: area, side: side)
        // At fit the scaled content equals the area, so it is centered at 0,0.
        XCTAssertEqual(offset.width, 0, accuracy: 0.001)
        XCTAssertEqual(offset.height, 0, accuracy: 0.001)
    }

    func testPinchOutZoomsInAndKeepsFocalPoint() {
        let startOffset = BoardTransform.clampOffset(.zero, scale: fit, area: area, side: side)
        let centroid = CGPoint(x: 200, y: 120)

        let result = BoardTransform.navigated(
            startScale: fit, startOffset: startOffset, startCentroid: centroid,
            factor: 2, centroid: centroid,
            minScale: fit, maxScale: maxScale, area: area, side: side
        )

        XCTAssertGreaterThan(result.scale, fit, "pinch-out must increase scale")
        XCTAssertEqual(result.scale, fit * 2, accuracy: 0.0001)

        // The content point under the fingers must stay under the fingers.
        let contentX = (centroid.x - startOffset.width) / fit
        let contentY = (centroid.y - startOffset.height) / fit
        let screenX = result.offset.width + result.scale * contentX
        let screenY = result.offset.height + result.scale * contentY
        XCTAssertEqual(screenX, centroid.x, accuracy: 0.5)
        XCTAssertEqual(screenY, centroid.y, accuracy: 0.5)
    }

    func testZoomClampedToRange() {
        let startOffset = BoardTransform.clampOffset(.zero, scale: fit, area: area, side: side)
        let c = CGPoint(x: 150, y: 150)

        let tooFarIn = BoardTransform.navigated(
            startScale: fit, startOffset: startOffset, startCentroid: c,
            factor: 100, centroid: c, minScale: fit, maxScale: maxScale, area: area, side: side
        )
        XCTAssertEqual(tooFarIn.scale, maxScale, accuracy: 0.0001)

        let tooFarOut = BoardTransform.navigated(
            startScale: fit, startOffset: startOffset, startCentroid: c,
            factor: 0.01, centroid: c, minScale: fit, maxScale: maxScale, area: area, side: side
        )
        XCTAssertEqual(tooFarOut.scale, fit, accuracy: 0.0001)
    }

    func testPanWhenZoomedMovesAndClampsOffset() {
        // Zoomed in to 2x fit, the content (600pt) is larger than the area (300pt).
        let zoom = fit * 2
        let startOffset = BoardTransform.clampOffset(.zero, scale: zoom, area: area, side: side)
        let start = CGPoint(x: 150, y: 150)
        // Slide both fingers right by 80pt (no zoom change).
        let moved = CGPoint(x: 230, y: 150)

        let result = BoardTransform.navigated(
            startScale: zoom, startOffset: startOffset, startCentroid: start,
            factor: 1, centroid: moved, minScale: fit, maxScale: maxScale, area: area, side: side
        )

        XCTAssertEqual(result.scale, zoom, accuracy: 0.0001)
        // Offset must never let the content edge cross into the area.
        let scaled = side * zoom
        XCTAssertLessThanOrEqual(result.offset.width, 0.0001)
        XCTAssertGreaterThanOrEqual(result.offset.width, area.width - scaled - 0.0001)
    }

    func testCellIndexMapsScreenPointToCell() {
        let pitch: CGFloat = 42
        // Point inside cell (row 2, col 3) at scale 1, no offset.
        let inside = CGPoint(x: 3 * pitch + 5, y: 2 * pitch + 5)
        XCTAssertEqual(
            BoardTransform.cellIndex(at: inside, scale: 1, offset: .zero, pitch: pitch, width: 10, height: 10),
            2 * 10 + 3
        )
        // Out of bounds returns nil.
        XCTAssertNil(
            BoardTransform.cellIndex(at: CGPoint(x: -5, y: 10), scale: 1, offset: .zero, pitch: pitch, width: 10, height: 10)
        )
    }

    func testCellIndexAccountsForScaleAndOffset() {
        let pitch: CGFloat = 42
        let scale: CGFloat = 2
        let offset = CGSize(width: 30, height: 10)
        // Pick content cell (row 1, col 4): content point (4*pitch+5, 1*pitch+5),
        // screen point = offset + scale * contentPoint.
        let contentX = 4 * pitch + 5
        let contentY = 1 * pitch + 5
        let screen = CGPoint(x: offset.width + scale * contentX, y: offset.height + scale * contentY)
        XCTAssertEqual(
            BoardTransform.cellIndex(at: screen, scale: scale, offset: offset, pitch: pitch, width: 10, height: 10),
            1 * 10 + 4
        )
    }
}
