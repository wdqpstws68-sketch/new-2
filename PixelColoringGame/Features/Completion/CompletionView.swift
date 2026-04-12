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

    private var accentColor: Color {
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
                localization.string(summary.chapterTitleKey)
            )
        case .returnHome:
            return localization.string("completion.detail.returnHome")
        }
    }

    private var primaryActionTitle: String {
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
        guard case .chapterUnlocked = summary.destination else { return nil }
        return destinationChapter?.chapter.localizedBadgeTitle(using: localization)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                CompletionBadge(
                    title: ribbonTitle ?? localization.string(summary.chapterTitleKey),
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

                Text(
                    localization.string(
                        "completion.summary.meta",
                        summary.filledCells,
                        summary.level.palette.count
                    )
                )
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
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
