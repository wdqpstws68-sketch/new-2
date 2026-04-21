import SwiftUI

struct JourneyHomeView: View {
    @Environment(AppLocalization.self) private var localization

    let manifest: JourneyManifest
    let snapshot: JourneyProgressSnapshot
    let homeSnapshot: HomeProgressSnapshot
    let repository: LevelRepository
    let onSelectLevel: (LevelManifest, LevelEntrySource) -> Void
    let onOpenDailyChallenge: (LevelEntrySource) -> Void
    let onOpenCollectionBook: (String?) -> Void
    let onOpenMonthDetail: (String) -> Void

    @State private var didLogAppearance = false

    var body: some View {
        VStack(spacing: 0) {
            TabTopStrip(
                balance: homeSnapshot.lifeBalance,
                collectionTitle: manifest.localizedCollectionTitle(using: localization),
                defaultCollectionChapterID: defaultCollectionChapterID,
                onOpenCollectionBook: onOpenCollectionBook
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    JourneyHeroCard(
                        display: heroDisplay,
                        repository: repository,
                        onSelectLevel: onSelectLevel,
                        onOpenCollectionBook: onOpenCollectionBook
                    )

                    if let missionSummary = currentMissionSummary {
                        CompactChapterMissionCard(
                            summary: missionSummary,
                            chapterTitle: localization.string(missionSummary.chapterTitleKey)
                        )
                    }

                    JourneyChapterRailSection(
                        snapshot: snapshot,
                        repository: repository,
                        onSelectLevel: onSelectLevel
                    )
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.m)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .task {
            guard !didLogAppearance else { return }
            didLogAppearance = true
            AppLogger.journeyHomeViewed(currentChapterID: snapshot.currentChapterID)
        }
    }

    private var defaultCollectionChapterID: String? {
        snapshot.currentChapterID ?? snapshot.chapters.last?.id
    }

    private var currentMissionSummary: ChapterMissionSummary? {
        homeSnapshot.chapterMissionSummary(for: snapshot.currentChapterID ?? snapshot.chapters.last?.id)
    }

    private var heroDisplay: JourneyHeroDisplayModel {
        JourneyHeroDisplayModel.make(
            snapshot: snapshot,
            localization: localization,
            defaultCollectionChapterID: defaultCollectionChapterID
        )
    }
}

private struct JourneyHeroCard: View {
    let display: JourneyHeroDisplayModel
    let repository: LevelRepository
    let onSelectLevel: (LevelManifest, LevelEntrySource) -> Void
    let onOpenCollectionBook: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(display.eyebrow)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(display.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(display.accentColor.opacity(0.14))
                    )

                Text(display.title)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(display.metadata)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            JourneyHeroArtworkPanel(display: display, repository: repository)

            Button(action: performPrimaryAction) {
                HStack(spacing: 12) {
                    Text(display.buttonTitle)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    Image(systemName: display.style == .completed ? "books.vertical.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 22, weight: .black))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(display.style == .completed ? AppTheme.accentGreen : display.accentColor)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(display.buttonAccessibilityLabel)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(AppTheme.homeHeroSurface)
                .overlay {
                    ZStack {
                        LinearGradient(
                            colors: [
                                display.accentColor.opacity(0.22),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )

                        Image("HomeAccentBloom")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 120, height: 84)
                            .opacity(0.85)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.top, 6)
                            .padding(.trailing, 10)

                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 96, height: 96)
                            .offset(x: -10, y: 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .allowsHitTesting(false)
                }
                .shadow(color: display.accentColor.opacity(0.16), radius: 28, x: 0, y: 18)
        )
    }

    private func performPrimaryAction() {
        switch display.action {
        case let .level(level):
            onSelectLevel(level, .journeyHero)
        case let .collection(chapterID):
            onOpenCollectionBook(chapterID)
        }
    }
}

private struct JourneyHeroArtworkPanel: View {
    let display: JourneyHeroDisplayModel
    let repository: LevelRepository

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.74))

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1.2)

            Circle()
                .fill(display.accentColor.opacity(0.13))
                .frame(width: 170, height: 170)
                .offset(x: 78, y: -46)

            switch display.artwork {
            case let .level(levelState):
                switch JourneyHomePreviewPresentation.make(levelState: levelState, isUnlocked: true) {
                case .thumbnail:
                    if let image = repository.thumbnailImage(for: levelState.level) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(22)
                    } else {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 56, weight: .black))
                            .foregroundStyle(display.accentColor)
                    }
                case .silhouette:
                    if let image = repository.silhouetteImage(for: levelState.level, side: 240) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(22)
                    } else {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 56, weight: .black))
                            .foregroundStyle(display.accentColor)
                    }
                case .locked:
                    Image(systemName: "lock.fill")
                        .font(.system(size: 56, weight: .black))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            case let .collection(levels):
                JourneyCollectionCollage(levels: levels, repository: repository)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
    }
}

