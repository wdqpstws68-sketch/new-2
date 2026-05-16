import SwiftUI

struct AnimationProfile {
    let reduceMotion: Bool
    let lowPower: Bool

    @MainActor
    static var current: AnimationProfile {
        AnimationProfile(
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    var shouldShowParticles: Bool {
        !reduceMotion
    }

    var particleBudget: Int {
        guard shouldShowParticles else { return 0 }
        return lowPower ? 24 : 80
    }

    func cascadeDelay(_ index: Int) -> Double {
        reduceMotion ? 0 : 0.15 * Double(index)
    }

    func pop() -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.25, dampingFraction: 0.55)
    }

    func tintTransition() -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .easeInOut(duration: 0.25)
    }

    func fadeIn() -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.20)
            : .easeOut(duration: 0.35)
    }
}
