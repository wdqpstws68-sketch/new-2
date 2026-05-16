import SwiftUI
import Combine

@MainActor
final class CelebrationFlowState: ObservableObject {
    enum Stage: Int, CaseIterable {
        case background = 0
        case artwork
        case rank
        case stats
        case cta
    }

    @Published var visibleStages: Set<Stage> = []
    @Published var confettiTriggered: Bool = false
    @Published var isCTAReady: Bool = false

    private let profile: AnimationProfile
    private var started: Bool = false

    init(profile: AnimationProfile = .current) {
        self.profile = profile
    }

    func startIfNeeded() {
        guard !started else { return }
        started = true
        if profile.reduceMotion {
            visibleStages = Set(Stage.allCases)
            confettiTriggered = true
            isCTAReady = true
            return
        }
        for stage in Stage.allCases {
            let delay = profile.cascadeDelay(stage.rawValue)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                withAnimation(self.profile.fadeIn()) {
                    _ = self.visibleStages.insert(stage)
                }
                if stage == .artwork {
                    self.confettiTriggered = true
                }
                if stage == .cta {
                    self.isCTAReady = true
                }
            }
        }
    }
}