private struct JourneyCollectionCollage: View {
    let levels: [LevelManifest]
    let repository: LevelRepository

    var body: some View {
        ZStack {
            ForEach(Array(levels.prefix(3).enumerated()), id: \.offset) { index, level in
                JourneyCollectionCardPreview(
                    image: repository.solvedImage(for: level) ?? repository.thumbnailImage(for: level),
                    rotation: rotation(for: index),
                    offset: offset(for: index)
                )
            }

            if levels.isEmpty {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(AppTheme.accentGreen)
            }
        }
    }

    private func rotation(for index: Int) -> Angle {
        switch index {
        case 0:
            return .degrees(-10)
        case 1:
            return .degrees(2)
        default:
            return .degrees(11)
        }
    }

    private func offset(for index: Int) -> CGSize {
        switch index {
        case 0:
            return CGSize(width: -76, height: 8)
        case 1:
            return CGSize(width: 0, height: -10)
        default:
            return CGSize(width: 76, height: 10)
        }
    }
}

private struct JourneyCollectionCardPreview: View {
    let image: UIImage?
    let rotation: Angle
    let offset: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 1.2)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(12)
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(AppTheme.accentGreen)
            }
        }
        .frame(width: 102, height: 134)
        .rotationEffect(rotation)
        .offset(offset)
        .shadow(color: AppTheme.shadowColor, radius: 14, x: 0, y: 10)
    }
}

private struct JourneyChapterRailSection: View {
    @Environment(AppLocalization.self) private var localization

    let snapshot: JourneyProgressSnapshot
    let repository: LevelRepository
    let onSelectLevel: (LevelManifest, LevelEntrySource) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localization.string("journey.section.storyTrail"))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(snapshot.chapters) { chapterProgress in
                        JourneyChapterRailCard(
                            chapterProgress: chapterProgress,
                            repository: repository,
                            isCurrent: isCurrentChapter(chapterProgress.id),
                            unlockRemainingCount: snapshot.unlockRemainingCount(for: chapterProgress.id),
                            onSelectLevel: onSelectLevel
                        )
                    }
                }
                .padding(.trailing, 20)
            }
            .contentMargins(.vertical, 4)
        }
    }

    private func isCurrentChapter(_ chapterID: String) -> Bool {
        if let currentChapterID = snapshot.currentChapterID {
            return currentChapterID == chapterID
        }

        return snapshot.allChaptersCompleted && snapshot.chapters.last?.id == chapterID
    }
}

private struct JourneyChapterRailCard: View {
    @Environment(AppLocalization.self) private var localization

