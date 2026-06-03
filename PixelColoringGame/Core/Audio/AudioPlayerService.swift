import AVFoundation
import Observation

@MainActor
@Observable
final class AudioPlayerService: AudioPlayer {
    private(set) var currentBGM: AudioAsset?

    private var bgmPlayer: AVAudioPlayer?
    private var sfxPlayers: [AudioAsset: AVAudioPlayer] = [:]
    private let settings: AudioSettings

    private var lastTapDate = Date.distantPast
    private let tapMinimumInterval: TimeInterval = 0.05

    init(settings: AudioSettings) {
        self.settings = settings
        configureSession()
        observeInterruptions()
        preloadSFX()
    }

    // MARK: AudioPlayer

    func playBGM(_ asset: AudioAsset) {
        guard asset.isBGM else { return }
        if currentBGM == asset, bgmPlayer?.isPlaying == true { return }

        bgmPlayer?.stop()
        guard let url = url(for: asset) else {
            AppLogger.audioBGMMissing(resource: asset.resourceName)
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Float(settings.effectiveBGMVolume)
            player.prepareToPlay()
            player.play()
            bgmPlayer = player
            currentBGM = asset
        } catch {
            AppLogger.audioBGMLoadFailed(resource: asset.resourceName, error: error)
        }
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
        currentBGM = nil
    }

    func pauseBGM() {
        bgmPlayer?.pause()
    }

    func resumeBGM() {
        guard let asset = currentBGM else { return }
        if let player = bgmPlayer {
            if !player.isPlaying { player.play() }
        } else {
            playBGM(asset)
        }
    }

    func playSFX(_ asset: AudioAsset) {
        guard !asset.isBGM else { return }
        let volume = settings.effectiveSFXVolume
        guard volume > 0 else { return }
        guard let player = sfxPlayers[asset] else {
            AppLogger.audioSFXMissing(resource: asset.resourceName)
            return
        }
        player.volume = Float(volume)
        player.currentTime = 0
        player.play()
    }

    func playTap() {
        let now = Date()
        guard now.timeIntervalSince(lastTapDate) >= tapMinimumInterval else { return }
        lastTapDate = now
        playSFX(.sfxTap)
    }

    func setMuted(_ muted: Bool) {
        settings.isMuted = muted
        bgmPlayer?.volume = Float(settings.effectiveBGMVolume)
    }

    func setBGMVolume(_ volume: Double) {
        settings.bgmVolume = volume
        bgmPlayer?.volume = Float(settings.effectiveBGMVolume)
    }

    func setSFXVolume(_ volume: Double) {
        settings.sfxVolume = volume
    }

    // MARK: Setup

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            AppLogger.audioSessionConfigFailed(error: error)
        }
    }

    private func preloadSFX() {
        for asset in AudioAsset.allCases where !asset.isBGM {
            guard let url = url(for: asset) else { continue }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                sfxPlayers[asset] = player
            } catch {
                AppLogger.audioSFXPreloadFailed(resource: asset.resourceName, error: error)
            }
        }
    }

    private func url(for asset: AudioAsset) -> URL? {
        Bundle.main.url(
            forResource: asset.resourceName,
            withExtension: asset.fileExtension,
            subdirectory: asset.bundleSubdirectory
        )
    }

    // MARK: Interruptions

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated { self?.handleInterruption(rawType: raw) }
        }
    }

    private func handleInterruption(rawType: UInt?) {
        guard let raw = rawType,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            bgmPlayer?.pause()
        case .ended:
            if let asset = currentBGM { playBGM(asset) }
        @unknown default:
            break
        }
    }
}
