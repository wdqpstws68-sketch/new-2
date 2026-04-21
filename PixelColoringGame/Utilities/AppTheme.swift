import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(hex: "F6F0FF")
    static let backgroundBottom = Color(hex: "FFF9F0")
    static let cardBackground = Color.white.opacity(0.88)
    static let boardBackground = Color.white.opacity(0.9)
    static let trayBackground = Color(hex: "FFF3E3")
    static let chipEmpty = Color(hex: "F8C99C")
    static let chipBorder = Color(hex: "E8B37E")
    static let accentOrange = Color(hex: "FF8A2A")
    static let accentGreen = Color(hex: "5DD64D")
    static let textPrimary = Color(hex: "2C2352")
    static let textSecondary = Color(hex: "7C6E98")
    static let shadowColor = Color.black.opacity(0.08)
    static let completedTint = Color(hex: "B9B4C9")
    static let homeHeroSurface = Color.white.opacity(0.94)
    static let homeRailSurface = Color.white.opacity(0.9)
    static let homeRailCurrent = Color(hex: "FFF5E9")
    static let homeUtilityBackground = Color.white.opacity(0.82)

    static let accentBerry = Color(hex: "E86AA8")
    static let accentSky = Color(hex: "7AB8E8")
    static let surfaceElevated = Color.white.opacity(0.96)
    static let surfaceSunken = Color(hex: "EFE6FF").opacity(0.55)
}

struct AppBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.white.opacity(0.32))
                .frame(width: 220, height: 220)
                .offset(x: -80, y: -70)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(hex: "FFD8B5").opacity(0.28))
                .frame(width: 260, height: 260)
                .offset(x: 80, y: 120)
        }
        .ignoresSafeArea()
    }
}