    let chapterProgress: JourneyChapterProgress
    let repository: LevelRepository
    let isCurrent: Bool
    let unlockRemainingCount: Int?
    let onSelectLevel: (LevelManifest, LevelEntrySource) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(chapterProgress.chapter.chapter.localizedTitle(using: localization))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                JourneyChapterStatusChip(
                    title: localization.string(chapterProgress.status.titleKey),
                    color: statusColor
                )
            }

            LazyVGrid(columns: previewColumns, spacing: 10) {
                ForEach(chapterProgress.levelStates) { levelState in
                    JourneyArtworkSlotPreview(
                        levelState: levelState,
                        repository: repository,
                        accentColor: accentColor,
                        isUnlocked: chapterProgress.isUnlocked
                    )
                }
            }

            chapterCTA

            Text(supportingText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 282, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(cardStroke, lineWidth: 1.2)
                }
                .shadow(color: shadowColor, radius: 20, x: 0, y: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chapterProgress.accessibilityLabel(using: localization))
    }

    private var previewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 2)
    }

    private var accentColor: Color {
        chapterProgress.isCompleted ? AppTheme.accentGreen : chapterProgress.chapter.chapter.accentColor
    }

    private var statusColor: Color {
        if chapterProgress.isCompleted {
            return AppTheme.accentGreen
        }
        return chapterProgress.isUnlocked ? chapterProgress.chapter.chapter.accentColor : AppTheme.textSecondary
    }

    private var cardBackground: Color {
        if !chapterProgress.isUnlocked {
            return AppTheme.homeRailSurface.opacity(0.92)
        }
        return isCurrent ? AppTheme.homeRailCurrent : AppTheme.homeRailSurface
    }

    private var cardStroke: Color {
        if isCurrent {
            return accentColor.opacity(0.32)
        }
        return Color.white.opacity(0.82)
    }

    private var shadowColor: Color {
        isCurrent ? accentColor.opacity(0.12) : AppTheme.shadowColor
    }

    @ViewBuilder
    private var chapterCTA: some View {
        if let nextLevel = chapterProgress.nextPlayableLevelState?.level,
           chapterProgress.isUnlocked {
            Button {
                onSelectLevel(nextLevel, .chapterRail)
            } label: {
                HStack(spacing: 10) {
                    Text(localization.string(chapterProgress.ctaTitleKey))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accentColor)
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 10) {
                Text(localization.string(chapterProgress.ctaTitleKey))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .black))
            }
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.7))
            )
        }
    }

    private var supportingText: String {
        if chapterProgress.isUnlocked {
            return chapterProgress.progressLabel(using: localization)
        }

        if let unlockRemainingCount {
            return localization.string("journey.chapter.unlockRemaining", unlockRemainingCount)
        }

        return localization.string("journey.locked.subtitle")
    }
}

private struct JourneyChapterStatusChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}

enum JourneyHomePreviewPresentation: Equatable {
    case thumbnail
    case silhouette
    case locked

    static func make(levelState: JourneyLevelState, isUnlocked: Bool) -> JourneyHomePreviewPresentation {
        guard isUnlocked else { return .locked }
        return levelState.isCompleted ? .thumbnail : .silhouette
    }
}

private struct JourneyArtworkSlotPreview: View {
    let levelState: JourneyLevelState
    let repository: LevelRepository
    let accentColor: Color
    let isUnlocked: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(previewPresentation == .locked ? Color.white.opacity(0.66) : Color.white.opacity(0.9))

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(previewPresentation == .locked ? Color.white.opacity(0.55) : accentColor.opacity(0.18), lineWidth: 1)

            Group {
                switch previewPresentation {
                case .locked:
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(AppTheme.textSecondary)
                case .thumbnail:
                    if let image = repository.thumbnailImage(for: levelState.level) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(10)
                    } else {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(accentColor)
                    }
                case .silhouette:
                    if let image = repository.silhouetteImage(for: levelState.level, side: 120) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(10)
                    } else {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(accentColor)
                    }
                }
            }

            if previewPresentation != .locked {
                statusBadge
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 84)
    }

    private var previewPresentation: JourneyHomePreviewPresentation {
        JourneyHomePreviewPresentation.make(levelState: levelState, isUnlocked: isUnlocked)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if levelState.isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(AppTheme.accentGreen)
        } else if levelState.isInProgress {
            Text("\(Int(levelState.progressFraction * 100))%")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(accentColor)
                )
        }
    }
}

struct JourneyHeroDisplayModel {
    enum Style {
        case play
        case completed
    }

    enum Action {
        case level(LevelManifest)
        case collection(String?)
    }

    enum Artwork {
        case level(JourneyLevelState)
        case collection([LevelManifest])
    }

    let style: Style
    let accentColor: Color
    let eyebrow: String
    let title: String
    let metadata: String
    let buttonTitle: String
    let buttonAccessibilityLabel: String
    let action: Action
    let artwork: Artwork

