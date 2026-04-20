import Foundation

enum AudioAsset: CaseIterable, Sendable {
    case bgmHome
    case bgmGameplayWarm
    case bgmGameplayCool
    case bgmCollection
    case bgmEvent

    case sfxLevelComplete
    case sfxBadgeEarned
    case sfxChapterClear
    case sfxDailyStreak
    case sfxEventComplete

    var resourceName: String {
        switch self {
        case .bgmHome: return "b1_home"
        case .bgmGameplayWarm: return "b2_gameplay_warm"
        case .bgmGameplayCool: return "b3_gameplay_cool"
        case .bgmCollection: return "b4_collection"
        case .bgmEvent: return "b5_event"
        case .sfxLevelComplete: return "s1_level_complete"
        case .sfxBadgeEarned: return "s2_badge_earned"
        case .sfxChapterClear: return "s3_chapter_clear"
        case .sfxDailyStreak: return "s4_daily_streak"
        case .sfxEventComplete: return "s5_event_complete"
        }
    }

    var fileExtension: String { isBGM ? "m4a" : "wav" }

    var isBGM: Bool {
        switch self {
        case .bgmHome, .bgmGameplayWarm, .bgmGameplayCool, .bgmCollection, .bgmEvent:
            return true
        case .sfxLevelComplete, .sfxBadgeEarned, .sfxChapterClear, .sfxDailyStreak, .sfxEventComplete:
            return false
        }
    }

    var bundleSubdirectory: String { isBGM ? "Audio/BGM" : "Audio/SFX" }
}
