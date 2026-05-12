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
    var hintCount: Int = 0
    var incorrectPaintAttemptCount: Int = 0
    var firstCompletedAt: Date?
    var completedAt: Date?
    var lastPlayedAt: Date?
    var bestCompletionRankRaw: Int = CompletionRank.normal.rawValue
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
    var equippedTitleIDRaw: String = ""
    var claimedMissionRewardIDsRaw: String = ""
    var currentMonthlyDailySelectionRaw: String = ""
    var monthlyDailyRecentHistoryRaw: String = ""
    var completedMonthlyRewardIDsRaw: String = ""
    var celebrationsSeenData: Data = Data()

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
        equippedTitleIDRaw: String = "",
        claimedMissionRewardIDsRaw: String = "",
        currentMonthlyDailySelectionRaw: String = "",
        monthlyDailyRecentHistoryRaw: String = "",
        completedMonthlyRewardIDsRaw: String = "",
        celebrationsSeenData: Data = Data()
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
        self.equippedTitleIDRaw = equippedTitleIDRaw
        self.claimedMissionRewardIDsRaw = claimedMissionRewardIDsRaw
        self.currentMonthlyDailySelectionRaw = currentMonthlyDailySelectionRaw
        self.monthlyDailyRecentHistoryRaw = monthlyDailyRecentHistoryRaw
        self.completedMonthlyRewardIDsRaw = completedMonthlyRewardIDsRaw
        self.celebrationsSeenData = celebrationsSeenData
    }
}

enum PixelColoringGameSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LevelProgress.self]
    }

    @Model
    final class LevelProgress {
        @Attribute(.unique) var storageKey: String
        var levelID: String
        var levelVersion: Int
        var filledCellsData: Data
        var filledCellCount: Int
        var activeColorIndex: Int?
        var completedAt: Date?
        var updatedAt: Date

        init(
            storageKey: String,
            levelID: String,
            levelVersion: Int,
            filledCellsData: Data,
            filledCellCount: Int,
            activeColorIndex: Int?,
            completedAt: Date?,
            updatedAt: Date
        ) {
            self.storageKey = storageKey
            self.levelID = levelID
            self.levelVersion = levelVersion
            self.filledCellsData = filledCellsData
            self.filledCellCount = filledCellCount
            self.activeColorIndex = activeColorIndex
            self.completedAt = completedAt
            self.updatedAt = updatedAt
        }
    }
}

enum PixelColoringGameSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LevelProgress.self, PlayerProfile.self]
    }

    @Model
    final class LevelProgress {
        @Attribute(.unique) var storageKey: String
        var levelID: String
        var levelVersion: Int
        var filledCellsData: Data
        var filledCellCount: Int
        var activeColorIndex: Int?
        var hintCount: Int = 0
        var incorrectPaintAttemptCount: Int = 0
        var firstCompletedAt: Date?
        var completedAt: Date?
        var lastPlayedAt: Date?
        var bestCompletionRankRaw: Int = CompletionRank.normal.rawValue
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
}

enum PixelColoringGameSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LevelProgress.self, PlayerProfile.self]
    }

    @Model
    final class LevelProgress {
        @Attribute(.unique) var storageKey: String
        var levelID: String
        var levelVersion: Int
        var filledCellsData: Data
        var filledCellCount: Int
        var activeColorIndex: Int?
        var hintCount: Int = 0
        var incorrectPaintAttemptCount: Int = 0
        var firstCompletedAt: Date?
        var completedAt: Date?
        var lastPlayedAt: Date?
        var bestCompletionRankRaw: Int = CompletionRank.normal.rawValue
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
        var equippedTitleIDRaw: String = ""
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
            equippedTitleIDRaw: String = "",
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
            self.equippedTitleIDRaw = equippedTitleIDRaw
            self.claimedMissionRewardIDsRaw = claimedMissionRewardIDsRaw
        }
    }
}

enum PixelColoringGameSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LevelProgress.self, PlayerProfile.self]
    }
}

enum PixelColoringGameSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LevelProgress.self, PlayerProfile.self]
    }
}

enum PixelColoringGameMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            PixelColoringGameSchemaV1.self,
            PixelColoringGameSchemaV2.self,
            PixelColoringGameSchemaV3.self,
            PixelColoringGameSchemaV4.self,
            PixelColoringGameSchemaV5.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            .custom(
                fromVersion: PixelColoringGameSchemaV1.self,
                toVersion: PixelColoringGameSchemaV2.self,
                willMigrate: nil,
                didMigrate: { context in
                    let records = try context.fetch(FetchDescriptor<PixelColoringGameSchemaV2.LevelProgress>())
                    for record in records {
                        record.firstCompletedAt = record.firstCompletedAt ?? record.completedAt
                        record.lastPlayedAt = record.lastPlayedAt ?? record.updatedAt
                    }

                    if context.hasChanges {
                        try context.save()
                    }
                }
            ),
            .lightweight(fromVersion: PixelColoringGameSchemaV2.self, toVersion: PixelColoringGameSchemaV3.self),
            .lightweight(fromVersion: PixelColoringGameSchemaV3.self, toVersion: PixelColoringGameSchemaV4.self),
            .lightweight(fromVersion: PixelColoringGameSchemaV4.self, toVersion: PixelColoringGameSchemaV5.self),
        ]
    }
}

enum PixelColoringGamePersistence {
    static let storeFilename = "default.store"
    static let recoveryPendingNoticeKey = "persistence.recovery.pending.notice"

    static func makeSharedContainer(defaults: UserDefaults = .standard) throws -> ModelContainer {
        let storeURL = try persistentStoreURL()

        do {
            return try makeContainer(at: storeURL)
        } catch {
            AppLogger.persistenceStoreLoadFailed(error: error)
            try destroyStoreArtifacts(at: storeURL)
            let recoveredContainer = try makeContainer(at: storeURL)
            defaults.set(true, forKey: recoveryPendingNoticeKey)
            AppLogger.persistenceStoreRecovered(storeURL: storeURL)
            return recoveredContainer
        }
    }

    static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: PixelColoringGameSchemaV5.self)
        let configuration = ModelConfiguration(
            "Preview",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: PixelColoringGameMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }

    static func consumePendingRecoveryNotice(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.bool(forKey: recoveryPendingNoticeKey) else {
            return false
        }
        defaults.removeObject(forKey: recoveryPendingNoticeKey)
        return true
    }

    static func makeContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PixelColoringGameSchemaV5.self)
        let configuration = ModelConfiguration(
            "Default",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: PixelColoringGameMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func persistentStoreURL() throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupportDirectory.appendingPathComponent(storeFilename, isDirectory: false)
    }

    static func destroyStoreArtifacts(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let urlsToRemove = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal"),
        ]

        for url in urlsToRemove where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
