import UIKit

@MainActor
final class HapticFeedbackRateLimiter {
    enum Stage {
        case cellFill        // 軽: セル塗り
        case colorComplete   // 中: 色完了
        case levelComplete   // 強: レベル完了
        case chapterClear    // 通知success: 章クリア
        case milestone       // 軽 通知: マイルストーントースト
        case incorrectTap    // 間違いタップ (既存互換)
    }

    private struct StageState {
        let minimumInterval: TimeInterval
        var lastTriggerDate: Date = .distantPast
    }

    private var states: [Stage: StageState] = [
        .cellFill: StageState(minimumInterval: 0.08),
        .colorComplete: StageState(minimumInterval: 0.20),
        .levelComplete: StageState(minimumInterval: 0.40),
        .chapterClear: StageState(minimumInterval: 0.50),
        .milestone: StageState(minimumInterval: 0.30),
        .incorrectTap: StageState(minimumInterval: 0.16),
    ]

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    init() {
        lightImpact.prepare()
        softImpact.prepare()
        mediumImpact.prepare()
        rigidImpact.prepare()
        notification.prepare()
    }

    func fire(_ stage: Stage) {
        guard var state = states[stage] else { return }
        let now = Date()
        guard now.timeIntervalSince(state.lastTriggerDate) >= state.minimumInterval else { return }
        state.lastTriggerDate = now
        states[stage] = state

        switch stage {
        case .cellFill:
            lightImpact.impactOccurred(intensity: 0.55)
        case .colorComplete:
            mediumImpact.impactOccurred(intensity: 0.85)
        case .levelComplete:
            rigidImpact.impactOccurred(intensity: 1.0)
        case .chapterClear:
            notification.notificationOccurred(.success)
        case .milestone:
            notification.notificationOccurred(.success)
        case .incorrectTap:
            softImpact.impactOccurred(intensity: 0.75)
        }
    }

}
