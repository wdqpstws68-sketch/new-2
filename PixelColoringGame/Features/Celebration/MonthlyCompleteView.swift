import SwiftUI

struct MonthlyCompleteView: View {
    let yearMonth: String
    let hasNextMonth: Bool
    let onContinue: () -> Void
    let onGoToNextMonth: () -> Void

    @Environment(AppLocalization.self) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0.0

    private var profile: AnimationProfile {
        AnimationProfile(
            reduceMotion: reduceMotion,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    var body: some View {
        ZStack {
            AppTheme.celebrationMonthly.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                icon
                titleBlock
                Spacer()
                cta
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 56)

            ParticleEmitterView(preset: .confetti, profile: profile)
                .ignoresSafeArea()
        }
        .onAppear {
            if reduceMotion {
                iconScale = 1.0
                iconOpacity = 1.0
            } else {
                withAnimation(profile.pop().delay(0.12)) {
                    iconScale = 1.0
                    iconOpacity = 1.0
                }
            }
        }
    }

    private var icon: some View {
        Image(systemName: "calendar.badge.checkmark")
            .resizable()
            .scaledToFit()
            .frame(width: 180, height: 180)
            .foregroundStyle(.white)
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .shadow(radius: 24)
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text(localization.string("monthly.complete.eyebrow"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
            Text(yearMonth)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(localization.string("monthly.complete.subtitle"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var cta: some View {
        if hasNextMonth {
            primaryButton(title: localization.string("monthly.complete.nextMonth"), action: onGoToNextMonth)
        } else {
            primaryButton(title: localization.string("monthly.complete.continue"), action: onContinue)
        }
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.celebrationMonthly)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.white)
                )
        }
        .buttonStyle(.tapSound)
    }
}

#if DEBUG
#Preview("Next month available") {
    MonthlyCompleteView(
        yearMonth: "2026-04",
        hasNextMonth: true,
        onContinue: {},
        onGoToNextMonth: {}
    )
    .environment(AppLocalization.preview)
}

#Preview("No next month") {
    MonthlyCompleteView(
        yearMonth: "2026-12",
        hasNextMonth: false,
        onContinue: {},
        onGoToNextMonth: {}
    )
    .environment(AppLocalization.preview)
}
#endif
