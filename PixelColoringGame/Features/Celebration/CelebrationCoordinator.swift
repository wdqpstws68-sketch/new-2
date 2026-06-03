import Foundation
import Observation

@MainActor
@Observable
final class CelebrationCoordinator {
    private(set) var currentFullScreenEvent: CelebrationEvent?
    private(set) var currentToast: CelebrationEvent?

    @ObservationIgnored private var seen: Set<String>
    @ObservationIgnored private var fullScreenQueue: [CelebrationEvent] = []
    @ObservationIgnored private var toastQueue: [CelebrationEvent] = []
    @ObservationIgnored private let persistSeen: (Set<String>) -> Void

    init(initialSeen: Set<String>, persist: @escaping (Set<String>) -> Void) {
        self.seen = initialSeen
        self.persistSeen = persist
    }

    var isCompletionFlowActive: Bool {
        currentFullScreenEvent != nil
            || currentToast != nil
            || !fullScreenQueue.isEmpty
            || !toastQueue.isEmpty
    }

    func handle(trigger: CelebrationTrigger) {
        let events = CelebrationDetector.detect(trigger: trigger, seen: seen)
        enqueue(events)
    }

    func enqueue(_ events: [CelebrationEvent]) {
        let kept = applySupersedes(events: events)
        for ev in kept {
            guard !seen.contains(ev.seenKey) else { continue }
            switch ev.presentationKind {
            case .fullScreen:
                fullScreenQueue.append(ev)
            case .toast:
                toastQueue.append(ev)
            }
        }
        fullScreenQueue.sort { $0.priority > $1.priority }
        toastQueue.sort { $0.priority > $1.priority }
        advance()
    }

    func dismissCurrent() {
        currentFullScreenEvent = nil
        currentToast = nil
        advance()
    }

    private func advance() {
        if currentFullScreenEvent == nil, !fullScreenQueue.isEmpty {
            let next = fullScreenQueue.removeFirst()
            markSeen(next)
            currentFullScreenEvent = next
        }
        if currentToast == nil, !toastQueue.isEmpty {
            let next = toastQueue.removeFirst()
            markSeen(next)
            currentToast = next
        }
    }

    private func markSeen(_ event: CelebrationEvent) {
        seen.insert(event.seenKey)
        persistSeen(seen)
    }

    /// Apply supersedes rules: an event with higher priority absorbs lower-priority events
    /// whose seenKey matches its supersedesPatterns. Absorbed events get their seenKey saved
    /// (they will never fire again — Journey/Monthly complete semantics).
    private func applySupersedes(events: [CelebrationEvent]) -> [CelebrationEvent] {
        let sorted = events.sorted { $0.priority > $1.priority }
        var kept: [CelebrationEvent] = []
        var absorbedKeys: Set<String> = []
        for ev in sorted {
            let isSuperseded = kept.contains { higher in
                higher.supersedesPatterns.contains { pattern in
                    ev.seenKey.celebrationMatches(pattern: pattern)
                }
            }
            if isSuperseded {
                absorbedKeys.insert(ev.seenKey)
            } else {
                kept.append(ev)
            }
        }
        if !absorbedKeys.isEmpty {
            seen.formUnion(absorbedKeys)
            persistSeen(seen)
        }
        return kept
    }
}
