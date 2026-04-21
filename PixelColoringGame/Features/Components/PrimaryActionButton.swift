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
        .buttonStyle(.plain)
    }
}
