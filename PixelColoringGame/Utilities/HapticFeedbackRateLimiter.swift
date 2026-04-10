import UIKit

@MainActor
final class HapticFeedbackRateLimiter {
    private var lastTriggerDate = Date.distantPast
    private let minimumInterval: TimeInterval

    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    init(minimumInterval: TimeInterval = 0.16) {
        self.minimumInterval = minimumInterval
        softImpact.prepare()
        rigidImpact.prepare()
        notification.prepare()
    }

    func incorrectTap() {
        triggerIfAllowed {
            softImpact.impactOccurred(intensity: 0.75)
        }
    }

    func correctTap() {
        rigidImpact.impactOccurred(intensity: 0.8)
    }

    func success() {
        notification.notificationOccurred(.success)
    }

    private func triggerIfAllowed(_ action: () -> Void) {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerDate) >= minimumInterval else { return }
        lastTriggerDate = now
        action()
    }
}