    static func make(
        snapshot: JourneyProgressSnapshot,
        localization: AppLocalization,
        defaultCollectionChapterID: String?
    ) -> JourneyHeroDisplayModel {
        let allLevelStates = snapshot.chapters.flatMap(\.levelStates)
        let hasAnyStartedProgress = allLevelStates.contains(where: { $0.isCompleted || $0.isInProgress })

        if snapshot.allChaptersCompleted {
            let previewLevels = allLevelStates
                .filter(\.isCompleted)
                .sorted { lhs, rhs in
                    (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
                }
                .prefix(3)
                .map(\.level)

            return JourneyHeroDisplayModel(
                style: .completed,
                accentColor: AppTheme.accentGreen,
                eyebrow: localization.string("journey.collectionComplete"),
                title: localization.string("journey.primary.collection.title"),
                metadata: localization.string("journey.hero.meta.completed"),
                buttonTitle: localization.string(JourneyPrimaryCTA.openCollectionBook(chapterID: defaultCollectionChapterID).buttonTitleKey),
                buttonAccessibilityLabel: localization.string("journey.openCollectionBook.accessibility"),
                action: .collection(defaultCollectionChapterID),
                artwork: .collection(Array(previewLevels))
            )
        }

        if !hasAnyStartedProgress,
           let firstChapter = snapshot.chapters.first(where: \.isUnlocked),
           let firstLevelState = firstChapter.levelStates.first {
            let buttonTitle = localization.string(JourneyPrimaryCTA.level(storageKey: firstLevelState.level.storageKey, kind: .start).buttonTitleKey)

            return JourneyHeroDisplayModel(
                style: .play,
                accentColor: firstChapter.chapter.chapter.accentColor,
                eyebrow: firstChapter.chapter.chapter.localizedBadgeTitle(using: localization),
                title: firstLevelState.level.localizedTitle(using: localization),
                metadata: [
                    firstChapter.chapter.chapter.localizedTitle(using: localization),
                    firstChapter.progressLabel(using: localization)
                ].joined(separator: " · "),
                buttonTitle: buttonTitle,
                buttonAccessibilityLabel: localization.string(
                    "common.inlinePair",
                    firstLevelState.level.localizedTitle(using: localization),
                    buttonTitle
                ),
                action: .level(firstLevelState.level),
                artwork: .level(firstLevelState)
            )
        }

        if case let .level(storageKey, kind) = snapshot.primaryCTA,
           let chapterProgress = snapshot.chapters.first(where: { $0.levelStates.contains(where: { $0.level.storageKey == storageKey }) }),
           let levelState = chapterProgress.levelStates.first(where: { $0.level.storageKey == storageKey }) {
            let progressPercent = Int(round((levelState.isCompleted ? 1 : levelState.progressFraction) * 100))
            let buttonTitle = localization.string(JourneyPrimaryCTA.level(storageKey: storageKey, kind: kind).buttonTitleKey)

            return JourneyHeroDisplayModel(
                style: .play,
                accentColor: chapterProgress.chapter.chapter.accentColor,
                eyebrow: chapterProgress.chapter.chapter.localizedBadgeTitle(using: localization),
                title: levelState.level.localizedTitle(using: localization),
                metadata: [
                    chapterProgress.chapter.chapter.localizedTitle(using: localization),
                    localization.string("journey.level.progress.inProgress", progressPercent)
                ].joined(separator: " · "),
                buttonTitle: buttonTitle,
                buttonAccessibilityLabel: localization.string(
                    "common.inlinePair",
                    levelState.level.localizedTitle(using: localization),
                    buttonTitle
                ),
                action: .level(levelState.level),
                artwork: .level(levelState)
            )
        }

        return JourneyHeroDisplayModel(
            style: .completed,
            accentColor: AppTheme.accentGreen,
            eyebrow: localization.string("journey.collectionComplete"),
            title: localization.string("journey.primary.collection.title"),
            metadata: localization.string("journey.hero.meta.completed"),
            buttonTitle: localization.string(JourneyPrimaryCTA.openCollectionBook(chapterID: defaultCollectionChapterID).buttonTitleKey),
            buttonAccessibilityLabel: localization.string("journey.openCollectionBook.accessibility"),
            action: .collection(defaultCollectionChapterID),
            artwork: .collection([])
        )
    }
}

private extension JourneyProgressSnapshot {
    func unlockRemainingCount(for chapterID: String) -> Int? {
        guard let currentIndex = chapters.firstIndex(where: { $0.id == chapterID }),
              currentIndex > 0 else {
            return nil
        }

        let previousChapter = chapters[currentIndex - 1]
        return max(previousChapter.totalLevelCount - previousChapter.completedLevelCount, 0)
    }
}

private struct CompactChapterMissionCard: View {
    @Environment(AppLocalization.self) private var localization

