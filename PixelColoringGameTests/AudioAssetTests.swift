import XCTest
@testable import PixelColoringGame

final class AudioAssetTests: XCTestCase {
    func test_bgm_resourceNames_matchSpec() {
        XCTAssertEqual(AudioAsset.bgmHome.resourceName, "b1_home")
        XCTAssertEqual(AudioAsset.bgmHome.fileExtension, "m4a")

        XCTAssertEqual(AudioAsset.bgmGameplayWarm.resourceName, "b2_gameplay_warm")
        XCTAssertEqual(AudioAsset.bgmGameplayCool.resourceName, "b3_gameplay_cool")
        XCTAssertEqual(AudioAsset.bgmCollection.resourceName, "b4_collection")
        XCTAssertEqual(AudioAsset.bgmEvent.resourceName, "b5_event")
    }

    func test_sfx_resourceNames_matchSpec() {
        XCTAssertEqual(AudioAsset.sfxLevelComplete.resourceName, "s1_level_complete")
        XCTAssertEqual(AudioAsset.sfxLevelComplete.fileExtension, "wav")
        XCTAssertEqual(AudioAsset.sfxBadgeEarned.resourceName, "s2_badge_earned")
        XCTAssertEqual(AudioAsset.sfxChapterClear.resourceName, "s3_chapter_clear")
        XCTAssertEqual(AudioAsset.sfxDailyStreak.resourceName, "s4_daily_streak")
        XCTAssertEqual(AudioAsset.sfxEventComplete.resourceName, "s5_event_complete")
    }

    func test_tap_sfx_matchesSpec() {
        XCTAssertEqual(AudioAsset.sfxTap.resourceName, "tap")
        XCTAssertEqual(AudioAsset.sfxTap.fileExtension, "wav")
        XCTAssertFalse(AudioAsset.sfxTap.isBGM)
        XCTAssertEqual(AudioAsset.sfxTap.bundleSubdirectory, "Audio/SFX")
    }

    func test_isBGM_discriminatesBGMvsSFX() {
        XCTAssertTrue(AudioAsset.bgmHome.isBGM)
        XCTAssertFalse(AudioAsset.sfxLevelComplete.isBGM)
    }

    func test_bundleSubdirectory_matchesBlueFolderLayout() {
        XCTAssertEqual(AudioAsset.bgmHome.bundleSubdirectory, "Audio/BGM")
        XCTAssertEqual(AudioAsset.sfxLevelComplete.bundleSubdirectory, "Audio/SFX")
    }
}
