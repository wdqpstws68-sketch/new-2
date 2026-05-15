import SwiftUI

struct TitleScreenView: View {
    @Environment(AppLocalization.self) private var localization

    let collectionTitle: String
    let defaultCollectionChapterID: String?
    let onOpenCollectionBook: (String?) -> Void
    let onStart: () -> Void
    #if DEBUG
    let celebrationCoordinator: CelebrationCoordinator?
    #endif

    @State private var appeared = false
    @State private var mascotFloat = false
    @State private var ctaPulse = false
    #if DEBUG
    @State private var showDebugMenu = false
    #endif

    init(
        collectionTitle: String,
        defaultCollectionChapterID: String?,
        onOpenCollectionBook: @escaping (String?) -> Void,
        onStart: @escaping () -> Void
    ) {
        self.collectionTitle = collectionTitle
        self.defaultCollectionChapterID = defaultCollectionChapterID
        self.onOpenCollectionBook = onOpenCollectionBook
        self.onStart = onStart
        #if DEBUG
        self.celebrationCoordinator = nil
        #endif
    }

    #if DEBUG
    init(
        collectionTitle: String,
        defaultCollectionChapterID: String?,
        onOpenCollectionBook: @escaping (String?) -> Void,
        onStart: @escaping () -> Void,
        celebrationCoordinator: CelebrationCoordinator?
    ) {
        self.collectionTitle = collectionTitle
        self.defaultCollectionChapterID = defaultCollectionChapterID
        self.onOpenCollectionBook = onOpenCollectionBook
        self.onStart = onStart
        self.celebrationCoordinator = celebrationCoordinator
    }
    #endif

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height

            ZStack {
                ambientBackdrop

                VStack(spacing: 0) {
                    Spacer(minLength: height * 0.12)

                    logoBlock
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)

                    Spacer(minLength: height * 0.05)

                    mascotStage
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.92)

                    Spacer(minLength: 0)

                    startButton
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .padding(.bottom, AppSpacing.xl)

                    #if DEBUG
                    versionStamp
                        .padding(.bottom, AppSpacing.s)
                    #endif
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, AppSpacing.xl)
            }
        }
        .overlay(alignment: .topTrailing) {
            JourneyUtilityMenuButton(
                collectionTitle: collectionTitle,
                defaultCollectionChapterID: defaultCollectionChapterID,
                onOpenCollectionBook: onOpenCollectionBook
            )
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.s)
            .opacity(appeared ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { onStart() }
        .onAppear(perform: startAnimations)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(localization.string("title.app.name"))
        .accessibilityHint(localization.string("title.tapToStart"))
        #if DEBUG
        .sheet(isPresented: $showDebugMenu) {
            DebugMenuView(coordinator: celebrationCoordinator)
        }
        #endif
    }

    // MARK: - Backdrop

    private var ambientBackdrop: some View {
        // A single calm focal glow behind the mascot — refined depth
        // without the muddy decorative texture of the old layout.
        RadialGradient(
            colors: [
                AppTheme.accentBerry.opacity(0.14),
                AppTheme.accentBerry.opacity(0.0)
            ],
            center: .center,
            startRadius: 8,
            endRadius: 340
        )
        .offset(y: 32)
        .blur(radius: 6)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Logo

    private var logoBlock: some View {
        VStack(spacing: AppSpacing.m) {
            Text(localization.string("title.app.name"))
                .font(AppTypography.titleXL())
                .kerning(0.5)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .shadow(color: AppTheme.accentBerry.opacity(0.12), radius: 12, x: 0, y: 8)

            // Refined accent rule — a small, calm brand mark.
            Capsule()
                .fill(AppTheme.accentBerry.opacity(0.85))
                .frame(width: appeared ? 44 : 0, height: 4)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Mascot

    private var mascotStage: some View {
        ZStack {
            Circle()
                .fill(AppTheme.surfaceElevated)
                .frame(width: 248, height: 248)
                .shadow(AppShadow.elevated)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                )

            IconAsset.mascot.image
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 168, height: 168)
                .foregroundStyle(AppTheme.accentBerry)
                .offset(y: (mascotFloat ? -6 : 6) - 6)
                .accessibilityHidden(true)
        }
        .background(alignment: .bottom) {
            // Grounding shadow so the mascot doesn't float untethered.
            Ellipse()
                .fill(AppTheme.textPrimary.opacity(0.10))
                .frame(width: 150, height: 26)
                .blur(radius: 8)
                .scaleEffect(mascotFloat ? 0.92 : 1.0)
                .offset(y: 18)
        }
    }

    // MARK: - CTA

    private var startButton: some View {
        Text(localization.string("title.tapToStart"))
            .font(AppTypography.button())
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.l)
            .background(
                Capsule()
                    .fill(AppTheme.textPrimary)
                    .shadow(color: AppTheme.textPrimary.opacity(0.28), radius: 16, x: 0, y: 10)
            )
            .scaleEffect(ctaPulse ? 1.03 : 1.0)
    }

    #if DEBUG
    private var versionStamp: some View {
        Text(versionLabel)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
            .onLongPressGesture(minimumDuration: 1.6) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showDebugMenu = true
            }
    }

    private var versionLabel: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(v) (\(b))"
    }
    #endif

    private func startAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
            appeared = true
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            mascotFloat = true
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            ctaPulse = true
        }
    }
}
