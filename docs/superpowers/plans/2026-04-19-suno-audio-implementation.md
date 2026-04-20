# Suno Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate 10 audio assets in Suno (5 BGM + 5 musical SFX), master them, and wire them into PixelColoringGame with an `@Observable` audio service.

**Architecture:** Assets are produced externally (Suno + Audacity) and bundled in `Resources/Audio/`. A Swift `AudioPlayerService` (`@Observable`, `@MainActor`) is injected through `@Environment` at the `AppView` level — the same pattern as `AppLocalization` and `RewardedAdService`. BGM uses a single looped `AVAudioPlayer` that swaps sources on scene change; SFX use a small pool of prepared `AVAudioPlayer` instances for instant playback. Audio is behind a protocol so view integrations can be tested with a recording fake.

**Tech Stack:** Suno (generation), Audacity + `afconvert` (mastering), Swift 6 / SwiftUI / AVFoundation, XCTest (unit tests).

**Spec reference:** `docs/superpowers/specs/2026-04-19-suno-audio-generation-design.md`

---

## File Structure

### Create

- `PixelColoringGame/Resources/Audio/BGM/b{1..5}_*.m4a` — BGM files (see spec §6)
- `PixelColoringGame/Resources/Audio/SFX/s{1..5}_*.wav` — SFX files (see spec §6)
- `PixelColoringGame/Core/Audio/AudioAsset.swift` — enum of all clips + file name mapping
- `PixelColoringGame/Core/Audio/ChapterBGMResolver.swift` — `chapterID → .bgmGameplayWarm | .bgmGameplayCool`
- `PixelColoringGame/Core/Audio/AudioPlayer.swift` — protocol + `RecordingAudioPlayer` fake
- `PixelColoringGame/Core/Audio/AudioPlayerService.swift` — `@Observable` AVFoundation impl
- `PixelColoringGame/Core/Audio/AudioSettings.swift` — mute toggle persisted in `UserDefaults`
- `PixelColoringGameTests/AudioAssetTests.swift`
- `PixelColoringGameTests/ChapterBGMResolverTests.swift`
- `PixelColoringGameTests/AudioSettingsTests.swift`

### Modify

- `PixelColoringGame/App/AppView.swift` — instantiate service, inject via environment, trigger Home/Journey BGM, handle scene phase
- `PixelColoringGame/Features/Game/GameView.swift` — switch to Warm/Cool BGM based on chapter
- `PixelColoringGame/Features/Completion/CompletionView.swift` — play S1/S2/S3 SFX
- `PixelColoringGame/Features/Collection/CollectionBookView.swift` — play B4 BGM
- Daily/Event flow entry point (`DailyExperience.swift` call site in `AppView.swift`) — play B5 + S4/S5

---

## Testing Notes

- `AudioAsset`, `ChapterBGMResolver`, `AudioSettings`: pure logic, fully unit-tested.
- `AudioPlayerService` (AVFoundation): can't unit-test real playback. Covered by the protocol + fake, plus manual simulator verification per integration task.
- Integration in views: verified by calls going through the fake recorder in tests, then manual simulator run-through as a final check.

---

## Phase A — Asset Generation (manual)

> Phase A is a manual workflow the human executes in Suno and Audacity. Each task is a checklist, not TDD. Check off items as you produce the files.

### Task A1: Generate BGM ×5 in Suno

**Files produced (intermediate, in `~/Downloads/suno_raw/`):**
- `b1_home_raw.wav` (or .mp3)
- `b2_gameplay_warm_raw.wav`
- `b3_gameplay_cool_raw.wav`
- `b4_collection_raw.wav`
- `b5_event_raw.wav`

For each clip B1–B5:

