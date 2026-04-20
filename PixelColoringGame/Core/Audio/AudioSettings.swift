import Foundation
import Observation

@MainActor
@Observable
final class AudioSettings {
    private let defaults: UserDefaults
    private let mutedKey = "audio.isMuted"

    var isMuted: Bool {
        didSet { defaults.set(isMuted, forKey: mutedKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isMuted = defaults.bool(forKey: mutedKey)
    }

    func toggleMuted() { isMuted.toggle() }
}
