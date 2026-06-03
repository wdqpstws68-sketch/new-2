import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String?
    let tint: Color
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        tint: Color = AppTheme.accentOrange,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.m) {
                Text(title)
                    .font(AppTypography.button())
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .black))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.l)
            .background(
                Capsule(style: .continuous)
                    .fill(tint)
            )
            .shadow(AppShadow.card)
        }
        .buttonStyle(.tapSound)
    }
}

/// A drop-in replacement for `.plain` that also plays the UI tap sound on press.
/// Renders the label exactly like `PlainButtonStyle` so it is a safe app-wide
/// swap; the sound is throttled inside `AudioPlayerService`.
struct TapSoundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TapSoundButtonStyleBody(configuration: configuration)
    }
}

extension ButtonStyle where Self == TapSoundButtonStyle {
    /// Plain appearance plus a tap sound on press.
    static var tapSound: TapSoundButtonStyle { TapSoundButtonStyle() }
}

private struct TapSoundButtonStyleBody: View {
    let configuration: TapSoundButtonStyle.Configuration

    // Optional so buttons rendered outside the app's audio environment
    // (e.g. SwiftUI previews) don't crash.
    @Environment(AudioPlayerService.self) private var audio: AudioPlayerService?

    var body: some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { audio?.playTap() }
            }
    }
}
