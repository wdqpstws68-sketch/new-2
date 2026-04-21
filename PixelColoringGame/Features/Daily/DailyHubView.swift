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
