import Foundation
import SwiftData

struct MonthlyDailySelectionRecord: Hashable {
    let profileKey: String
    let dayKey: String
    let monthID: String
    let storageKey: String
    let timeZoneID: String

    init(
        profileKey: String,
        dayKey: String,
        monthID: String,
        storageKey: String,
        timeZoneID: String
    ) {
        self.profileKey = profileKey
        self.dayKey = dayKey
        self.monthID = monthID
        self.storageKey = storageKey
        self.timeZoneID = timeZoneID
    }

    init?(_ rawValue: String) {
        let components = rawValue.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard components.count == 5 else { return nil }
        self.init(
            profileKey: components[0],
            dayKey: components[1],
            monthID: components[2],
            storageKey: components[3],
            timeZoneID: components[4]
        )
    }

    var rawValue: String {
        [profileKey, dayKey, monthID, storageKey, timeZoneID].joined(separator: "|")
    }
}

enum MonthlyDailyHistoryCodec {
    static func decode(_ rawValue: String) -> [String: [String]] {
        Dictionary(
            uniqueKeysWithValues: rawValue
                .split(separator: "\n")
                .compactMap { line -> (String, [String])? in
                    let components = line.split(separator: "|").map(String.init)
                    guard let monthID = components.first else { return nil }
                    return (monthID, Array(components.dropFirst()))
                }
        )
    }

    static func encode(_ values: [String: [String]]) -> String {
        values.keys.sorted().map { monthID in
            ([monthID] + values[monthID, default: []]).joined(separator: "|")
        }
        .joined(separator: "\n")
    }
}

struct BadgeDefinition: Hashable, Identifiable {
    let id: String
    let titleKey: String
    let subtitleKey: String

    static let streak7 = BadgeDefinition(
        id: "streak-7",
        titleKey: "badge.streak7.title",
        subtitleKey: "badge.streak7.subtitle"
    )
}

struct LifeBalance: Hashable {
    let refillableLives: Int
    let bonusLives: Int
    let maxRefillableLives: Int
    let refillInterval: TimeInterval
    let nextRefillDate: Date?

    var totalLives: Int {
        refillableLives + bonusLives
    }

    var isDepleted: Bool {
        totalLives == 0
    }

    var bonusDisplayCount: Int {
        bonusLives
    }

    var isNaturalRefillPaused: Bool {
        bonusLives > 0
    }
}

enum LifeConsumeResult: Hashable {
    case notRequired(LifeBalance)
    case consumed(LifeBalance)
    case unavailable(LifeBalance)

    var balance: LifeBalance {
        switch self {
        case let .notRequired(balance), let .consumed(balance), let .unavailable(balance):
            return balance
        }
    }
}

@MainActor
struct PlayerProfileStore {
    static let maxRefillableLives = 3
    static let initialBonusLives = 3
    static let refillInterval: TimeInterval = 8 * 60 * 60
    private static let legacySelectedDayKeyKey = "daily.challenge.selected.dayKey"
    private static let legacySelectedStorageKeyKey = "daily.challenge.selected.storageKey"

    func ensureProfile(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent
    ) throws -> PlayerProfile {
        if let existing = try context.fetch(FetchDescriptor<PlayerProfile>()).first {
            if seedInitialLivesIfNeeded(profile: existing) {
                try context.save()
            }
            if migrateLegacyDailySelectionIfNeeded(profile: existing, defaults: defaults, calendar: calendar) {
                try context.save()
            }
            return existing
        }

        let profile = PlayerProfile()
        context.insert(profile)
        _ = seedInitialLivesIfNeeded(profile: profile)
        _ = migrateLegacyDailySelectionIfNeeded(profile: profile, defaults: defaults, calendar: calendar)
        try context.save()
        return profile
    }

    @discardableResult
    func seedInitialLivesIfNeeded(profile: PlayerProfile) -> Bool {
        guard !profile.didSeedInitialLives else {
            return false
        }

        profile.refillableLives = Self.maxRefillableLives
        profile.bonusLives = Self.initialBonusLives
        profile.lifeRefillAnchorAt = nil
        profile.didSeedInitialLives = true
        return true
    }

