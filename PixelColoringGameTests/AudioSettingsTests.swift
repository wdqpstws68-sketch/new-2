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
