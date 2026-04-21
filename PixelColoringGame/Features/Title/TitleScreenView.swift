import SwiftUI

struct TitleScreenView: View {
    @Environment(AppLocalization.self) private var localization

    let collectionTitle: String
    let defaultCollectionChapterID: String?
    let onOpenCollectionBook: (String?) -> Void
    let onStart: () -> Void

    @State private var breathing = false
    @State private var promptVisible = true

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
    }
}
