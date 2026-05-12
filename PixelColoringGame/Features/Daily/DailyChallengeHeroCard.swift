import SwiftUI

struct DailyChallengeHeroCard: View {
    @Environment(AppLocalization.self) private var localization

    let challenge: DailyChallengeState
    let streak: HomeStreakState
    let repository: LevelRepository
    let action: () -> Void
    let monthAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Button(action: action) {
                HStack(spacing: 18) {
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let image = repository.thumbnailImage(for: challenge.level) {
                                Image(uiImage: image)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                            } else {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.white.opacity(0.55))
                            }
                        }
                        .frame(width: 112, height: 112)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.88))
                        )

                        if challenge.bestRank == .perfect {
                            Label(localization.string("common.rank.perfect"), systemImage: "sparkles")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(challenge.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.white)
                                )
                                .offset(x: 8, y: -8)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(challenge.localizedTitle(using: localization))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(challenge.accentColor)

                        Text(challenge.level.localizedTitle(using: localization))
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(challenge.localizedSubtitle(using: localization))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HomeBadgeLabel(
                            title: monthProgressLabel,
                            accentColor: challenge.accentColor
                        )
                        HomeBadgeLabel(
                            title: localization.string("daily.hero.streak", streak.current),
                            accentColor: AppTheme.accentGreen
                        )

                        HStack(spacing: 10) {
                            HomeBadgeLabel(
                                title: localization.string(
                                    challenge.isCompletedToday
                                        ? "daily.hero.clearedToday"
                                        : "daily.hero.freshToday"
                                ),
                                accentColor: challenge.accentColor
                            )
                            HomeBadgeLabel(
                                title: localization.string("daily.hero.freeEntry"),
                                accentColor: AppTheme.accentOrange
                            )
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Button(action: action) {
                    Text(
                        localization.string(
                            challenge.isReplayPick
                                ? "daily.hero.action.replayPick"
                                : "daily.hero.action.playToday"
                        )
                    )
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(challenge.accentColor)
                        )
                }
                .buttonStyle(.plain)

                Button(action: monthAction) {
                    Text(localization.string("daily.hero.action.viewMonth"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.94))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(challenge.accentColor.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .offset(x: 28, y: -30)
                    }
                    .shadow(color: challenge.accentColor.opacity(0.18), radius: 26, x: 0, y: 16)
            )
        }
    }

    private var monthProgressLabel: String {
        if challenge.isMonthCompleted {
            return localization.string("daily.hero.progress.monthComplete")
        }
        return localization.string(
            "collection.events.progress",
            challenge.completedMonthCount,
            max(challenge.totalMonthCount, 1)
        )
    }
}
