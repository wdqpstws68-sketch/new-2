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

    func test_defaultVolumes() {
        let settings = AudioSettings(defaults: defaults)
        XCTAssertEqual(settings.bgmVolume, AudioSettings.defaultBGMVolume, accuracy: 0.0001)
        XCTAssertEqual(settings.sfxVolume, AudioSettings.defaultSFXVolume, accuracy: 0.0001)
    }

    func test_volumesPersistAcrossInstances() {
        let a = AudioSettings(defaults: defaults)
        a.bgmVolume = 0.3
        a.sfxVolume = 0.6

        let b = AudioSettings(defaults: defaults)
        XCTAssertEqual(b.bgmVolume, 0.3, accuracy: 0.0001)
        XCTAssertEqual(b.sfxVolume, 0.6, accuracy: 0.0001)
    }

    func test_volumesAreClampedToUnitInterval() {
        let settings = AudioSettings(defaults: defaults)
        settings.bgmVolume = 1.8
        settings.sfxVolume = -0.4
        XCTAssertEqual(settings.bgmVolume, 1.0, accuracy: 0.0001)
        XCTAssertEqual(settings.sfxVolume, 0.0, accuracy: 0.0001)
    }

    func test_muteOverridesEffectiveVolumes() {
        let settings = AudioSettings(defaults: defaults)
        settings.bgmVolume = 0.8
        settings.sfxVolume = 0.5

        XCTAssertEqual(settings.effectiveBGMVolume, 0.8, accuracy: 0.0001)
        XCTAssertEqual(settings.effectiveSFXVolume, 0.5, accuracy: 0.0001)

        settings.isMuted = true
        XCTAssertEqual(settings.effectiveBGMVolume, 0, accuracy: 0.0001)
        XCTAssertEqual(settings.effectiveSFXVolume, 0, accuracy: 0.0001)
        // Underlying volumes are preserved so unmuting restores them.
        XCTAssertEqual(settings.bgmVolume, 0.8, accuracy: 0.0001)
        XCTAssertEqual(settings.sfxVolume, 0.5, accuracy: 0.0001)
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

@MainActor
final class RewardedAdServiceTests: XCTestCase {

    func test_debugBuildUsesGoogleTestAdUnit() {
        // Dev/test must never request production ads (invalid-traffic risk).
        #if DEBUG
        XCTAssertEqual(
            RewardedAdService.defaultRewardedAdUnitID,
            "ca-app-pub-3940256099942544/1712485313"
        )
        #endif
    }

    func test_adIsSupportedWhenSDKLinked() {
        XCTAssertTrue(RewardedAdService().isAdSupported)
    }

    func test_rewardButtonIsTappableForRetryUntilLoadingOrPresenting() {
        let service = RewardedAdService()
        // Fresh service is .unavailable but tappable so the user can retry —
        // the button must not vanish or dead-end while ads aren't ready yet.
        XCTAssertTrue(service.isRewardButtonEnabled)

        service.availability = .loading
        XCTAssertFalse(service.isRewardButtonEnabled)

        service.availability = .ready
        XCTAssertTrue(service.isRewardButtonEnabled)

        service.isPresenting = true
        XCTAssertFalse(service.isRewardButtonEnabled)
    }
}
