import Foundation
import SwiftData

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

    func ensureProfile(in context: ModelContext) throws -> PlayerProfile {
        if let existing = try context.fetch(FetchDescriptor<PlayerProfile>()).first {
            if seedInitialLivesIfNeeded(profile: existing) {
                try context.save()
            }
            return existing
        }

        let profile = PlayerProfile()
        context.insert(profile)
        _ = seedInitialLivesIfNeeded(profile: profile)
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

    var claimedMissionRewardIDs: Set<String> {
        get { StoredStringSetCodec.decode(claimedMissionRewardIDsRaw) }
        set { claimedMissionRewardIDsRaw = StoredStringSetCodec.encode(newValue) }
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
