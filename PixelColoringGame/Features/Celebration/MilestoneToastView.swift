import SwiftUI

struct MilestoneToastView: View {
    let event: CelebrationEvent
    let onTap: () -> Void

    @Environment(AppLocalization.self) private var localization

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(AppTheme.celebrationGold)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.string(titleKey))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(localization.string(subtitleKey))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceElevated)
                .shadow(color: AppTheme.shadowColor, radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, 18)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var icon: String {
        switch event {
        case .firstPerfect: return "sparkles"
        case .streakMilestone: return "flame.fill"
        case .levelCountMilestone: return "checkmark.seal.fill"
        default: return "star.fill"
        }
    }

    private var titleKey: String {
        switch event {
        case .firstPerfect: return "toast.firstPerfect.title"
        case .streakMilestone(let d): return "toast.streak\(d).title"
        case .levelCountMilestone(let c): return "toast.levels\(c).title"
        default: return "toast.generic.title"
        }
    }

    private var subtitleKey: String {
        switch event {
        case .firstPerfect: return "toast.firstPerfect.subtitle"
        case .streakMilestone(let d): return "toast.streak\(d).subtitle"
        case .levelCountMilestone(let c): return "toast.levels\(c).subtitle"
        default: return "toast.generic.subtitle"
        }
    }
}
