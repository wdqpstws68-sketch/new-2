import XCTest
@testable import PixelColoringGame

final class AnimationProfileTests: XCTestCase {
    func test_default_shouldShowParticles_true() {
        let profile = AnimationProfile(reduceMotion: false, lowPower: false)
        XCTAssertTrue(profile.shouldShowParticles)
    }

    func test_reduceMotion_shouldShowParticles_false() {
        let profile = AnimationProfile(reduceMotion: true, lowPower: false)
        XCTAssertFalse(profile.shouldShowParticles)
    }

    func test_reduceMotion_particleBudget_zero() {
        let profile = AnimationProfile(reduceMotion: true, lowPower: false)
        XCTAssertEqual(profile.particleBudget, 0)
    }

    func test_normal_particleBudget_80() {
        let profile = AnimationProfile(reduceMotion: false, lowPower: false)
        XCTAssertEqual(profile.particleBudget, 80)
    }

    func test_lowPower_reducesParticleBudget() {
        let normal = AnimationProfile(reduceMotion: false, lowPower: false)
        let low = AnimationProfile(reduceMotion: false, lowPower: true)
        XCTAssertLessThan(low.particleBudget, normal.particleBudget)
        XCTAssertGreaterThan(low.particleBudget, 0)
    }

    func test_cascadeDelay_normalMode_scalesByIndex() {
        let profile = AnimationProfile(reduceMotion: false, lowPower: false)
        XCTAssertEqual(profile.cascadeDelay(0), 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.cascadeDelay(1), 0.15, accuracy: 0.001)
        XCTAssertEqual(profile.cascadeDelay(2), 0.30, accuracy: 0.001)
        XCTAssertEqual(profile.cascadeDelay(5), 0.75, accuracy: 0.001)
    }

    func test_cascadeDelay_reduceMotion_alwaysZero() {
        let profile = AnimationProfile(reduceMotion: true, lowPower: false)
        XCTAssertEqual(profile.cascadeDelay(0), 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.cascadeDelay(5), 0.0, accuracy: 0.001)
    }
}
