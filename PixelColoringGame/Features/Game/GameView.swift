import SwiftUI
import SwiftData

struct GameView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(AudioPlayerService.self) private var audio

    let level: LevelManifest
    let playContext: PlayRouteContext
    let chapterID: String?
    let startFresh: Bool
    let progressStore: ProgressStore
    let onClose: () -> Void
    let onComplete: (LevelManifest, PlayRouteContext, Int, CompletionRank) -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var session: GameSessionStore
    @State private var storedProgress: LevelProgress?
    @State private var feedback = HapticFeedbackRateLimiter()
    @State private var bannerTask: Task<Void, Never>?
    @State private var completionTask: Task<Void, Never>?

    init(
        level: LevelManifest,
        existingProgress: LevelProgress?,
        playContext: PlayRouteContext,
        chapterID: String?,
        startFresh: Bool = false,
        progressStore: ProgressStore,
        onClose: @escaping () -> Void,
        onComplete: @escaping (LevelManifest, PlayRouteContext, Int, CompletionRank) -> Void
    ) {
        self.level = level
        self.playContext = playContext
        self.chapterID = chapterID
        self.startFresh = startFresh
        self.progressStore = progressStore
        self.onClose = onClose
        self.onComplete = onComplete
        _session = State(initialValue: GameSessionStore(level: level, progress: existingProgress, startFresh: startFresh))
        _storedProgress = State(initialValue: existingProgress)
    }

    var body: some View {
        VStack(spacing: 18) {
            header

            if let banner = session.banner {
                Text(banner.text(using: localization))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(session.isCompleted ? AppTheme.accentGreen : AppTheme.accentOrange)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            PixelBoardView(session: session, onTapCell: handleTap)
                .frame(maxWidth: 390)
                .aspectRatio(1, contentMode: .fit)

            PaletteTrayView(
                paletteStates: session.paletteStates,
                progressLabel: session.completionLabel,
                onSelectColor: { session.selectColor($0) },
                onHint: handleHint
            )
            .frame(maxWidth: 390)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .onAppear {
            switch playContext {
            case .journey:
                if let chapterID {
                    audio.playBGM(ChapterBGMResolver.bgm(for: chapterID))
                }
            case .dailyToday, .monthlyFreeplay:
                audio.playBGM(.bgmEvent)
            }
        }
        .onDisappear {
            bannerTask?.cancel()
            completionTask?.cancel()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(level.localizedTitle(using: localization))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(
                    headerMetadata
                )
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.72))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var headerMetadata: String {
        switch playContext {
        case .journey:
            return localization.string(
                "game.header.meta",
                level.localizedDifficulty(using: localization),
                level.palette.count,
                session.completionLabel
            )
        case let .dailyToday(_, _, monthTitleKey, _):
            let label = localization.string(monthTitleKey)
            return "\(label) · \(session.completionLabel)"
        case let .monthlyFreeplay(_, monthTitleKey, _):
            return "\(localization.string(monthTitleKey)) · \(session.completionLabel)"
        }
    }

    private var isReplaySession: Bool {
        startFresh && storedProgress?.completedAt != nil
    }

    private func handleTap(_ index: Int) {
        let outcome = session.tapCell(at: index)

        switch outcome {
        case .ignored, .alreadyFilled:
            return
        case .incorrect:
            feedback.fire(.incorrectTap)
            scheduleIncorrectClear()
        case .correct:
            feedback.fire(.cellFill)
            persistProgress()
            scheduleBannerClear()

            if session.isCompleted {
                feedback.fire(.levelComplete)
                scheduleCompletion()
            }
        }
    }

    private func handleHint() {
        guard session.applyHint() != nil else { return }
        feedback.fire(.cellFill)
        persistProgress()
        scheduleBannerClear()

        if session.isCompleted {
            feedback.fire(.levelComplete)
            scheduleCompletion()
        }
    }

    private func persistProgress() {
        if isReplaySession && !session.isCompleted {
            return
        }
        do {
            storedProgress = try progressStore.persist(
                session: session,
                existingProgress: storedProgress,
                in: modelContext
            )
        } catch {
            AppLogger.persistenceSaveFailed(reason: "game_persist_progress", error: error)
            assertionFailure("Failed to persist progress: \(error)")
        }
    }

    private func scheduleIncorrectClear() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            session.clearHighlightedIncorrectCell()
        }
    }

    private func scheduleBannerClear() {
        bannerTask?.cancel()
        guard session.banner != nil else { return }
        bannerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            session.clearBanner()
        }
    }

    private func scheduleCompletion() {
        completionTask?.cancel()
        completionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }

            onComplete(level, playContext, session.filledCells.count, session.completionRank)
        }
    }
}
