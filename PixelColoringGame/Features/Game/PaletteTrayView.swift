import SwiftUI

/// A slim, horizontally-scrolling palette so the artwork can dominate the
/// screen. Each swatch shows its colour number plus how many cells remain, and
/// the active colour stays scrolled into view as the player progresses.
struct PaletteTrayView: View {
    @Environment(AppLocalization.self) private var localization

    let paletteStates: [GameSessionStore.PaletteChipState]
    let onSelectColor: (Int) -> Void
    let onHint: () -> Void

    private var selectedColorIndex: Int? {
        paletteStates.first(where: { $0.isSelected })?.entry.index
    }

    var body: some View {
        HStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(paletteStates) { state in
                            PaletteSwatchView(state: state) {
                                onSelectColor(state.entry.index)
                            }
                            .id(state.entry.index)
                            .environment(localization)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .onChange(of: selectedColorIndex) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            hintButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.trayBackground)
                .shadow(color: AppTheme.shadowColor, radius: 14, x: 0, y: 8)
        )
    }

    private var hintButton: some View {
        Button(action: onHint) {
            VStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .black))
                Text(localization.string("game.palette.hint"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 54, height: 54)
            .background(
                Circle()
                    .fill(AppTheme.accentGreen)
                    .shadow(color: AppTheme.accentGreen.opacity(0.35), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.tapSound)
        .accessibilityLabel(Text(localization.string("game.palette.hint")))
    }
}

private struct PaletteSwatchView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let state: GameSessionStore.PaletteChipState
    let onSelect: () -> Void

    @State private var celebrateScale: CGFloat = 1.0
    @State private var hasCelebrated = false

    private let diameter: CGFloat = 46

    private var profile: AnimationProfile {
        AnimationProfile(
            reduceMotion: reduceMotion,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Circle()
                    .fill(state.isCompleted ? AppTheme.completedTint : state.entry.color)
                    .frame(width: diameter, height: diameter)
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.8)
                    }
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(Color.white.opacity(state.isCompleted ? 0.12 : 0.42))
                            .frame(width: 10, height: 10)
                            .offset(x: 7, y: 7)
                    }
                    .overlay {
                        if state.isSelected {
                            Circle()
                                .stroke(state.isCompleted ? AppTheme.completedTint : state.entry.color, lineWidth: 3)
                                .padding(-4)
                                .background(
                                    Circle().stroke(Color.white, lineWidth: 2).padding(-4)
                                )
                        }
                    }

                if state.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                } else {
                    Text("\(state.entry.index + 1)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.95))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !state.isCompleted {
                    Text("\(state.remainingCount)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule().fill(Color.white)
                                .shadow(color: AppTheme.shadowColor, radius: 2, x: 0, y: 1)
                        )
                        .offset(x: 6, y: 4)
                }
            }
            .scaleEffect(celebrateScale * (state.isSelected ? 1.08 : 1.0))
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.tapSound)
        .accessibilityLabel(Text(accessibilityLabel))
        .onChange(of: state.isCompleted) { _, completed in
            guard completed, !hasCelebrated else {
                if !completed { hasCelebrated = false }
                return
            }
            hasCelebrated = true
            guard !reduceMotion else { return }
            withAnimation(profile.pop()) { celebrateScale = 1.2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeOut(duration: 0.28)) { celebrateScale = 1.0 }
            }
        }
        .onAppear { hasCelebrated = state.isCompleted }
    }

    private var accessibilityLabel: String {
        let status = state.isCompleted
            ? localization.string("game.palette.done")
            : localization.string("game.palette.left", state.remainingCount)
        return "\(state.entry.index + 1) · \(status)"
    }
}
