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
    @State private var incorrectClearTask: Task<Void, Never>?

    // Transient state for a single paint stroke. A stroke is locked to the
    // colour it began on so a continuous sweep only fills that colour.
    @State private var strokeColor: Int?
    @State private var strokeFirstCell: Int?
    @State private var strokeDidDrag = false
    @State private var strokeProcessed: Set<Int> = []
    @State private var strokePaintedAny = false

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
        VStack(spacing: 12) {
            header

            PixelBoardView(
                session: session,
                onPaintBegan: handlePaintBegan,
                onPaintMoved: handlePaintMoved,
                onPaintEnded: handlePaintEnded,
                onPaintCancelled: handlePaintCancelled,
                onAccessibilityFill: accessibilityFill
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if let banner = session.banner {
                    bannerView(banner)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            PaletteTrayView(
                paletteStates: session.paletteStates,
                onSelectColor: { session.selectColor($0) },
                onHint: handleHint
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .animation(.easeInOut(duration: 0.25), value: session.banner)
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
            incorrectClearTask?.cancel()
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
            .buttonStyle(.tapSound)
        }
    }

    private func bannerView(_ banner: GameSessionStore.Banner) -> some View {
        Text(banner.text(using: localization))
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(session.isCompleted ? AppTheme.accentGreen : AppTheme.accentOrange)
                    .shadow(color: AppTheme.shadowColor, radius: 8, x: 0, y: 4)
            )
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

    private func handlePaintBegan(_ index: Int?) {
        strokeColor = session.selectedColorIndex
        strokeFirstCell = index
        strokeDidDrag = false
        strokePaintedAny = false
        strokeProcessed = []

        if let index {
            strokeProcessed.insert(index)
            applyStrokeFill(at: index)
        }
    }

    private func handlePaintMoved(_ index: Int) {
        strokeDidDrag = true
        guard !strokeProcessed.contains(index) else { return }
        strokeProcessed.insert(index)
        applyStrokeFill(at: index)
    }

    private func applyStrokeFill(at index: Int) {
        guard let color = strokeColor else { return }
        guard session.paintCell(at: index, color: color) == .correct else { return }

        strokePaintedAny = true
        audio.playTap()

        if session.remainingCount(for: color) == 0 {
            feedback.fire(.colorComplete)
        } else {
            feedback.fire(.cellFill)
        }
        scheduleBannerClear()

        if session.isCompleted {
            feedback.fire(.levelComplete)
            persistProgress()
            scheduleCompletion()
        }
    }

    private func handlePaintEnded() {
        finishStroke(penalizeTap: true)
    }

    // Called when a second finger turns the stroke into a zoom/pan gesture: the
    // in-progress stroke is abandoned without the wrong-colour penalty.
    private func handlePaintCancelled() {
        finishStroke(penalizeTap: false)
    }

    private func finishStroke(penalizeTap: Bool) {
        let wasTap = !strokeDidDrag
        let firstCell = strokeFirstCell
        let color = strokeColor
        let paintedAny = strokePaintedAny

        strokeColor = nil
        strokeFirstCell = nil
        strokeDidDrag = false
        strokeProcessed = []
        strokePaintedAny = false

        guard let color else { return }

        // A deliberate single tap on a non-matching, still-empty cell keeps the
        // classic "wrong colour" cue. Sweeping over mismatched cells while
        // dragging — or aborting into a two-finger gesture — stays penalty-free.
        if penalizeTap,
           wasTap,
           let firstCell,
           let expected = session.level.colorIndex(at: firstCell),
           !session.filledCells.contains(firstCell),
           expected != color {
            if session.tapCell(at: firstCell) == .incorrect {
                feedback.fire(.incorrectTap)
                scheduleIncorrectClear()
            }
        }

        session.advanceSelectionIfColorCompleted()

        if paintedAny {
            persistProgress()
            scheduleBannerClear()
        }
    }

    /// VoiceOver path: activating a cell fills it with its own correct colour.
    /// The drag/pinch recognisers are invisible to assistive tech, so this gives
    /// the board a fully operable accessibility action.
    private func accessibilityFill(_ index: Int) {
        guard let color = session.level.colorIndex(at: index),
              !session.filledCells.contains(index) else { return }

        session.selectColor(color)
        guard session.paintCell(at: index, color: color) == .correct else { return }

        audio.playTap()
        if session.remainingCount(for: color) == 0 {
            feedback.fire(.colorComplete)
        } else {
            feedback.fire(.cellFill)
        }
        session.advanceSelectionIfColorCompleted()
        scheduleBannerClear()
        persistProgress()

        if session.isCompleted {
            feedback.fire(.levelComplete)
            scheduleCompletion()
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
        incorrectClearTask?.cancel()
        incorrectClearTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
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