    let summary: ChapterMissionSummary
    let chapterTitle: String

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.m) {
            Image(systemName: "target")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppTheme.accentOrange)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(AppTheme.accentOrange.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(localization.string("mission.currentChapter.eyebrow"))
                    .font(AppTypography.caption())
                    .foregroundStyle(AppTheme.accentOrange)
                Text(chapterTitle)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(summary.completedCount)/\(summary.missions.count)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(AppTheme.surfaceElevated)
                )
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppTheme.homeRailSurface)
                .shadow(AppShadow.card)
        )
    }
}

private enum JourneyHomePreviewState {
    case initial
    case inProgress
    case completed
}

@MainActor
private struct JourneyHomePreviewContainer: View {
    let state: JourneyHomePreviewState

    private let levelRepository: LevelRepository
    private let journeyRepository: JourneyRepository

    init(state: JourneyHomePreviewState) {
        let levelRepository = LevelRepository()
        self.levelRepository = levelRepository
        self.journeyRepository = JourneyRepository(levelRepository: levelRepository)
        self.state = state
    }

    var body: some View {
        JourneyHomeView(
            manifest: journeyRepository.manifest,
            snapshot: snapshot,
            homeSnapshot: homeSnapshot,
            repository: levelRepository,
            onSelectLevel: { _, _ in },
            onOpenDailyChallenge: { _ in },
            onOpenCollectionBook: { _ in },
            onOpenMonthDetail: { _ in }
        )
        .environment(AppLocalization.preview)
    }

    private var snapshot: JourneyProgressSnapshot {
        JourneyProgressSnapshot(catalog: journeyRepository.catalog, progressValues: progressValues)
    }

    private var homeSnapshot: HomeProgressSnapshot {
        HomeProgressSnapshot(
            journeySnapshot: snapshot,
            dailyRepository: DailyChallengeRepository(levelRepository: levelRepository),
            progressLookup: [:],
            lifeBalance: LifeBalance(
                refillableLives: 3,
                bonusLives: state == .initial ? 3 : 0,
                maxRefillableLives: PlayerProfileStore.maxRefillableLives,
                refillInterval: PlayerProfileStore.refillInterval,
                nextRefillDate: Date().addingTimeInterval(PlayerProfileStore.refillInterval)
            ),
            profile: nil
        )
    }

    private var progressValues: [String: JourneyLevelProgressValue] {
        let levels = journeyRepository.catalog.chapters.flatMap(\.levels)
        let now = Date()

        switch state {
        case .initial:
            return [:]
        case .inProgress:
            guard let level = levels.first else { return [:] }
            return [
                level.storageKey: JourneyLevelProgressValue(
                    filledCellCount: max(1, level.paintableCellCount / 3),
                    completedAt: nil,
                    updatedAt: now
                )
            ]
        case .completed:
            return Dictionary(
                uniqueKeysWithValues: levels.enumerated().map { index, level in
                    let timestamp = now.addingTimeInterval(Double(-index) * 240)
                    return (
                        level.storageKey,
                        JourneyLevelProgressValue(
                            filledCellCount: level.paintableCellCount,
                            completedAt: timestamp,
                            updatedAt: timestamp
                        )
                    )
                }
            )
        }
    }
}

#Preview("Journey Home - Initial") {
    JourneyHomePreviewContainer(state: .initial)
}

#Preview("Journey Home - In Progress") {
    JourneyHomePreviewContainer(state: .inProgress)
}

#Preview("Journey Home - Completed") {
    JourneyHomePreviewContainer(state: .completed)
}
