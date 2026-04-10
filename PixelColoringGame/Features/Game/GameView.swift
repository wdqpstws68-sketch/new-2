import SwiftUI
import SwiftData

struct GameView: View {
    let level: LevelManifest
    let nextLevel: LevelManifest?
    let progressStore: ProgressStore
    let onClose: () -> Void
    let onComplete: (LevelCompletionSummary) -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var session: GameSessionStore
    @State private var storedProgress: LevelProgress?
    @State private var feedback = HapticFeedbackRateLimiter()
    @State private var bannerTask: Task<Void, Never>?
    @State private var completionTask: Task<Void, Never>?

    init(
        level: LevelManifest,
        nextLevel: LevelManifest?,
        existingProgress: LevelProgress?,
        progressStore: ProgressStore,
        onClose: @escaping () -> Void,
        onComplete: @escaping (LevelCompletionSummary) -> Void
    ) {
        self.level = level
        self.nextLevel = nextLevel
        self.progressStore = progressStore
        self.onClose = onClose
        self.onComplete = onComplete
        _session = State(initialValue: GameSessionStore(level: level, progress: existingProgress))
        _storedProgress = State(initialValue: existingProgress)
    }

    var body: some View {
        VStack(spacing: 18) {
            header

            if let banner = session.bannerText {
                Text(banner)
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
                progressLabel: "\(session.completionLabel) filled",
                onSelectColor: { session.selectColor($0) },
                onHint: handleHint
            )
            .frame(maxWidth: 390)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .onDisappear {
            bannerTask?.cancel()
            completionTask?.cancel()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(level.title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("\(level.difficulty) · \(level.palette.count) colors · \(session.completionLabel)")
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

    private func handleTap(_ index: Int) {
        let outcome = session.tapCell(at: index)

        switch outcome {
        case .ignored, .alreadyFilled:
            return
        case .incorrect:
            feedback.incorrectTap()
            scheduleIncorrectClear()
        case .correct:
            feedback.correctTap()
            persistProgress()
            scheduleBannerClear()

            if session.isCompleted {
                feedback.success()
                scheduleCompletion()
            }
        }
    }

    private func handleHint() {
        guard session.applyHint() != nil else { return }
        feedback.correctTap()
        persistProgress()
        scheduleBannerClear()

        if session.isCompleted {
            feedback.success()
            scheduleCompletion()
        }
    }

    private func persistProgress() {
        storedProgress = try? progressStore.persist(session: session, existingProgress: storedProgress, in: modelContext)
    }

    private func scheduleIncorrectClear() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            session.clearHighlightedIncorrectCell()
        }
    }

    private func scheduleBannerClear() {
        bannerTask?.cancel()
        guard session.bannerText != nil else { return }
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

            onComplete(
                LevelCompletionSummary(
                    level: level,
                    nextLevel: nextLevel,
                    filledCells: session.filledCells.count
                )
            )
        }
    }
}