- [ ] **Step 1:** Open Suno, switch to **Custom Mode**.
- [ ] **Step 2:** Paste the Style prompt from spec §4 (the fenced code block for that clip).
- [ ] **Step 3:** Paste the Lyrics tag (e.g. `[Instrumental]`) into the Lyrics field.
- [ ] **Step 4:** Generate. Generate a second variant from the same prompt (Suno outputs two per click).
- [ ] **Step 5:** Listen to both. Pick the one that best matches the "Mood" column in spec §3.1.
- [ ] **Step 6:** If neither works, regenerate once more. If still off, relax the BPM hint (it's the most commonly ignored) and regenerate. Give up after 3 attempts and either accept the best take or flag the prompt for revision.
- [ ] **Step 7:** Download the chosen take. Prefer **WAV** if your plan allows; otherwise MP3 320 kbps.
- [ ] **Step 8:** Save into `~/Downloads/suno_raw/<filename>_raw.<ext>`.
- [ ] **Step 9:** When all 5 BGM files are saved, move to Task A2.

### Task A2: Generate SFX stingers ×5 in Suno

**Files produced (intermediate):**
- `s1_level_complete_raw.wav` through `s5_event_complete_raw.wav`

For each stinger S1–S5:

- [ ] **Step 1:** Same Custom Mode workflow as A1 — paste Style + Lyrics from spec §4 for that clip.
- [ ] **Step 2:** Generate 2 variants; listen for the first few seconds only (that's the stinger region).
- [ ] **Step 3:** Pick the take whose **opening** matches the stinger intent. If the intro drifts into a song before hitting the fanfare, regenerate.
- [ ] **Step 4:** Download and save to `~/Downloads/suno_raw/`.

### Task A3: Master BGM (trim + loop) in Audacity

**Files produced:** WAV intermediates in `~/Downloads/suno_mastered/`.

For each BGM file:

- [ ] **Step 1:** Open `~/Downloads/suno_raw/bN_*_raw.*` in Audacity.
- [ ] **Step 2:** Identify a clean 4–8 bar loop region. Zoom in on waveform, find a downbeat after the intro has settled.
- [ ] **Step 3:** Select the region (Shift+click end point). Aim for 30–60 s of usable loop content.
- [ ] **Step 4:** Trim outside the selection: `Edit → Remove Special → Trim Audio`.
- [ ] **Step 5:** Add a 50 ms crossfade between the end and beginning so the loop is seamless: copy last 50 ms, paste at the very start, use `Effect → Crossfade Clips`. (If Audacity's crossfade sounds awkward, use a short fade-in/fade-out around the loop seam instead.)
- [ ] **Step 6:** Normalize: `Effect → Normalize → Peak amplitude –1.0 dB`.
- [ ] **Step 7:** Export: `File → Export → Export as WAV` → 16-bit PCM, 44.1 kHz → `~/Downloads/suno_mastered/bN_<name>.wav`.
- [ ] **Step 8:** Play the exported file twice back-to-back to confirm the loop point isn't audible.

### Task A4: Master SFX (trim + fade) and convert

**Files produced:** Final WAV/M4A in `~/Downloads/suno_final/`.

#### A4a: SFX (WAV)

For each SFX file:

- [ ] **Step 1:** Open `~/Downloads/suno_raw/sN_*_raw.*` in Audacity.
- [ ] **Step 2:** Trim to target length per spec §3.2 (e.g. 3–5 s for S1). Keep only the stinger portion.
- [ ] **Step 3:** Apply a 20–50 ms fade-out at the end: `Effect → Fade Out` (with the last 50 ms selected).
- [ ] **Step 4:** Normalize to **–3.0 dB peak** (per spec §7 — SFX sits slightly below BGM so stingers don't startle the player).
- [ ] **Step 5:** Export: `File → Export → Export as WAV` → 16-bit PCM, 44.1 kHz, **mono** if the source is mono-ish, otherwise stereo → `~/Downloads/suno_final/sN_<name>.wav`.

#### A4b: BGM (convert WAV → M4A/AAC)

Run from `~/Downloads/`:

- [ ] **Step 1:** Ensure `afconvert` is available (ships with macOS, `which afconvert`).
- [ ] **Step 2:** Convert each BGM file:

```bash
for f in suno_mastered/b*.wav; do
  out="suno_final/$(basename "${f%.wav}.m4a")"
  afconvert -f m4af -d aac@128000 -s 3 "$f" "$out"
done
```

- [ ] **Step 3:** Verify file sizes: 30–60 s of M4A at 128 kbps should be ~500–900 KB each. If any is >2 MB something went wrong with the encoder — re-run that file.

### Task A5: Import audio into the Xcode project

- [ ] **Step 1:** Create the folder structure:

```bash
mkdir -p PixelColoringGame/Resources/Audio/BGM
mkdir -p PixelColoringGame/Resources/Audio/SFX
```

- [ ] **Step 2:** Copy mastered files into place (filenames must match spec §6 exactly):

```bash
cp ~/Downloads/suno_final/b*.m4a PixelColoringGame/Resources/Audio/BGM/
cp ~/Downloads/suno_final/s*.wav PixelColoringGame/Resources/Audio/SFX/
```

- [ ] **Step 3:** Open `PixelColoringGame.xcodeproj` in Xcode.
- [ ] **Step 4:** Right-click the `Resources` group → `Add Files to "PixelColoringGame"…` → select the two new `Audio/BGM` and `Audio/SFX` folders. Check **"Create folder references"** (blue folder icon) — this keeps them as a folder bundle so new files auto-include. Ensure **PixelColoringGame** target is ticked.
- [ ] **Step 5:** Build (⌘B). Expect zero errors — assets only.
- [ ] **Step 6:** Commit:

```bash
git add PixelColoringGame/Resources/Audio PixelColoringGame.xcodeproj
git commit -m "chore: add Suno-generated BGM and SFX assets"
```

---

## Phase B — Audio Service (TDD)

### Task B1: `AudioAsset` enum and file-name mapping

**Files:**
- Create: `PixelColoringGame/Core/Audio/AudioAsset.swift`
- Test: `PixelColoringGameTests/AudioAssetTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PixelColoringGameTests/AudioAssetTests.swift
import XCTest
@testable import PixelColoringGame

final class AudioAssetTests: XCTestCase {
    func test_bgm_resourceNames_matchSpec() {
        XCTAssertEqual(AudioAsset.bgmHome.resourceName, "b1_home")
        XCTAssertEqual(AudioAsset.bgmHome.fileExtension, "m4a")

        XCTAssertEqual(AudioAsset.bgmGameplayWarm.resourceName, "b2_gameplay_warm")
        XCTAssertEqual(AudioAsset.bgmGameplayCool.resourceName, "b3_gameplay_cool")
        XCTAssertEqual(AudioAsset.bgmCollection.resourceName, "b4_collection")
        XCTAssertEqual(AudioAsset.bgmEvent.resourceName, "b5_event")
    }

    func test_sfx_resourceNames_matchSpec() {
        XCTAssertEqual(AudioAsset.sfxLevelComplete.resourceName, "s1_level_complete")
        XCTAssertEqual(AudioAsset.sfxLevelComplete.fileExtension, "wav")
        XCTAssertEqual(AudioAsset.sfxBadgeEarned.resourceName, "s2_badge_earned")
        XCTAssertEqual(AudioAsset.sfxChapterClear.resourceName, "s3_chapter_clear")
        XCTAssertEqual(AudioAsset.sfxDailyStreak.resourceName, "s4_daily_streak")
        XCTAssertEqual(AudioAsset.sfxEventComplete.resourceName, "s5_event_complete")
    }

    func test_isBGM_discriminatesBGMvsSFX() {
        XCTAssertTrue(AudioAsset.bgmHome.isBGM)
        XCTAssertFalse(AudioAsset.sfxLevelComplete.isBGM)
    }

    func test_bundleSubdirectory_matchesBlueFolderLayout() {
        XCTAssertEqual(AudioAsset.bgmHome.bundleSubdirectory, "Audio/BGM")
        XCTAssertEqual(AudioAsset.sfxLevelComplete.bundleSubdirectory, "Audio/SFX")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme PixelColoringGame -only-testing:PixelColoringGameTests/AudioAssetTests -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL — `AudioAsset` not defined.

- [ ] **Step 3: Write the enum**

```swift
// PixelColoringGame/Core/Audio/AudioAsset.swift
import Foundation

enum AudioAsset: CaseIterable, Sendable {
    case bgmHome
    case bgmGameplayWarm
    case bgmGameplayCool
    case bgmCollection
    case bgmEvent

    case sfxLevelComplete
    case sfxBadgeEarned
    case sfxChapterClear
    case sfxDailyStreak
    case sfxEventComplete

    var resourceName: String {
        switch self {
        case .bgmHome: return "b1_home"
        case .bgmGameplayWarm: return "b2_gameplay_warm"
        case .bgmGameplayCool: return "b3_gameplay_cool"
        case .bgmCollection: return "b4_collection"
        case .bgmEvent: return "b5_event"
        case .sfxLevelComplete: return "s1_level_complete"
        case .sfxBadgeEarned: return "s2_badge_earned"
        case .sfxChapterClear: return "s3_chapter_clear"
        case .sfxDailyStreak: return "s4_daily_streak"
        case .sfxEventComplete: return "s5_event_complete"
        }
    }

    var fileExtension: String { isBGM ? "m4a" : "wav" }

    var isBGM: Bool {
        switch self {
        case .bgmHome, .bgmGameplayWarm, .bgmGameplayCool, .bgmCollection, .bgmEvent:
            return true
        case .sfxLevelComplete, .sfxBadgeEarned, .sfxChapterClear, .sfxDailyStreak, .sfxEventComplete:
            return false
        }
    }

    /// Directory path inside the app bundle. The Xcode project registers
    /// `Audio/` as a blue folder reference, so `BGM/` and `SFX/` are preserved
    /// at runtime and must be passed to `Bundle.main.url(forResource:...)`.
    var bundleSubdirectory: String { isBGM ? "Audio/BGM" : "Audio/SFX" }
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PixelColoringGame/Core/Audio/AudioAsset.swift PixelColoringGameTests/AudioAssetTests.swift
git commit -m "feat(audio): add AudioAsset enum with resource name mapping"
```

### Task B2: `ChapterBGMResolver`

**Files:**
- Create: `PixelColoringGame/Core/Audio/ChapterBGMResolver.swift`
- Test: `PixelColoringGameTests/ChapterBGMResolverTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PixelColoringGameTests/ChapterBGMResolverTests.swift
import XCTest
@testable import PixelColoringGame

final class ChapterBGMResolverTests: XCTestCase {
    func test_warmChapters_resolveToWarmBGM() {
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "berry-meadow"), .bgmGameplayWarm)
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "bakery-path"), .bgmGameplayWarm)
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "petal-pond"), .bgmGameplayWarm)
    }

    func test_coolChapters_resolveToCoolBGM() {
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "tide-garden"), .bgmGameplayCool)
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "moonlit-shore"), .bgmGameplayCool)
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "starlit-garden"), .bgmGameplayCool)
    }

    func test_unknownChapter_fallsBackToWarm() {
        XCTAssertEqual(ChapterBGMResolver.bgm(for: "unknown-chapter"), .bgmGameplayWarm)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `ChapterBGMResolver` not defined.

- [ ] **Step 3: Write the resolver**

```swift
// PixelColoringGame/Core/Audio/ChapterBGMResolver.swift
import Foundation

enum ChapterBGMResolver {
    private static let coolChapters: Set<String> = [
        "tide-garden",
        "moonlit-shore",
        "starlit-garden",
    ]

    static func bgm(for chapterID: String) -> AudioAsset {
        coolChapters.contains(chapterID) ? .bgmGameplayCool : .bgmGameplayWarm
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add PixelColoringGame/Core/Audio/ChapterBGMResolver.swift PixelColoringGameTests/ChapterBGMResolverTests.swift
git commit -m "feat(audio): resolve chapter ID to Warm/Cool gameplay BGM"
```

### Task B3: `AudioPlayer` protocol + recording fake

**Files:**
- Create: `PixelColoringGame/Core/Audio/AudioPlayer.swift`

This task has no behavior of its own — the protocol is exercised via the fake in later tests. We commit it to unblock B4 and the integration tasks.

- [ ] **Step 1: Write the protocol and fake**

```swift
// PixelColoringGame/Core/Audio/AudioPlayer.swift
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
```

- [ ] **Step 2: Build the test target to verify it compiles**

Run: `xcodebuild build-for-testing -scheme PixelColoringGame -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add PixelColoringGame/Core/Audio/AudioPlayer.swift
git commit -m "feat(audio): introduce AudioPlayer protocol + recording fake"
```

### Task B4: `AudioSettings` (mute persistence)

**Files:**
- Create: `PixelColoringGame/Core/Audio/AudioSettings.swift`
- Test: `PixelColoringGameTests/AudioSettingsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PixelColoringGameTests/AudioSettingsTests.swift
import XCTest
@testable import PixelColoringGame

@MainActor
final class AudioSettingsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "AudioSettingsTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().description)
    }

    func test_defaultIsUnmuted() {
        let settings = AudioSettings(defaults: defaults)
        XCTAssertFalse(settings.isMuted)
    }

    func test_settingMuted_persistsAcrossInstances() {
        let a = AudioSettings(defaults: defaults)
        a.isMuted = true

        let b = AudioSettings(defaults: defaults)
        XCTAssertTrue(b.isMuted)
    }

    func test_toggleFlipsValue() {
        let settings = AudioSettings(defaults: defaults)
        settings.toggleMuted()
        XCTAssertTrue(settings.isMuted)
        settings.toggleMuted()
        XCTAssertFalse(settings.isMuted)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `AudioSettings` not defined.

- [ ] **Step 3: Write the settings class**

```swift
// PixelColoringGame/Core/Audio/AudioSettings.swift
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
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add PixelColoringGame/Core/Audio/AudioSettings.swift PixelColoringGameTests/AudioSettingsTests.swift
git commit -m "feat(audio): persist mute toggle via UserDefaults"
```

### Task B5: `AudioPlayerService` (AVFoundation impl)

**Files:**
- Create: `PixelColoringGame/Core/Audio/AudioPlayerService.swift`

Cannot unit-test AVAudioPlayer without real audio output. Verified manually in the simulator during Phase C. This task delivers the concrete production implementation behind the protocol from B3.

- [ ] **Step 1: Write the service**

```swift
// PixelColoringGame/Core/Audio/AudioPlayerService.swift
import AVFoundation
import Observation

@MainActor
@Observable
final class AudioPlayerService: AudioPlayer {
    private(set) var currentBGM: AudioAsset?

    private var bgmPlayer: AVAudioPlayer?
    private var sfxPlayers: [AudioAsset: AVAudioPlayer] = [:]
    private let settings: AudioSettings

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
            AppLogger.audio.error("Missing BGM asset: \(asset.resourceName)")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = settings.isMuted ? 0 : 1
            player.prepareToPlay()
            player.play()
            bgmPlayer = player
            currentBGM = asset
        } catch {
            AppLogger.audio.error("BGM init failed: \(error)")
        }
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
        currentBGM = nil
    }

    func playSFX(_ asset: AudioAsset) {
        guard !asset.isBGM else { return }
        guard !settings.isMuted else { return }
        guard let player = sfxPlayers[asset] else {
            AppLogger.audio.error("SFX not preloaded: \(asset.resourceName)")
            return
        }
        player.currentTime = 0
        player.play()
    }

    func setMuted(_ muted: Bool) {
        settings.isMuted = muted
        bgmPlayer?.volume = muted ? 0 : 1
    }

    // MARK: Setup

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            AppLogger.audio.error("Audio session config failed: \(error)")
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
                AppLogger.audio.error("SFX preload failed for \(asset.resourceName): \(error)")
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
            MainActor.assumeIsolated { self?.handleInterruption(note) }
        }
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
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
```

- [ ] **Step 2: Add `AppLogger.audio` category**

Find the existing `AppLogger` file:

```bash
grep -n "Logger(subsystem" PixelColoringGame/Core/AppLogger.swift
```

Add a new category next to the existing ones (show the file then append):

```swift
// Inside AppLogger — add among existing Logger static lets
static let audio = Logger(subsystem: subsystem, category: "audio")
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -scheme PixelColoringGame -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add PixelColoringGame/Core/Audio/AudioPlayerService.swift PixelColoringGame/Core/AppLogger.swift
git commit -m "feat(audio): AVFoundation-backed AudioPlayerService with interruption handling"
```

---

## Phase C — Integration

### Task C1: Inject service at `AppView` and start Home BGM

**Files:**
- Modify: `PixelColoringGame/App/AppView.swift`
- Modify: `PixelColoringGame/App/PixelColoringGameApp.swift` (or wherever the root scene is)

- [ ] **Step 1: Locate the root scene file**

```bash
grep -l "@main" PixelColoringGame/App/
```

- [ ] **Step 2: Create `AudioSettings` and `AudioPlayerService` instances at `AppView` level**

In `AppView.swift`, add next to the existing `@State private var rewardedAdService = RewardedAdService()`:

```swift
@State private var audioSettings: AudioSettings
@State private var audioService: AudioPlayerService

