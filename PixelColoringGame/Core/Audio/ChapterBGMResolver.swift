import Foundation

enum ChapterBGMResolver {
    private static let coolChapters: Set<String> = [
        "tide-garden",
        "moonlit-shore",
        "starlit-garden",
    ]

    static func bgm(for chapterID: String) -> AudioAsset {
        coolChapters.contains(chapterID) ? .bgmGameplayCool : .bgmGameplayWarm
    }
}
