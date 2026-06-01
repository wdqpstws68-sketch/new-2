import XCTest
@testable import PixelColoringGame

@MainActor
final class AudioSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "AudioSettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_defaultIsUnmuted() {
        let settings = AudioSettings(defaults: defaults)
        XCTAssertFalse(settings.isMuted)
    }

    func test_settingMuted_persistsAcrossInstances() {
        let a = AudioSettings(defaults: defaults)
        a.isMuted = true

        let b = AudioSettings(defaults: defaults)
        XCTAssertTrue(b.isMuted)
    }

    func test_toggleFlipsValue() {
        let settings = AudioSettings(defaults: defaults)
        settings.toggleMuted()
        XCTAssertTrue(settings.isMuted)
        settings.toggleMuted()
        XCTAssertFalse(settings.isMuted)
    }
}

@MainActor
final class RewardedAdQuotaTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "RewardedAdQuotaTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_freshQuota_allowsUpToDailyLimit() {
        let quota = RewardedAdQuota(defaults: defaults)
        XCTAssertEqual(quota.remaining(on: "2026-06-01"), RewardedAdQuota.dailyLimit)
        XCTAssertTrue(quota.canWatch(on: "2026-06-01"))
    }

    func test_recordWatch_decrementsRemaining() {
        let quota = RewardedAdQuota(defaults: defaults)
        quota.recordWatch(on: "2026-06-01")
        XCTAssertEqual(quota.remaining(on: "2026-06-01"), RewardedAdQuota.dailyLimit - 1)
    }

    func test_reachingDailyLimit_blocksFurtherWatches() {
        let quota = RewardedAdQuota(defaults: defaults)
        for _ in 0..<RewardedAdQuota.dailyLimit {
            quota.recordWatch(on: "2026-06-01")
        }
        XCTAssertEqual(quota.remaining(on: "2026-06-01"), 0)
        XCTAssertFalse(quota.canWatch(on: "2026-06-01"))
    }

    func test_newDay_resetsQuota() {
        let quota = RewardedAdQuota(defaults: defaults)
        for _ in 0..<RewardedAdQuota.dailyLimit {
            quota.recordWatch(on: "2026-06-01")
        }
        XCTAssertFalse(quota.canWatch(on: "2026-06-01"))
        XCTAssertTrue(quota.canWatch(on: "2026-06-02"))
        XCTAssertEqual(quota.remaining(on: "2026-06-02"), RewardedAdQuota.dailyLimit)
    }

    func test_countPersistsAcrossInstances_sameDay() {
        let a = RewardedAdQuota(defaults: defaults)
        a.recordWatch(on: "2026-06-01")
        a.recordWatch(on: "2026-06-01")

        let b = RewardedAdQuota(defaults: defaults)
        XCTAssertEqual(b.remaining(on: "2026-06-01"), RewardedAdQuota.dailyLimit - 2)
    }
}
