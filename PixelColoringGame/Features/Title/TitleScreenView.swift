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

    @State private var breathing = false
    @State private var promptVisible = true
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
        ZStack {
            Image("HomeAccentBloom")
                .resizable()
                .scaledToFit()
                .frame(width: 360, height: 360)
                .opacity(0.55)
                .offset(y: -40)
                .accessibilityHidden(true)

            VStack(spacing: AppSpacing.xl) {
                Spacer(minLength: 0)

                Text(localization.string("title.app.name"))
                    .font(AppTypography.titleXL())
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)

                IconAsset.mascot.image
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .foregroundStyle(AppTheme.accentBerry)
                    .scaleEffect(breathing ? 1.04 : 1.0)
                    .shadow(AppShadow.elevated)
                    .accessibilityLabel(localization.string("title.mascot.accessibility"))

                Spacer(minLength: 0)

                Text(localization.string("title.tapToStart"))
                    .font(AppTypography.button())
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.m)
                    .background(
                        Capsule()
                            .fill(AppTheme.surfaceElevated)
                            .shadow(AppShadow.card)
                    )
                    .opacity(promptVisible ? 1.0 : 0.45)
                    .padding(.bottom, AppSpacing.xxl)

                #if DEBUG
                Text(versionLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                    .padding(.bottom, 8)
                    .onLongPressGesture(minimumDuration: 1.6) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showDebugMenu = true
                    }
                #endif
            }
            .padding(.horizontal, AppSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    Spacer(minLength: 0)
                    JourneyUtilityMenuButton(
                        collectionTitle: collectionTitle,
                        defaultCollectionChapterID: defaultCollectionChapterID,
                        onOpenCollectionBook: onOpenCollectionBook
                    )
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.s)
                Spacer(minLength: 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onStart()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                promptVisible = false
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(localization.string("title.tapToStart"))
        #if DEBUG
        .sheet(isPresented: $showDebugMenu) {
            DebugMenuView(coordinator: celebrationCoordinator)
        }
        #endif
    }

    #if DEBUG
    private var versionLabel: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(v) (\(b))"
    }
    #endif
}