init(/* existing parameters */) {
    // existing init body first
    let settings = AudioSettings()
    self._audioSettings = State(initialValue: settings)
    self._audioService = State(initialValue: AudioPlayerService(settings: settings))
}
```

The important part: one `AudioSettings` instance is shared between the service and the environment, so the mute toggle (which writes through `AudioSettings`) and the service (which reads `AudioSettings.isMuted`) stay in sync.

Inject the **concrete** types into the view tree (SwiftUI `@Environment(T.self)` keys on the concrete `@Observable` type, not on a protocol):

```swift
.environment(audioService)
.environment(audioSettings)
```

Subsequent tasks read them back with `@Environment(AudioPlayerService.self)` and `@Environment(AudioSettings.self)`.

- [ ] **Step 3: Trigger Home BGM when the Journey home screen is visible**

In `AppView.swift`, find the root `NavigationStack` and add:

```swift
.onAppear { audioService.playBGM(.bgmHome) }
.onChange(of: path) { _, newPath in
    // When the user returns to the journey home (path empty), resume Home BGM
    if newPath.isEmpty { audioService.playBGM(.bgmHome) }
}
.onChange(of: scenePhase) { _, phase in
    switch phase {
    case .background: audioService.stopBGM()
    case .active:
        if path.isEmpty { audioService.playBGM(.bgmHome) }
    default: break
    }
}
```

- [ ] **Step 4: Build and run in simulator**

Run: `xcodebuild build -scheme PixelColoringGame -destination 'platform=iOS Simulator,name=iPhone 15'`. Launch in simulator, confirm B1 plays on the home screen and stops when the app backgrounds.

- [ ] **Step 5: Commit**

```bash
git add PixelColoringGame/App/AppView.swift
git commit -m "feat(audio): play Home BGM on journey home, pause on background"
```

### Task C2: Gameplay BGM switches by chapter

**Files:**
- Modify: `PixelColoringGame/Features/Game/GameView.swift`

- [ ] **Step 1: Locate the chapter ID on the game route**

Search for how `GameView` already receives its level/chapter info:

```bash
grep -n "chapterID\|chapter_id\|chapter:" PixelColoringGame/Features/Game/GameView.swift
```

If the chapter ID isn't already in scope, derive it from the current `LevelManifest`/`JourneyRepository` in the same way neighboring code does.

- [ ] **Step 2: Inject the audio service**

At the top of `GameView`:

```swift
@Environment(AudioPlayerService.self) private var audio
```

- [ ] **Step 3: Play the chapter-specific BGM when the view appears**

```swift
.onAppear {
    let asset = ChapterBGMResolver.bgm(for: currentChapterID)
    audio.playBGM(asset)
}
```

If the user can switch chapters without leaving `GameView`, add `.onChange(of: currentChapterID)` with the same body.

- [ ] **Step 4: Simulator verification**

Launch the game, start a Berry Meadow level → expect B2 (Warm). Back out, start a Tide Garden level → expect B3 (Cool).

- [ ] **Step 5: Commit**

```bash
git add PixelColoringGame/Features/Game/GameView.swift
git commit -m "feat(audio): switch gameplay BGM by chapter (Warm/Cool)"
```

### Task C3: Collection and Event/Daily BGM

**Files:**
- Modify: `PixelColoringGame/Features/Collection/CollectionBookView.swift`
- Modify: `PixelColoringGame/Core/DailyExperience.swift` or its `AppView` call site (pick the one that owns the "daily/event active" screen)

- [ ] **Step 1: Collection BGM**

In `CollectionBookView.swift`:

```swift
@Environment(AudioPlayerService.self) private var audio
// …
.onAppear { audio.playBGM(.bgmCollection) }
```

- [ ] **Step 2: Event/Daily BGM**

Find where the Daily/Event game flow starts (not the regular journey flow). In that view's `onAppear`:

```swift
audio.playBGM(.bgmEvent)
```

This replaces B2/B3 for the duration of Daily/Event puzzles, so don't call it on every level — only when entering the Daily/Event context.

- [ ] **Step 3: Simulator verification**

Open the Collection Book → expect B4. Start a Daily puzzle → expect B5. Exit back to home → expect B1 resumes.

- [ ] **Step 4: Commit**

```bash
git add PixelColoringGame/Features/Collection/CollectionBookView.swift PixelColoringGame/Core/DailyExperience.swift
git commit -m "feat(audio): Collection and Event/Daily BGM triggers"
```

### Task C4: Level-completion SFX (S1 + S2)

**Files:**
- Modify: `PixelColoringGame/Features/Completion/CompletionView.swift`

- [ ] **Step 1: Play Level Complete on appear**

```swift
@Environment(AudioPlayerService.self) private var audio
// …
.onAppear {
    audio.playSFX(.sfxLevelComplete)
    if summary.newBadgeEarned { // use the actual flag from LevelCompletionSummary
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            audio.playSFX(.sfxBadgeEarned)
        }
    }
}
```

Confirm the exact badge-earned flag name by checking `LevelCompletionSummary.swift`:

```bash
grep -n "badge\|Badge" PixelColoringGame/Models/LevelCompletionSummary.swift
```

If the flag is named differently (e.g. `earnedBadge`), use that instead.

- [ ] **Step 2: Simulator verification**

Complete a level that doesn't earn a badge → only S1 plays. Complete a level that earns a badge → S1 then S2 ~0.6 s later.

- [ ] **Step 3: Commit**

```bash
git add PixelColoringGame/Features/Completion/CompletionView.swift
git commit -m "feat(audio): play Level Complete + Badge SFX on completion"
```

### Task C5: Chapter Clear, Daily Streak, Event Complete SFX

**Files:**
- Modify: `PixelColoringGame/Features/Completion/CompletionView.swift` (chapter clear)
- Modify: daily/event completion trigger point (same file that showed Daily/Event BGM entry in C3)

- [ ] **Step 1: Detect chapter-clear state**

In `CompletionView`, add a check after S1/S2:

```swift
if summary.isChapterClear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        audio.playSFX(.sfxChapterClear)
    }
}
```

If `LevelCompletionSummary` has no `isChapterClear` flag, add one and populate it from the call site:

```bash
grep -n "LevelCompletionSummary" PixelColoringGame --include="*.swift" -r
```

Add the flag:

```swift
// In LevelCompletionSummary
let isChapterClear: Bool
```

Compute it at the completion-summary build site by asking `JourneyRepository` whether all levels in the just-finished chapter are now complete.

- [ ] **Step 2: Daily Streak SFX**

At the point where the daily-challenge completion screen (or toast) first appears:

```swift
audio.playSFX(.sfxDailyStreak)
```

- [ ] **Step 3: Event Complete SFX**

At the point where an event is fully completed (not individual event-level, but the full event):

```swift
audio.playSFX(.sfxEventComplete)
```

- [ ] **Step 4: Simulator verification**

Complete the last level of a chapter → S1, S2 (if badge), then S3. Complete a daily challenge → S4. Finish an event → S5.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(audio): Chapter Clear / Daily / Event stinger triggers"
```

