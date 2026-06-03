import Foundation

@MainActor
protocol AudioPlayer: AnyObject {
    var currentBGM: AudioAsset? { get }
    func playBGM(_ asset: AudioAsset)
    func stopBGM()
    /// Pause the current BGM, preserving its playback position (e.g. while a full-screen ad plays).
    func pauseBGM()
    /// Resume BGM paused by pauseBGM().
    func resumeBGM()
    func playSFX(_ asset: AudioAsset)
    /// Plays the UI tap sound. Internally throttled so a continuous paint
    /// stroke (or rapid presses) sounds like a pleasant texture, not noise.
    func playTap()
    func setMuted(_ muted: Bool)
    func setBGMVolume(_ volume: Double)
    func setSFXVolume(_ volume: Double)
}

/// Test double that records calls instead of touching AVFoundation.
@MainActor
final class RecordingAudioPlayer: AudioPlayer {
    enum Call: Equatable {
        case playBGM(AudioAsset)
        case stopBGM
        case pauseBGM
        case resumeBGM
        case playSFX(AudioAsset)
        case playTap
        case setMuted(Bool)
        case setBGMVolume(Double)
        case setSFXVolume(Double)
    }

    private(set) var calls: [Call] = []
    private(set) var currentBGM: AudioAsset?
    private var muted = false

    func playBGM(_ asset: AudioAsset) {
        calls.append(.playBGM(asset))
        currentBGM = asset
    }

    func stopBGM() {
        calls.append(.stopBGM)
        currentBGM = nil
    }

    func pauseBGM() {
        calls.append(.pauseBGM)
    }

    func resumeBGM() {
        calls.append(.resumeBGM)
    }

    func playSFX(_ asset: AudioAsset) {
        calls.append(.playSFX(asset))
    }

    func playTap() {
        calls.append(.playTap)
    }

    func setMuted(_ muted: Bool) {
        calls.append(.setMuted(muted))
        self.muted = muted
    }

    func setBGMVolume(_ volume: Double) {
        calls.append(.setBGMVolume(volume))
    }

    func setSFXVolume(_ volume: Double) {
        calls.append(.setSFXVolume(volume))
    }
}
