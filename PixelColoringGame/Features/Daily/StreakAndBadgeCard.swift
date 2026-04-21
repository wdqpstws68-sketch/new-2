import SwiftUI

struct StreakAndBadgeCard: View {
    @Environment(AppLocalization.self) private var localization

    let streak: HomeStreakState
    let badges: [BadgeDefinition]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localization.string("streak.card.eyebrow"))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.accentGreen)

            HStack(spacing: 12) {
                StreakStat(
                    title: localization.string("streak.current"),
                    value: "\(streak.current)"
                )
                StreakStat(
                    title: localization.string("streak.best"),
                    value: "\(streak.best)"
                )
                StreakStat(
                    title: localization.string("streak.today"),
                    value: localization.string(
                        streak.countedToday
                            ? "streak.today.done"
                            : "streak.today.open"
                    )
                )
            }

            if !badges.isEmpty {
                ForEach(badges) { badge in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localization.string(badge.titleKey))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(localization.string(badge.subtitleKey))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.88))
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(hex: "ECFBEA"))
                .shadow(color: AppTheme.shadowColor, radius: 16, x: 0, y: 10)
        )
    }
}

private struct StreakStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
    }
}
