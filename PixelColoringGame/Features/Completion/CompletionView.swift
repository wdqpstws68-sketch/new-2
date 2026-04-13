import SwiftUI

struct CompletionView: View {
    @Environment(AppLocalization.self) private var localization

    let summary: LevelCompletionSummary
    let repository: LevelRepository
    let journeyRepository: JourneyRepository
    let onPrimaryAction: () -> Void
    let onReturnHome: () -> Void

    private var destinationChapter: JourneyCatalogChapter? {
        switch summary.destination {
        case let .chapterUnlocked(chapterID):
            return journeyRepository.chapter(id: chapterID)
        case let .openCollectionBook(chapterID):
            guard let chapterID else { return nil }
            return journeyRepository.chapter(id: chapterID)
        case .nextLevel, .returnHome:
            return nil
        }
    }

    private var chapterTitle: String? {
        switch summary.sourceContext {
        case let .journey(_, chapterTitleKey):
            return localization.string(chapterTitleKey)
        case .daily:
            return nil
        }
    }

    private var accentColor: Color {
        if case .daily = summary.sourceContext {
            return summary.completionRank == .perfect ? AppTheme.accentGreen : AppTheme.accentOrange
        }
        switch summary.destination {
        case .chapterUnlocked:
            return destinationChapter?.chapter.accentColor ?? AppTheme.accentOrange
        case .openCollectionBook:
            return AppTheme.accentGreen
        case .nextLevel:
            return AppTheme.accentOrange
        case .returnHome:
            return AppTheme.textPrimary
        }
    }

    private var headline: String {
        if case .daily = summary.sourceContext {
            return localization.string(
                summary.completionRank == .perfect
                    ? "completion.daily.headline.perfect"
                    : "completion.daily.headline.cleared"
            )
        }
        switch summary.destination {
        case .chapterUnlocked:
            return localization.string("completion.headline.chapterUnlocked")
        case .openCollectionBook:
            return localization.string("completion.headline.bookGlowing")
        case .nextLevel:
            return localization.string("completion.headline.nextLevel")
        case .returnHome:
            return localization.string("completion.headline.returnHome")
        }
    }

    private var detailText: String {
        if case let .daily(_, titleKey, eventTitleKey) = summary.sourceContext {
            let title = localization.string(titleKey)
            if let eventTitleKey {
                return localization.string(
                    "completion.daily.detail.event",
                    title,
                    localization.string(eventTitleKey)
                )
            }
            return localization.string("completion.daily.detail.default", title)
        }
        switch summary.destination {
        case .chapterUnlocked:
            return localization.string(
                "completion.detail.chapterUnlocked",
                destinationChapter?.chapter.localizedTitle(using: localization)
                    ?? localization.string("completion.detail.chapterPlaceholder")
            )
        case .openCollectionBook:
            return localization.string("completion.detail.bookGlowing")
        case .nextLevel:
            return localization.string(
                "completion.detail.nextLevel",
                chapterTitle ?? summary.level.localizedCategory(using: localization)
            )
        case .returnHome:
            return localization.string("completion.detail.returnHome")
        }
    }

    private var primaryActionTitle: String {
        if case .daily = summary.sourceContext {
            return localization.string("completion.daily.action.home")
        }
        switch summary.destination {
        case .chapterUnlocked:
            return localization.string("completion.action.seeNewChapter")
        case .openCollectionBook:
            return localization.string("completion.action.openCollectionBook")
        case .nextLevel:
            return localization.string("completion.action.playNextArtwork")
        case .returnHome:
            return localization.string("completion.action.backToTrail")
        }
    }

    private var ribbonTitle: String? {
        if case let .daily(_, titleKey, _) = summary.sourceContext {
            return localization.string(titleKey)
        }
        guard case .chapterUnlocked = summary.destination else { return nil }
        return destinationChapter?.chapter.localizedBadgeTitle(using: localization)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                CompletionBadge(
                    title: ribbonTitle ?? chapterTitle ?? summary.level.localizedTitle(using: localization),
                    systemImage: badgeSystemImage
                )

                Text(summary.level.localizedTitle(using: localization))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let image = repository.solvedImage(for: summary.level) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: 360, maxHeight: 360)
                        .padding(22)
                        .background(
                            RoundedRectangle(cornerRadius: 40, style: .continuous)
                                .fill(AppTheme.cardBackground)
                                .shadow(color: AppTheme.shadowColor, radius: 24, x: 0, y: 18)
                        )

                    CompletionStamp(
                        title: stampTitle,
                        accentColor: accentColor
                    )
                    .offset(x: 12, y: -12)
                }
            }

            VStack(spacing: 10) {
                Text(headline)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(accentColor)
                    .multilineTextAlignment(.center)

                Text(detailText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text(
                        localization.string(
                            "completion.summary.meta",
                            summary.filledCells,
                            summary.level.palette.count
                        )
                    )
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.9))

                    HStack(spacing: 10) {
                        SummaryPill(
                            title: localization.string(
                                summary.completionRank == .perfect
                                    ? "common.rank.perfect"
                                    : "common.rank.normal"
                            ),
                            accentColor: summary.completionRank == .perfect ? AppTheme.accentGreen : accentColor
                        )
                        SummaryPill(
                            title: localization.string("daily.hero.streak", summary.streakSummary.current),
                            accentColor: AppTheme.accentGreen
                        )
                        if summary.streakSummary.awardedBadgeID != nil {
                            SummaryPill(
                                title: localization.string("badge.new"),
                                accentColor: AppTheme.accentOrange
                            )
                        }
                    }

                    if let missionSummary = summary.chapterMissionSummary {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localization.string("completion.missions.title"))
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                            ForEach(missionSummary.missions) { mission in
                                HStack {
                                    Text(mission.localizedTitle(using: localization))
                                    Spacer()
                                    Text(mission.progressLabel)
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: 320, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.86))
                        )
                    }
                }
            }

            VStack(spacing: 12) {
                Button(action: onPrimaryAction) {
                    Text(primaryActionTitle)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(accentColor)
                        )
                }
                .buttonStyle(.plain)

                if case .returnHome = summary.destination {
                    EmptyView()
                } else {
                    Button(action: onReturnHome) {
                        Text(localization.string("completion.action.backToTrail"))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.9))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 360)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private var badgeSystemImage: String {
        if case .daily = summary.sourceContext {
            return "sun.max.fill"
        }
        switch summary.destination {
        case .chapterUnlocked:
            return "rosette"
        case .openCollectionBook:
            return "books.vertical.fill"
        case .nextLevel:
            return "sparkles"
        case .returnHome:
            return "heart.fill"
        }
    }

    private var stampTitle: String {
        if case .daily = summary.sourceContext {
            return localization.string(
                summary.completionRank == .perfect
                    ? "completion.daily.stamp.perfect"
                    : "completion.daily.stamp.default"
            )
        }
        switch summary.destination {
        case .chapterUnlocked:
            return localization.string("completion.stamp.newPage")
        case .openCollectionBook:
            return localization.string("completion.stamp.complete")
        case .nextLevel:
            return localization.string("completion.stamp.flowOn")
        case .returnHome:
            return localization.string("completion.stamp.cozy")
        }
    }
}

private struct SummaryPill: View {
    let title: String
    let accentColor: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.14))
            )
    }
}

private struct CompletionBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.74))
            )
    }
}

private struct CompletionStamp: View {
    let title: String
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.16))
                .frame(width: 94, height: 94)

            Circle()
                .stroke(accentColor, lineWidth: 3)
                .frame(width: 82, height: 82)

            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(accentColor)
                .rotationEffect(.degrees(-12))
        }
    }
}