    @discardableResult
    func resolveLives(
        at date: Date,
        profile: PlayerProfile,
        calendar: Calendar = .current
    ) -> LifeBalance {
        _ = calendar
        profile.refillableLives = max(0, min(profile.refillableLives, Self.maxRefillableLives))
        profile.bonusLives = max(profile.bonusLives, 0)

        if profile.bonusLives > 0 {
            if profile.refillableLives >= Self.maxRefillableLives {
                profile.lifeRefillAnchorAt = nil
            }
            return makeLifeBalance(from: profile, nextRefillDate: nil)
        }

        guard profile.refillableLives < Self.maxRefillableLives else {
            profile.lifeRefillAnchorAt = nil
            return makeLifeBalance(from: profile, nextRefillDate: nil)
        }

        let anchor = profile.lifeRefillAnchorAt ?? date
        if profile.lifeRefillAnchorAt == nil {
            profile.lifeRefillAnchorAt = anchor
        }

        let elapsed = max(date.timeIntervalSince(anchor), 0)
        let recoveredLives = Int(elapsed / Self.refillInterval)

        if recoveredLives > 0 {
            profile.refillableLives = min(
                Self.maxRefillableLives,
                profile.refillableLives + recoveredLives
            )

            if profile.refillableLives >= Self.maxRefillableLives {
                profile.lifeRefillAnchorAt = nil
                return makeLifeBalance(from: profile, nextRefillDate: nil)
            }

            profile.lifeRefillAnchorAt = anchor.addingTimeInterval(
                TimeInterval(recoveredLives) * Self.refillInterval
            )
        }

        let nextRefillDate = profile.lifeRefillAnchorAt?.addingTimeInterval(Self.refillInterval)
        return makeLifeBalance(from: profile, nextRefillDate: nextRefillDate)
    }

    func consumeLifeIfNeeded(
        for policy: LevelEntryPolicy,
        at date: Date,
        profile: PlayerProfile,
        calendar: Calendar = .current
    ) -> LifeConsumeResult {
        let currentBalance = resolveLives(at: date, profile: profile, calendar: calendar)

        guard policy.consumesLife else {
            return .notRequired(currentBalance)
        }

        guard currentBalance.totalLives > 0 else {
            return .unavailable(currentBalance)
        }

        if profile.bonusLives > 0 {
            profile.bonusLives -= 1
        } else if profile.refillableLives > 0 {
            profile.refillableLives -= 1
            if profile.refillableLives < Self.maxRefillableLives, profile.lifeRefillAnchorAt == nil {
                profile.lifeRefillAnchorAt = date
            }
        }

        return .consumed(resolveLives(at: date, profile: profile, calendar: calendar))
    }

    @discardableResult
    func grantRewardedLife(
        at date: Date,
        profile: PlayerProfile,
        calendar: Calendar = .current
    ) -> LifeBalance {
        _ = resolveLives(at: date, profile: profile, calendar: calendar)
        profile.refillableLives = min(profile.refillableLives + 1, Self.maxRefillableLives)
        if profile.refillableLives >= Self.maxRefillableLives {
            profile.lifeRefillAnchorAt = nil
        }
        return resolveLives(at: date, profile: profile, calendar: calendar)
    }

    func shouldPresentDailyPopup(dayKey: String, profile: PlayerProfile) -> Bool {
        profile.lastDailyPopupPresentedDayKey != dayKey
    }

    func markDailyPopupPresented(dayKey: String, profile: PlayerProfile) {
        profile.lastDailyPopupPresentedDayKey = dayKey
    }

    func migrateLegacyDailySelectionIfNeeded(
        profile: PlayerProfile,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        guard profile.currentMonthlyDailySelection == nil else {
            defaults.removeObject(forKey: Self.legacySelectedDayKeyKey)
            defaults.removeObject(forKey: Self.legacySelectedStorageKeyKey)
            return false
        }

        guard let dayKey = defaults.string(forKey: Self.legacySelectedDayKeyKey),
              let storageKey = defaults.string(forKey: Self.legacySelectedStorageKeyKey),
              let date = DayKey.date(from: dayKey, calendar: calendar) else {
            return false
        }

        profile.currentMonthlyDailySelection = MonthlyDailySelectionRecord(
            profileKey: profile.profileKey,
            dayKey: dayKey,
            monthID: MonthKey.id(for: date, calendar: calendar),
            storageKey: storageKey,
            timeZoneID: calendar.timeZone.identifier
        )
        defaults.removeObject(forKey: Self.legacySelectedDayKeyKey)
        defaults.removeObject(forKey: Self.legacySelectedStorageKeyKey)
        return true
    }

