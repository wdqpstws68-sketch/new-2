import SwiftUI

struct MilestoneToastHost: View {
    @ObservedObject var coordinator: CelebrationCoordinator
    @State private var dismissTask: Task<Void, Never>?
    @State private var consumedSeconds: Double = 0

    var body: some View {
        VStack {
            if let event = coordinator.currentToast {
                MilestoneToastView(event: event) {
                    cancelAndAdvance()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 12)
                .onAppear {
                    scheduleDismiss(for: event)
                }
                .onChange(of: event) { _, newEvent in
                    scheduleDismiss(for: newEvent)
                }
            }
            Spacer()
        }
        .allowsHitTesting(coordinator.currentToast != nil)
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentToast)
    }

    private func scheduleDismiss(for event: CelebrationEvent) {
        dismissTask?.cancel()
        let duration = toastDuration(for: event)
        let remaining = max(0.0, 8.0 - consumedSeconds)
        let effective = min(duration, remaining)

        guard effective > 0 else {
            // Spec: 8-second total cap. Excess toasts are absorbed (seenKey already saved).
            coordinator.dismissCurrent()
            return
        }

        consumedSeconds += effective
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(effective * 1_000_000_000))
            guard !Task.isCancelled else { return }
            coordinator.dismissCurrent()
            if coordinator.currentToast == nil {
                consumedSeconds = 0
            }
        }
    }

    private func cancelAndAdvance() {
        dismissTask?.cancel()
        coordinator.dismissCurrent()
        if coordinator.currentToast == nil {
            consumedSeconds = 0
        }
    }

    private func toastDuration(for event: CelebrationEvent) -> Double {
        switch event {
        case .firstPerfect: return 4.0
        case .streakMilestone: return 3.5
        case .levelCountMilestone: return 3.0
        default: return 3.0
        }
    }
}
