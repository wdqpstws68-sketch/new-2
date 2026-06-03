import SwiftUI

struct ChapterClearView: View {
    let chapterTitleKey: String
    let nextChapterTitleKey: String?
    let onDismiss: () -> Void

    @Environment(AppLocalization.self) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badgeScale: CGFloat = 0.55
    @State private var badgeOpacity: Double = 0.0

    private var profile: AnimationProfile {
        AnimationProfile(
            reduceMotion: reduceMotion,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            VStack(spacing: 28) {
                Spacer(minLength: 0)
                badge
                titleBlock
                if let nextKey = nextChapterTitleKey {
                    nextHint(titleKey: nextKey)
                }
                Spacer(minLength: 0)
                continueButton
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 56)

            ParticleEmitterView(preset: .confetti, profile: profile)
                .ignoresSafeArea()
        }
        .onAppear {
            if reduceMotion {
                badgeScale = 1.0
                badgeOpacity = 1.0
            } else {
                withAnimation(profile.pop().delay(0.12)) {
                    badgeScale = 1.0
                    badgeOpacity = 1.0
                }
            }
        }
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(AppTheme.celebrationGold)
                .shadow(color: AppTheme.celebrationGold.opacity(0.4), radius: 30)
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .padding(38)
                .foregroundStyle(.white)
        }
        .frame(width: 168, height: 168)
        .scaleEffect(badgeScale)
        .opacity(badgeOpacity)
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text(localization.string("chapter.clear.eyebrow"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)
            Text(localization.string(chapterTitleKey))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    private func nextHint(titleKey: String) -> some View {
        VStack(spacing: 4) {
            Text(localization.string("chapter.clear.next"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
            Text(localization.string(titleKey))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private var continueButton: some View {
        Button(action: onDismiss) {
            Text(localization.string("chapter.clear.continue"))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.celebrationGold)
                )
        }
        .buttonStyle(.tapSound)
    }
}

#if DEBUG
#Preview("Normal") {
    ChapterClearView(
        chapterTitleKey: "chapter.berry-meadow.title",
        nextChapterTitleKey: "chapter.cloud-port.title",
        onDismiss: {}
    )
    .environment(AppLocalization.preview)
}

#Preview("No next chapter") {
    ChapterClearView(
        chapterTitleKey: "chapter.berry-meadow.title",
        nextChapterTitleKey: nil,
        onDismiss: {}
    )
    .environment(AppLocalization.preview)
}
#endif
