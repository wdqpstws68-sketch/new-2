import SwiftUI

enum AppSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum AppCornerRadius {
    static let small: CGFloat = 14
    static let medium: CGFloat = 20
    static let large: CGFloat = 28
}

enum AppTypography {
    static func titleXL() -> Font { .system(size: 40, weight: .black, design: .rounded) }
    static func title() -> Font { .system(size: 31, weight: .black, design: .rounded) }
    static func headline() -> Font { .system(size: 22, weight: .bold, design: .rounded) }
    static func body() -> Font { .system(size: 16, weight: .semibold, design: .rounded) }
    static func caption() -> Font { .system(size: 12, weight: .bold, design: .rounded) }
    static func button() -> Font { .system(size: 18, weight: .black, design: .rounded) }
}

struct AppShadow {
    static let card = ShadowStyle(
        color: AppTheme.shadowColor,
        radius: 18,
        x: 0,
        y: 12
    )
    static let elevated = ShadowStyle(
        color: Color.black.opacity(0.12),
        radius: 26,
        x: 0,
        y: 16
    )

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

extension View {
    func shadow(_ style: AppShadow.ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