    func registerCompletion(
        on date: Date,
        profile: PlayerProfile,
        calendar: Calendar = .current
    ) -> StreakProgressSummary {
        let todayKey = DayKey.string(from: date, calendar: calendar)

        if profile.lastActiveDayKey == todayKey {
            return StreakProgressSummary(
                current: profile.currentStreak,
                best: profile.bestStreak,
                countedToday: false,
                awardedBadgeID: nil
            )
        }

        let yesterdayKey = DayKey.string(
            from: calendar.date(byAdding: .day, value: -1, to: date) ?? date,
            calendar: calendar
        )

        if profile.lastActiveDayKey == yesterdayKey {
            profile.currentStreak += 1
        } else {
            profile.currentStreak = 1
        }

        profile.lastActiveDayKey = todayKey
        profile.bestStreak = max(profile.bestStreak, profile.currentStreak)

        var awardedBadgeID: String?
        if profile.currentStreak >= 7, !profile.earnedBadgeIDs.contains(BadgeDefinition.streak7.id) {
            profile.earnedBadgeIDs.insert(BadgeDefinition.streak7.id)
            awardedBadgeID = BadgeDefinition.streak7.id
        }

        return StreakProgressSummary(
            current: profile.currentStreak,
            best: profile.bestStreak,
            countedToday: true,
            awardedBadgeID: awardedBadgeID
        )
    }

    @discardableResult
    func markDailyCompleted(dayKey: String, profile: PlayerProfile) -> Bool {
        let inserted = profile.completedDailyDayKeys.insert(dayKey).inserted
        return inserted
    }

    func persistMonthlyDailySelection(
        _ selection: MonthlyDailySelectionRecord?,
        profile: PlayerProfile
    ) {
        profile.currentMonthlyDailySelection = selection
    }

    func monthlyDailyRecentHistory(
        monthID: String,
        profile: PlayerProfile
    ) -> [String] {
        profile.monthlyDailyRecentHistory[monthID, default: []]
    }

    func recordMonthlyDailySelection(
        storageKey: String,
        monthID: String,
        profile: PlayerProfile,
        maxCount: Int = 3
    ) {
        var history = profile.monthlyDailyRecentHistory
        var monthHistory = history[monthID, default: []].filter { $0 != storageKey }
        monthHistory.insert(storageKey, at: 0)
        history[monthID] = Array(monthHistory.prefix(maxCount))
        profile.monthlyDailyRecentHistory = history
    }

    @discardableResult
    func unlockMonthlyReward(_ title: EventTitleDefinition, profile: PlayerProfile) -> Bool {
        let claimed = profile.completedMonthlyRewardIDs.insert(title.id).inserted
        profile.earnedBadgeIDs.insert(title.id)
        return claimed
    }

    @discardableResult
    func unlockEventTitle(_ title: EventTitleDefinition, profile: PlayerProfile) -> Bool {
        profile.earnedBadgeIDs.insert(title.id).inserted
    }

    func equipEventTitle(_ title: EventTitleDefinition, profile: PlayerProfile) {
        guard profile.earnedBadgeIDs.contains(title.id) else { return }
        profile.equippedTitleID = title.id
    }

    private func makeLifeBalance(from profile: PlayerProfile, nextRefillDate: Date?) -> LifeBalance {
        LifeBalance(
            refillableLives: profile.refillableLives,
            bonusLives: profile.bonusLives,
            maxRefillableLives: Self.maxRefillableLives,
            refillInterval: Self.refillInterval,
            nextRefillDate: nextRefillDate
        )
    }
}

extension PlayerProfile {
    var completedDailyDayKeys: Set<String> {
        get { StoredStringSetCodec.decode(completedDailyDayKeysRaw) }
        set { completedDailyDayKeysRaw = StoredStringSetCodec.encode(newValue) }
    }

    var earnedBadgeIDs: Set<String> {
        get { StoredStringSetCodec.decode(earnedBadgeIDsRaw) }
        set { earnedBadgeIDsRaw = StoredStringSetCodec.encode(newValue) }
    }

