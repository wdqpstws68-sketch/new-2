import SwiftUI

struct DailyHubView: View {
    @Environment(AppLocalization.self) private var localization

    let manifest: JourneyManifest
    let snapshot: JourneyProgressSnapshot
    let homeSnapshot: HomeProgressSnapshot
    let repository: LevelRepository
    let onOpenDailyChallenge: (LevelEntrySource) -> Void
    let onOpenMonthDetail: (String) -> Void
    let onOpenCollectionBook: (String?) -> Void
    let dailyWishAvailable: Bool
    let onClaimDailyWish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabTopStrip(
                balance: homeSnapshot.lifeBalance,
                collectionTitle: manifest.localizedCollectionTitle(using: localization),
                defaultCollectionChapterID: defaultCollectionChapterID,
                onOpenCollectionBook: onOpenCollectionBook
            )

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    header

                    if let dailyChallenge = homeSnapshot.dailyChallenge {
                        DailyChallengeHeroCard(
                            challenge: dailyChallenge,
                            streak: homeSnapshot.streak,
                            repository: repository,
                            action: { onOpenDailyChallenge(.dailyHero) },
                            monthAction: { onOpenMonthDetail(dailyChallenge.monthID) }
                        )
                    } else {
                        emptyChallengeCard
                    }

                    if dailyWishAvailable {
                        dailyWishCard
                    }

                    if !homeSnapshot.badges.isEmpty || homeSnapshot.streak.current > 0 {
                        StreakAndBadgeCard(
                            streak: homeSnapshot.streak,
                            badges: homeSnapshot.badges
                        )
                    }

                    if let activeEvent = homeSnapshot.activeEvent,
                       let activeCollection = homeSnapshot.eventCollection(eventID: activeEvent.id) {
                        eventDigestCard(eventState: activeCollection)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xl)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var defaultCollectionChapterID: String? {
        snapshot.currentChapterID ?? snapshot.chapters.last?.id
    }

    /// Days remaining in the current calendar month — the active event's "reward window".
    private var daysLeftInMonth: Int? {
        let cal = Calendar.current
        let now = Date()
        guard let range = cal.range(of: .day, in: .month, for: now),
              let day = cal.dateComponents([.day], from: now).day else { return nil }
        return max(range.count - day, 0)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(localization.string("daily.hub.eyebrow"))
                .font(AppTypography.caption())
                .foregroundStyle(AppTheme.accentOrange)
            Text(localization.string("daily.hub.title"))
                .font(AppTypography.title())
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private var emptyChallengeCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(localization.string("daily.hub.empty.title"))
                .font(AppTypography.headline())
                .foregroundStyle(AppTheme.textPrimary)
            Text(localization.string("daily.hub.empty.subtitle"))
                .font(AppTypography.body())
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppTheme.surfaceElevated)
                .shadow(AppShadow.card)
        )
    }

    private var dailyWishCard: some View {
        Button(action: onClaimDailyWish) {
            HStack(spacing: AppSpacing.m) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(AppTheme.accentBerry)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppTheme.accentBerry.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.string("daily.hub.wish.title"))
                        .font(AppTypography.headline())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(localization.string("daily.hub.wish.subtitle"))
                        .font(AppTypography.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Text(localization.string("daily.hub.wish.claim"))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppTheme.accentBerry))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .fill(AppTheme.surfaceElevated)
                    .shadow(AppShadow.card)
            )
        }
        .buttonStyle(.tapSound)
    }

    private func eventDigestCard(eventState: EventCollectionState) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            Image("EventTitleMedallion")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 6) {
                Text(localization.string("daily.hub.event.eyebrow"))
                    .font(AppTypography.caption())
                    .foregroundStyle(eventState.event.accentColor)
                Text(eventState.localizedHeaderTitle(using: localization))
                    .font(AppTypography.headline())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(eventState.localizedHeaderSubtitle(using: localization))
                    .font(AppTypography.body())
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(localization.string(
                            "daily.hub.event.progress",
                            eventState.completedEntryCount,
                            eventState.totalEntryCount
                        ))
                        Spacer(minLength: 0)
                        if !eventState.isTitleUnlocked, let daysLeft = daysLeftInMonth {
                            Text(localization.string("daily.hub.event.daysLeft", daysLeft))
                        }
                    }
                    .font(AppTypography.caption())
                    .foregroundStyle(AppTheme.textSecondary)

                    ProgressView(
                        value: Double(eventState.completedEntryCount),
                        total: Double(max(eventState.totalEntryCount, 1))
                    )
                    .tint(eventState.event.accentColor)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.l)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppTheme.surfaceElevated)
                .shadow(AppShadow.card)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenMonthDetail(eventState.event.id)
        }
    }
}