### Task C6: Mute toggle in Settings

**Files:**
- Modify: the settings / profile sheet (find it)

- [ ] **Step 1: Find the settings sheet**

```bash
grep -rn "settings\|Settings" PixelColoringGame/Features --include="*.swift" | grep -i view
```

If no explicit settings view exists yet, add the toggle to the Profile/Home screen's menu overlay (check `JourneyHomeView.swift` for a gear/menu button).

- [ ] **Step 2: Add the toggle**

```swift
@Environment(AudioSettings.self) private var audioSettings
@Environment(AudioPlayerService.self) private var audio

Toggle("settings.audio.mute", isOn: Binding(
    get: { audioSettings.isMuted },
    set: { audio.setMuted($0) }
))
```

- [ ] **Step 3: Add the localization key**

Add `settings.audio.mute` to `PixelColoringGame/Resources/Localizable.xcstrings` for all 7 supported languages (follow existing keys' style).

- [ ] **Step 4: Simulator verification**

Toggle mute ON → BGM silences, SFX do not play. Toggle OFF → BGM volume restores. Force-quit and relaunch → mute state persists.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(audio): user-facing mute toggle with persistence"
```

---

## Final Verification

- [ ] Run full test suite: `xcodebuild test -scheme PixelColoringGame -destination 'platform=iOS Simulator,name=iPhone 15'` — all existing tests + the 3 new audio test files pass.
- [ ] Play through: home → Berry Meadow level → complete → back to home → Tide Garden level → complete chapter → Collection Book → Daily → Event. Confirm every BGM/SFX from spec §3 fires at the correct moment.
- [ ] Force an interruption: receive a simulated phone call (Simulator → Features → Trigger Interrupt) → BGM pauses → end call → BGM resumes.
- [ ] Mute toggle round-trip: mute → kill app → relaunch → still muted → unmute.