    var equippedTitleID: String? {
        get { equippedTitleIDRaw.isEmpty ? nil : equippedTitleIDRaw }
        set { equippedTitleIDRaw = newValue ?? "" }
    }

    var claimedMissionRewardIDs: Set<String> {
        get { StoredStringSetCodec.decode(claimedMissionRewardIDsRaw) }
        set { claimedMissionRewardIDsRaw = StoredStringSetCodec.encode(newValue) }
    }

    var currentMonthlyDailySelection: MonthlyDailySelectionRecord? {
        get {
            guard !currentMonthlyDailySelectionRaw.isEmpty else { return nil }
            return MonthlyDailySelectionRecord(currentMonthlyDailySelectionRaw)
        }
        set { currentMonthlyDailySelectionRaw = newValue?.rawValue ?? "" }
    }

    var monthlyDailyRecentHistory: [String: [String]] {
        get { MonthlyDailyHistoryCodec.decode(monthlyDailyRecentHistoryRaw) }
        set { monthlyDailyRecentHistoryRaw = MonthlyDailyHistoryCodec.encode(newValue) }
    }

    var completedMonthlyRewardIDs: Set<String> {
        get { StoredStringSetCodec.decode(completedMonthlyRewardIDsRaw) }
        set { completedMonthlyRewardIDsRaw = StoredStringSetCodec.encode(newValue) }
    }

    var celebrationsSeen: Set<String> {
        get {
            guard !celebrationsSeenData.isEmpty,
                  let decoded = try? JSONDecoder().decode(Set<String>.self, from: celebrationsSeenData) else {
                return []
            }
            return decoded
        }
        set {
            celebrationsSeenData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}

enum StoredStringSetCodec {
    static func decode(_ rawValue: String) -> Set<String> {
        Set(
            rawValue
                .split(separator: "\n")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    static func encode(_ values: Set<String>) -> String {
        values.sorted().joined(separator: "\n")
    }
}

/// 報酬型広告でライフ回復できる「1日あたりの回数上限」を管理する。
/// 日付の境界判定は呼び出し側（AppView）が `appCalendar` で算出した日キー文字列で行うため、
/// この型自体は時計・カレンダーに依存せずテスト可能。永続化は `AudioSettings` と同じ UserDefaults 流儀。
@MainActor
@Observable
final class RewardedAdQuota {
    static let dailyLimit = 5

    private static let countDefaultsKey = "rewardedAdQuota.count"
    private static let dayDefaultsKey = "rewardedAdQuota.dayKey"

    private let defaults: UserDefaults
    private(set) var watchedCount: Int
    private(set) var recordedDayKey: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.watchedCount = defaults.integer(forKey: Self.countDefaultsKey)
        self.recordedDayKey = defaults.string(forKey: Self.dayDefaultsKey) ?? ""
    }

    func remaining(on dayKey: String) -> Int {
        guard dayKey == recordedDayKey else { return Self.dailyLimit }
        return max(0, Self.dailyLimit - watchedCount)
    }

    func canWatch(on dayKey: String) -> Bool {
        remaining(on: dayKey) > 0
    }

    @discardableResult
    func recordWatch(on dayKey: String) -> Int {
        if dayKey != recordedDayKey {
            recordedDayKey = dayKey
            watchedCount = 0
            defaults.set(dayKey, forKey: Self.dayDefaultsKey)
        }
        watchedCount += 1
        defaults.set(watchedCount, forKey: Self.countDefaultsKey)
        return remaining(on: dayKey)
    }
}

/// Tracks the once-per-day free "painting wish" gift in UserDefaults (no SwiftData schema
/// change). The reward itself is granted via PlayerProfileStore.grantRewardedLife.
@MainActor
@Observable
final class DailyWishStore {
    private static let dayDefaultsKey = "dailyWish.claimedDayKey"

    private let defaults: UserDefaults
    private(set) var claimedDayKey: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.claimedDayKey = defaults.string(forKey: Self.dayDefaultsKey) ?? ""
    }

    func canClaim(on dayKey: String) -> Bool {
        dayKey != claimedDayKey
    }

    func recordClaim(on dayKey: String) {
        claimedDayKey = dayKey
        defaults.set(dayKey, forKey: Self.dayDefaultsKey)
    }
}
