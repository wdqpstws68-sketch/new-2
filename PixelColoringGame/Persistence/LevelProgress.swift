import Foundation
import SwiftData

@Model
final class LevelProgress {
    @Attribute(.unique) var storageKey: String
    var levelID: String
    var levelVersion: Int
    var filledCellsData: Data
    var filledCellCount: Int
    var activeColorIndex: Int?
    var hintCount: Int
    var incorrectPaintAttemptCount: Int
    var firstCompletedAt: Date?
    var completedAt: Date?
    var lastPlayedAt: Date?
    var bestCompletionRankRaw: Int
    var updatedAt: Date

    init(
        storageKey: String,
        levelID: String,
        levelVersion: Int,
        filledCellsData: Data,
        filledCellCount: Int,
        activeColorIndex: Int?,
        hintCount: Int = 0,
        incorrectPaintAttemptCount: Int = 0,
        firstCompletedAt: Date? = nil,
        completedAt: Date?,
        lastPlayedAt: Date? = nil,
        bestCompletionRankRaw: Int = CompletionRank.normal.rawValue,
        updatedAt: Date
    ) {
        self.storageKey = storageKey
        self.levelID = levelID
        self.levelVersion = levelVersion
        self.filledCellsData = filledCellsData
        self.filledCellCount = filledCellCount
        self.activeColorIndex = activeColorIndex
        self.hintCount = hintCount
        self.incorrectPaintAttemptCount = incorrectPaintAttemptCount
        self.firstCompletedAt = firstCompletedAt
        self.completedAt = completedAt
        self.lastPlayedAt = lastPlayedAt
        self.bestCompletionRankRaw = bestCompletionRankRaw
        self.updatedAt = updatedAt
    }
}

extension LevelProgress {
    var bestCompletionRank: CompletionRank {
        get { CompletionRank(rawValue: bestCompletionRankRaw) ?? .normal }
        set { bestCompletionRankRaw = newValue.rawValue }
    }
}

@Model
final class PlayerProfile {
    @Attribute(.unique) var profileKey: String = "primary"
    var lastActiveDayKey: String?
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var refillableLives: Int = 0
    var bonusLives: Int = 0
    var lifeRefillAnchorAt: Date?
    var didSeedInitialLives: Bool = false
    var lastDailyPopupPresentedDayKey: String?
    var completedDailyDayKeysRaw: String = ""
    var earnedBadgeIDsRaw: String = ""
    var claimedMissionRewardIDsRaw: String = ""

    init(
        profileKey: String = "primary",
        lastActiveDayKey: String? = nil,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        refillableLives: Int = 0,
        bonusLives: Int = 0,
        lifeRefillAnchorAt: Date? = nil,
        didSeedInitialLives: Bool = false,
        lastDailyPopupPresentedDayKey: String? = nil,
        completedDailyDayKeysRaw: String = "",
        earnedBadgeIDsRaw: String = "",
        claimedMissionRewardIDsRaw: String = ""
    ) {
        self.profileKey = profileKey
        self.lastActiveDayKey = lastActiveDayKey
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.refillableLives = refillableLives
        self.bonusLives = bonusLives
        self.lifeRefillAnchorAt = lifeRefillAnchorAt
        self.didSeedInitialLives = didSeedInitialLives
        self.lastDailyPopupPresentedDayKey = lastDailyPopupPresentedDayKey
        self.completedDailyDayKeysRaw = completedDailyDayKeysRaw
        self.earnedBadgeIDsRaw = earnedBadgeIDsRaw
        self.claimedMissionRewardIDsRaw = claimedMissionRewardIDsRaw
    }
}
