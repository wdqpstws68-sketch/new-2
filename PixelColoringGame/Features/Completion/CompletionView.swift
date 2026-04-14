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
        case .nextLevel, .returnHome, .returnToEvent:
            return nil
        }
    }

    private var chapterTitle: String? {
        switch summary.sourceContext {
        case let .journey(_, chapterTitleKey):
            return localization.string(chapterTitleKey)
        case .daily, .event:
            return nil
        }
    }

    private var accentColor: Color {
        switch summary.sourceContext {
        case .daily, .event:
            return summary.completionRank == .perfect ? AppTheme.accentGreen : AppTheme.accentOrange
        case .journey:
            break
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
        case .returnToEvent:
            return AppTheme.accentOrange
        }
    }

    private var headline: String {
        switch summary.sourceContext {
        case .daily:
            return localization.string(
                summary.completionRank == .perfect
                    ? "completion.daily.headline.perfect"
                    : "completion.daily.headline.cleared"
            )
        case .event:
            return localization.string(
                summary.completionRank == .perfect
                    ? "completion.event.headline.perfect"
                    : "completion.event.headline.cleared"
            )
        case .journey:
            break
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
        case .returnToEvent:
            return localization.string("completion.event.headline.cleared")
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
        if case let .event(_, eventTitleKey) = summary.sourceContext {
            return localization.string(
                "completion.event.detail",
                localization.string(eventTitleKey)
            )
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
        case .returnToEvent:
            return localization.string("completion.event.detail", summary.level.localizedTitle(using: localization))
        }
    }

    private var primaryActionTitle: String {
        switch summary.sourceContext {
        case .daily:
            return localization.string("completion.daily.action.home")
        case .event:
            return localization.string("completion.event.action.return")
        case .journey:
            break
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
        case .returnToEvent:
            return localization.string("completion.event.action.return")
        }
    }

    private var ribbonTitle: String? {
        if case let .daily(_, titleKey, _) = summary.sourceContext {
            return localization.string(titleKey)
        }
        if case let .event(_, eventTitleKey) = summary.sourceContext {
            return localization.string(eventTitleKey)
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
                                .overlay(alignment: .bottomLeading) {
                                    Image("CompletionRosetteSparkles")
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: 112, height: 84)
                                        .opacity(0.24)
                                        .offset(x: -8, y: 10)
                                }
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
                        if summary.unlockedEventTitle != nil {
                            SummaryPill(
                                title: localization.string("completion.events.titleUnlockedPill"),
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

                    if let unlockedEventTitle = summary.unlockedEventTitle {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localization.string("completion.events.titleUnlocked"))
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.accentOrange)
                            Text(unlockedEventTitle.localizedTitle(using: localization))
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(unlockedEventTitle.localizedSubtitle(using: localization))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(16)
                        .frame(maxWidth: 320, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(AppTheme.accentOrange.opacity(0.12))
                                .overlay(alignment: .topTrailing) {
                                    Image("CompletionRosetteSparkles")
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: 88, height: 64)
                                        .opacity(0.9)
                                        .offset(x: 10, y: -10)
                                }
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
        switch summary.sourceContext {
        case .daily:
            return "sun.max.fill"
        case .event:
            return "sparkles.rectangle.stack.fill"
        case .journey:
            break
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
        case .returnToEvent:
            return "sparkles.rectangle.stack.fill"
        }
    }

    private var stampTitle: String {
        switch summary.sourceContext {
        case .daily:
            return localization.string(
                summary.completionRank == .perfect
                    ? "completion.daily.stamp.perfect"
                    : "completion.daily.stamp.default"
            )
        case .event:
            return localization.string(
                summary.completionRank == .perfect
                    ? "completion.event.stamp.perfect"
                    : "completion.event.stamp.default"
            )
        case .journey:
            break
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
        case .returnToEvent:
            return localization.string("completion.event.stamp.default")
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
