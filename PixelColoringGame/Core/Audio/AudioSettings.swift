import Foundation
import Observation

@MainActor
@Observable
final class AudioSettings {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let mutedKey = "audio.isMuted"
    @ObservationIgnored private let bgmVolumeKey = "audio.bgmVolume"
    @ObservationIgnored private let sfxVolumeKey = "audio.sfxVolume"

    static let defaultBGMVolume = 0.7
    static let defaultSFXVolume = 1.0

    /// Master mute. When on, both axes are silenced regardless of their volume.
    var isMuted: Bool {
        didSet { defaults.set(isMuted, forKey: mutedKey) }
    }

    // Backing storage clamps in the setter without re-entering it (reassigning a
    // property inside its own `didSet` recurses under @Observable).
    private var storedBGMVolume: Double
    private var storedSFXVolume: Double

    /// Background-music volume (0…1), independent of `sfxVolume`.
    var bgmVolume: Double {
        get { storedBGMVolume }
        set {
            storedBGMVolume = newValue.clampedToUnitInterval()
            defaults.set(storedBGMVolume, forKey: bgmVolumeKey)
        }
    }

    /// Sound-effects volume (0…1) — taps, completions, etc.
    var sfxVolume: Double {
        get { storedSFXVolume }
        set {
            storedSFXVolume = newValue.clampedToUnitInterval()
            defaults.set(storedSFXVolume, forKey: sfxVolumeKey)
        }
    }

    /// Volume actually applied to BGM playback (folds in the master mute).
    var effectiveBGMVolume: Double { isMuted ? 0 : bgmVolume }

    /// Volume actually applied to sound effects (folds in the master mute).
    var effectiveSFXVolume: Double { isMuted ? 0 : sfxVolume }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isMuted = defaults.bool(forKey: mutedKey)
        self.storedBGMVolume = defaults.object(forKey: bgmVolumeKey) == nil
            ? Self.defaultBGMVolume
            : defaults.double(forKey: bgmVolumeKey).clampedToUnitInterval()
        self.storedSFXVolume = defaults.object(forKey: sfxVolumeKey) == nil
            ? Self.defaultSFXVolume
            : defaults.double(forKey: sfxVolumeKey).clampedToUnitInterval()
    }

    func toggleMuted() { isMuted.toggle() }
}

private extension Double {
    func clampedToUnitInterval() -> Double {
        Swift.min(1, Swift.max(0, self))
    }
}
