import SwiftUI

struct JourneyCompleteView: View {
    let onDismiss: () -> Void

    @Environment(AppLocalization.self) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var medalScale: CGFloat = 0.5
    @State private var medalOpacity: Double = 0.0

    private var profile: AnimationProfile {
        AnimationProfile(
            reduceMotion: reduceMotion,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    var body: some View {
        ZStack {
            AppTheme.celebrationDeep.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                medal
                titleBlock
                Spacer()
                continueButton
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 56)

            ParticleEmitterView(preset: .confetti, profile: profile)
                .ignoresSafeArea()
        }
        .onAppear {
            if reduceMotion {
                medalScale = 1.0
                medalOpacity = 1.0
            } else {
                withAnimation(profile.pop().delay(0.15)) {
                    medalScale = 1.0
                    medalOpacity = 1.0
                }
            }
        }
    }

    private var medal: some View {
        Image(systemName: "star.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 200, height: 200)
            .foregroundStyle(AppTheme.celebrationGold)
            .scaleEffect(medalScale)
            .opacity(medalOpacity)
            .shadow(color: AppTheme.celebrationGold.opacity(0.6), radius: 36)
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text(localization.string("journey.complete.eyebrow"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
            Text(localization.string("journey.complete.title"))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(localization.string("journey.complete.subtitle"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    private var continueButton: some View {
        Button(action: onDismiss) {
            Text(localization.string("journey.complete.continue"))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.celebrationDeep)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.celebrationGold)
                )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview { JourneyCompleteView(onDismiss: {}).environment(AppLocalization.preview) }
#endif
