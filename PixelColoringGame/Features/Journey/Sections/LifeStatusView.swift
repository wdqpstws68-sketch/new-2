import SwiftUI

struct LifeStatusView: View {
    @Environment(AppLocalization.self) private var localization

    let balance: LifeBalance

    var body: some View {
        HStack(spacing: 14) {
            Label(
                localization.string("life.status.current", balance.totalLives),
                systemImage: "heart.fill"
            )
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.accentOrange)

            if balance.bonusDisplayCount > 0 {
                Text(localization.string("life.status.bonus", balance.bonusDisplayCount))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.accentGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(AppTheme.accentGreen.opacity(0.14))
                    )
            } else if let nextRefillDate = balance.nextRefillDate {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(
                        localization.string(
                            "life.status.timer",
                            countdownLabel(until: nextRefillDate, now: context.date)
                        )
                    )
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.84))
        )
    }

    private func countdownLabel(until nextRefillDate: Date, now: Date) -> String {
        let remaining = max(Int(nextRefillDate.timeIntervalSince(now)), 0)
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
