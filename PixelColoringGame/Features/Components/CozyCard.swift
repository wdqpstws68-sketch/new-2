import SwiftUI

struct CozyCard<Content: View>: View {
    enum Elevation { case flat, raised, hero }

    let elevation: Elevation
    let cornerRadius: CGFloat
    let content: () -> Content

    init(
        elevation: Elevation = .raised,
        cornerRadius: CGFloat = AppCornerRadius.large,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.elevation = elevation
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .padding(AppSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(shadowStyle)
    }

    private var fill: Color {
        switch elevation {
        case .flat: return AppTheme.surfaceSunken
        case .raised: return AppTheme.cardBackground
        case .hero: return AppTheme.surfaceElevated
        }
    }

    private var shadowStyle: AppShadow.ShadowStyle {
        switch elevation {
        case .flat: return AppShadow.ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        case .raised: return AppShadow.card
        case .hero: return AppShadow.elevated
        }
    }
}
