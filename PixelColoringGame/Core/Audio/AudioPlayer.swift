import Foundation

@MainActor
protocol AudioPlayer: AnyObject {
    var currentBGM: AudioAsset? { get }
    func playBGM(_ asset: AudioAsset)
    func stopBGM()
    func playSFX(_ asset: AudioAsset)
    func setMuted(_ muted: Bool)
}

/// Test double that records calls instead of touching AVFoundation.
@MainActor
final class RecordingAudioPlayer: AudioPlayer {
    enum Call: Equatable {
        case playBGM(AudioAsset)
        case stopBGM
        case playSFX(AudioAsset)
        case setMuted(Bool)
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

    func playSFX(_ asset: AudioAsset) {
        calls.append(.playSFX(asset))
    }

    func setMuted(_ muted: Bool) {
        calls.append(.setMuted(muted))
        self.muted = muted
    }
}
