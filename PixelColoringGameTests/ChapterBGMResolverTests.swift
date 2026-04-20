import XCTest
@testable import PixelColoringGame

final class ChapterBGMResolverTests: XCTestCase {
    func test_warmChapters_resolveToWarmBGM() {
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "berry-meadow"), .bgmGameplayWarm)
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "bakery-path"), .bgmGameplayWarm)
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "petal-pond"), .bgmGameplayWarm)
    }

    func test_coolChapters_resolveToCoolBGM() {
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "tide-garden"), .bgmGameplayCool)
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "moonlit-shore"), .bgmGameplayCool)
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "starlit-garden"), .bgmGameplayCool)
    }

    func test_unknownChapter_fallsBackToWarm() {
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "unknown-chapter"), .bgmGameplayWarm)
    }
}
