# 報酬型広告によるライフ回復（AdMob 再導入 / v1.1）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ライフ切れ時に報酬型（rewarded）動画広告を1本見ると回復ライフが +1 される仕組みを、1日5回の上限つきで再導入する（まずはテストID）。

**Architecture:** `d532d21` で削除された `RewardedAdService` を復元し、既存の未使用フック `PlayerProfileStore.grantRewardedLife()`（+1・上限3）と `LifeDepletedSheet` に再接続する。新規の1日上限ロジック `RewardedAdQuota`（UserDefaults 永続）を追加。広告 SDK 依存部はすべて `#if canImport(GoogleMobileAds)` でガードし、SDK 未導入でもビルド・動作（広告非表示）する。SDK パッケージと Info.plist/Privacy 設定は最後に追加して機能を有効化する。

**Tech Stack:** Swift 6 / iOS 17+ / SwiftUI / SwiftData / Observation（`@Observable`）/ Google Mobile Ads SDK v12（SPM）/ User Messaging Platform v3（SPM）/ XCTest。

---

## 実行メモ（全タスク共通）

- **ビルド/テストはサンドボックス無効で実行**（FS/DerivedData アクセスが必要）。`-list` は使わない（この環境ではハングする）。
- ビルド:
  ```
  xcodebuild -project PixelColoringGame.xcodeproj -scheme PixelColoringGame \
    -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug \
    -derivedDataPath build/DerivedData2 CODE_SIGNING_ALLOWED=NO build
  ```
- テスト: 上記の末尾 `build` を `test` に置換。特定クラスのみは `-only-testing:PixelColoringGameTests/<ClassName>` を付与。
- **新規 .swift ファイルは作らない**：本プロジェクトは file-system-synchronized group ではなく明示的 `PBXFileReference` を使うため、新規ファイルは `project.pbxproj` への手編集が必要になり壊れやすい。よって新しい型・テストは **既存のコンパイル対象ファイルに追記**する（[[ios-build-test-cli]] 参照）。
- **`@Observable` の `didSet` 自己代入は無限再帰でクラッシュ**する。クランプ等はメソッド内で行い、`didSet { x = ... }` は書かない（[[audio-system]] 参照）。
- Task 1〜4 は SDK 不要・オフラインでビルド/テストが通る。Task 5 で初めて SPM 解決のためネットワークが必要。
- **各タスク末尾でビルド（必要ならテスト）が緑になることを必ず確認してからコミットする。**

## ファイル構成（どこに何を置くか）

| ファイル | 変更 | 責務 |
|---|---|---|
| `PixelColoringGame/Core/PlayerProfileStore.swift` | 追記 | 新規 `RewardedAdQuota`（@Observable, UserDefaults 永続, 1日上限ロジック）を末尾に追加。既存 `grantRewardedLife()` はそのまま流用。 |
| `PixelColoringGameTests/AudioSettingsTests.swift` | 追記 | 新規 `RewardedAdQuotaTests`（UserDefaults 注入テストの既存流儀に倣う）を追加。 |
| `PixelColoringGameTests/JourneyProgressSnapshotTests.swift` | 追記 | 新規 `GrantRewardedLifeTests`（枯渇→+1→上限クランプ）を追加。 |
| `PixelColoringGame/App/AppView.swift` | 改修 | `RewardedAdService`（クラス＋デリゲート拡張）を復元。`@State` で `rewardedAdService`/`rewardedAdQuota` を保持。`LifeDepletedSheet` を広告対応に復元。`.lifeDepleted` ケースと `handleRewardedLifeRequest()` を復元（現行シグネチャ準拠）。`todayQuotaKey` 算出を追加。ガード付き import を追加。 |
| `PixelColoringGame/Resources/Localizable.xcstrings` | 追記 | 新規キー `life.depleted.adLimitReached`（en/ja）。`watchAd`/`loadingAd`/`retryAd` は既存流用。 |
| `PixelColoringGame.xcodeproj/project.pbxproj` | 改修 | GoogleMobileAds / UserMessagingPlatform の SPM パッケージ参照を復元。 |
| `PixelColoringGame/Info.plist` | 追記 | `GADApplicationIdentifier`（テスト）, `SKAdNetworkItems`（47件）, `NSUserTrackingUsageDescription`。 |
| `PixelColoringGame/PrivacyInfo.xcprivacy` | 追記 | AdMob 向けトラッキング/収集データ申告。 |

---

### Task 1: RewardedAdQuota（1日上限ロジック・純ロジック / TDD）

**Files:**
- Modify: `PixelColoringGame/Core/PlayerProfileStore.swift`（末尾に型追加）
- Test: `PixelColoringGameTests/AudioSettingsTests.swift`（末尾に新クラス追加）

- [ ] **Step 1: 失敗するテストを書く**

`PixelColoringGameTests/AudioSettingsTests.swift` の末尾（最後の `}` の後）に以下を追加:

```swift

@MainActor
final class RewardedAdQuotaTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "RewardedAdQuotaTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_freshQuota_allowsUpToDailyLimit() {
        let quota = RewardedAdQuota(defaults: defaults)
        XCTAssertEqual(quota.remaining(on: "2026-06-01"), RewardedAdQuota.dailyLimit)
        XCTAssertTrue(quota.canWatch(on: "2026-06-01"))
    }

    func test_recordWatch_decrementsRemaining() {
        let quota = RewardedAdQuota(defaults: defaults)
        quota.recordWatch(on: "2026-06-01")
        XCTAssertEqual(quota.remaining(on: "2026-06-01"), RewardedAdQuota.dailyLimit - 1)
    }

    func test_reachingDailyLimit_blocksFurtherWatches() {
        let quota = RewardedAdQuota(defaults: defaults)
        for _ in 0..<RewardedAdQuota.dailyLimit {
            quota.recordWatch(on: "2026-06-01")
        }
        XCTAssertEqual(quota.remaining(on: "2026-06-01"), 0)
        XCTAssertFalse(quota.canWatch(on: "2026-06-01"))
    }

    func test_newDay_resetsQuota() {
        let quota = RewardedAdQuota(defaults: defaults)
        for _ in 0..<RewardedAdQuota.dailyLimit {
            quota.recordWatch(on: "2026-06-01")
        }
        XCTAssertFalse(quota.canWatch(on: "2026-06-01"))
        XCTAssertTrue(quota.canWatch(on: "2026-06-02"))
        XCTAssertEqual(quota.remaining(on: "2026-06-02"), RewardedAdQuota.dailyLimit)
    }

    func test_countPersistsAcrossInstances_sameDay() {
        let a = RewardedAdQuota(defaults: defaults)
        a.recordWatch(on: "2026-06-01")
        a.recordWatch(on: "2026-06-01")

        let b = RewardedAdQuota(defaults: defaults)
        XCTAssertEqual(b.remaining(on: "2026-06-01"), RewardedAdQuota.dailyLimit - 2)
    }
}
```

- [ ] **Step 2: テストが失敗（コンパイル不可）することを確認**

Run: `xcodebuild ... test -only-testing:PixelColoringGameTests/RewardedAdQuotaTests`（先頭の実行メモのビルド設定を使用）
Expected: FAIL — `Cannot find 'RewardedAdQuota' in scope`。

- [ ] **Step 3: 最小実装を追加**

`PixelColoringGame/Core/PlayerProfileStore.swift` の末尾（ファイル最後の `}` の後）に追加:

```swift

/// 報酬型広告でライフ回復できる「1日あたりの回数上限」を管理する。
/// 日付の境界判定は呼び出し側（AppView）が `appCalendar` で算出した日キー文字列で行うため、
/// この型自体は時計・カレンダーに依存せずテスト可能。永続化は `AudioSettings` と同じ UserDefaults 流儀。
@MainActor
@Observable
final class RewardedAdQuota {
    static let dailyLimit = 5

    private static let countDefaultsKey = "rewardedAdQuota.count"
    private static let dayDefaultsKey = "rewardedAdQuota.dayKey"

    private let defaults: UserDefaults
    private(set) var watchedCount: Int
    private(set) var recordedDayKey: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.watchedCount = defaults.integer(forKey: Self.countDefaultsKey)
        self.recordedDayKey = defaults.string(forKey: Self.dayDefaultsKey) ?? ""
    }

    func remaining(on dayKey: String) -> Int {
        guard dayKey == recordedDayKey else { return Self.dailyLimit }
        return max(0, Self.dailyLimit - watchedCount)
    }

    func canWatch(on dayKey: String) -> Bool {
        remaining(on: dayKey) > 0
    }

    @discardableResult
    func recordWatch(on dayKey: String) -> Int {
        if dayKey != recordedDayKey {
            recordedDayKey = dayKey
            watchedCount = 0
            defaults.set(dayKey, forKey: Self.dayDefaultsKey)
        }
        watchedCount += 1
        defaults.set(watchedCount, forKey: Self.countDefaultsKey)
        return remaining(on: dayKey)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `xcodebuild ... test -only-testing:PixelColoringGameTests/RewardedAdQuotaTests`
Expected: PASS（5 テスト）。

- [ ] **Step 5: コミット**

```bash
git add PixelColoringGame/Core/PlayerProfileStore.swift PixelColoringGameTests/AudioSettingsTests.swift
git commit -m "feat(life): add RewardedAdQuota for daily ad-refill limit (5/day)"
```

---

### Task 2: grantRewardedLife の枯渇→+1→上限クランプを保証するテスト

既存 `PlayerProfileStore.grantRewardedLife(at:profile:calendar:)` の挙動をテストで固定する（実装変更なし）。

**Files:**
- Test: `PixelColoringGameTests/JourneyProgressSnapshotTests.swift`（末尾に新クラス追加）

- [ ] **Step 1: テストを書く**

`PixelColoringGameTests/JourneyProgressSnapshotTests.swift` の末尾に追加:

```swift

@MainActor
final class GrantRewardedLifeTests: XCTestCase {
    func test_grantFromDepleted_addsOneRefillableLife() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile()
        // 枯渇状態を作る
        profile.didSeedInitialLives = true
        profile.refillableLives = 0
        profile.bonusLives = 0
        profile.lifeRefillAnchorAt = Date.now

        let balance = store.grantRewardedLife(at: Date.now, profile: profile, calendar: .current)

        XCTAssertEqual(profile.refillableLives, 1)
        XCTAssertEqual(balance.totalLives, 1)
    }

    func test_grantNeverExceedsMaxRefillable() {
        let store = PlayerProfileStore()
        let profile = PlayerProfile()
        profile.didSeedInitialLives = true
        profile.refillableLives = PlayerProfileStore.maxRefillableLives
        profile.bonusLives = 0
        profile.lifeRefillAnchorAt = nil

        _ = store.grantRewardedLife(at: Date.now, profile: profile, calendar: .current)

        XCTAssertEqual(profile.refillableLives, PlayerProfileStore.maxRefillableLives)
    }
}
```

> 注: `PlayerProfile()` の引数なし初期化と各プロパティ名（`refillableLives`/`bonusLives`/`lifeRefillAnchorAt`/`didSeedInitialLives`）は現行 `Persistence/LevelProgress.swift` の `@Model PlayerProfile` 定義に存在する。`PlayerProfileStore.maxRefillableLives` は `static let`（=3）。`grantRewardedLife` の戻り値 `LifeBalance` には `totalLives` がある。これらが相違する場合は実コードの名前に合わせて修正すること。

- [ ] **Step 2: テストが通ることを確認**

Run: `xcodebuild ... test -only-testing:PixelColoringGameTests/GrantRewardedLifeTests`
Expected: 既存実装が正しければ PASS。コンパイルエラーが出る場合はプロパティ名の相違なので Step 1 のコードを実コードに合わせて修正し、再実行。

- [ ] **Step 3: コミット**

```bash
git add PixelColoringGameTests/JourneyProgressSnapshotTests.swift
git commit -m "test(life): lock in grantRewardedLife +1 and max-clamp behavior"
```

---

### Task 3: RewardedAdService を AppView.swift に復元（SDK ガード付き・インアクティブ）

SDK 未導入でもコンパイル・動作する（`canRequestAds=false`）状態で広告サービスを復元する。

**Files:**
- Modify: `PixelColoringGame/App/AppView.swift`（先頭の import 群と、ファイル末尾の `#Preview` ブロックの直前）

- [ ] **Step 1: ガード付き import を追加**

`AppView.swift` 冒頭の既存 `import` 群（`import SwiftUI` 等）の直後に追加:

```swift
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif
```

- [ ] **Step 2: RewardedAdService クラスとデリゲート拡張を追加**

`AppView.swift` 末尾の `#Preview { ... }` ブロックの**直前**に、以下をそのまま追加:

```swift
@MainActor
@Observable
final class RewardedAdService: NSObject {
    enum Availability: Hashable {
        case unavailable
        case loading
        case ready
        case failed
    }

    enum RewardOutcome: Hashable {
        case rewarded
        case cancelled
        case failed
    }

    private static let testRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    var canRequestAds = false
    var availability: Availability = .unavailable
    var isPresenting = false
    var lastErrorMessage: String?

    private let rewardedAdUnitID: String
    private var hasStartedSDK = false

#if canImport(GoogleMobileAds)
    private var rewardedAd: RewardedAd?
    private var rewardContinuation: CheckedContinuation<RewardOutcome, Never>?
    private var didEarnReward = false
#endif

    init(rewardedAdUnitID: String = RewardedAdService.testRewardedAdUnitID) {
        self.rewardedAdUnitID = rewardedAdUnitID
        super.init()
    }

    var isRewardButtonEnabled: Bool {
        canRequestAds && availability != .loading && !isPresenting
    }

    var rewardButtonTitleKey: String {
        switch availability {
        case .ready:
            return "life.depleted.watchAd"
        case .loading:
            return "life.depleted.loadingAd"
        case .failed, .unavailable:
            return "life.depleted.retryAd"
        }
    }

    /// SDK を起動し、UMP 同意を取得してから広告をプリロードする。
    /// SDK 未導入時（canImport=false）は何もせず canRequestAds=false のまま。
    func refreshConsentAndLoadAds() async {
        lastErrorMessage = nil
#if canImport(GoogleMobileAds)
        await startSDKIfNeeded()
#if canImport(UserMessagingPlatform)
        do {
            let parameters = RequestParameters()
            try await requestConsentInfoUpdate(with: parameters)
            try await loadAndPresentConsentFormIfRequired()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        canRequestAds = ConsentInformation.shared.canRequestAds
#else
        canRequestAds = true
#endif
        if canRequestAds {
            await preloadRewardedAd(force: true)
        } else {
            availability = .unavailable
        }
#else
        canRequestAds = false
        availability = .unavailable
#endif
    }

    func presentRewardedAd() async -> RewardOutcome {
        guard canRequestAds else {
            return .failed
        }

        guard !isPresenting else {
            return .failed
        }

#if canImport(GoogleMobileAds)
        if availability != .ready {
            await preloadRewardedAd(force: true)
        }

        guard let rewardedAd else {
            return .failed
        }

        isPresenting = true
        didEarnReward = false

        return await withCheckedContinuation { continuation in
            rewardContinuation = continuation
            rewardedAd.present(from: nil) { [weak self] in
                self?.didEarnReward = true
            }
        }
#else
        return .failed
#endif
    }

#if canImport(GoogleMobileAds)
    private func startSDKIfNeeded() async {
        guard !hasStartedSDK else { return }
        hasStartedSDK = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            MobileAds.shared.start { _ in
                continuation.resume()
            }
        }
    }

    private func preloadRewardedAd(force: Bool) async {
        guard canRequestAds else {
            availability = .unavailable
            rewardedAd = nil
            return
        }

        if !force, rewardedAd != nil, availability == .ready {
            return
        }

        availability = .loading

        do {
            let rewardedAd = try await RewardedAd.load(
                with: rewardedAdUnitID,
                request: Request()
            )
            rewardedAd.fullScreenContentDelegate = self
            self.rewardedAd = rewardedAd
            availability = .ready
            lastErrorMessage = nil
        } catch {
            rewardedAd = nil
            availability = .failed
            lastErrorMessage = error.localizedDescription
        }
    }

    private func finishPresentation(with outcome: RewardOutcome) {
        let continuation = rewardContinuation
        rewardContinuation = nil
        continuation?.resume(returning: outcome)
    }
#endif

#if canImport(UserMessagingPlatform)
    private func requestConsentInfoUpdate(with parameters: RequestParameters) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func loadAndPresentConsentFormIfRequired() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentForm.loadAndPresentIfRequired(from: nil) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
#endif
}

#if canImport(GoogleMobileAds)
extension RewardedAdService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isPresenting = false
        let outcome: RewardOutcome = didEarnReward ? .rewarded : .cancelled
        rewardedAd = nil
        availability = .unavailable
        finishPresentation(with: outcome)

        Task {
            await preloadRewardedAd(force: true)
        }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        isPresenting = false
        rewardedAd = nil
        availability = .failed
        lastErrorMessage = error.localizedDescription
        finishPresentation(with: .failed)

        Task {
            await preloadRewardedAd(force: true)
        }
    }
}
#endif
```

- [ ] **Step 3: ビルドが通ることを確認（オフライン / SDK 未導入）**

Run: `xcodebuild ... build`
Expected: SUCCEEDED。`canImport(GoogleMobileAds)` が false のため SDK 依存ブランチはコンパイル対象外。`RewardedAdService` は `canRequestAds=false` の inert な状態でビルドされる。

- [ ] **Step 4: コミット**

```bash
git add PixelColoringGame/App/AppView.swift
git commit -m "feat(ads): restore RewardedAdService (SDK-guarded, inert until SDK added)"
```

---

### Task 4: LifeDepletedSheet の広告 UI 復元 ＋ AppView 配線（1コミット単位）

> `LifeDepletedSheet` の引数変更と、その呼び出し側（`.lifeDepleted` ケース）は同時に変えないとビルドが通らないため、本タスクでまとめて行い、最後に一度だけビルド/テスト/コミットする。

**Files:**
- Modify: `PixelColoringGame/Resources/Localizable.xcstrings`
- Modify: `PixelColoringGame/App/AppView.swift`

- [ ] **Step 1: 新規ローカライズキーを追加**

`PixelColoringGame/Resources/Localizable.xcstrings` 内の `"life.depleted.close" : {` 行の**直前**に、同じインデント（半角スペース4）で以下を挿入:

```json
    "life.depleted.adLimitReached" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "You've used today's ad refills — wait for hearts to refill or come back tomorrow."
          }
        },
        "ja" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "本日分の広告回復は使い切りました。自然回復を待つか、また明日お試しください。"
          }
        }
      }
    },
```

- [ ] **Step 2: JSON の妥当性を確認**

Run: `python3 -m json.tool PixelColoringGame/Resources/Localizable.xcstrings > /dev/null && echo OK`
Expected: `OK`（カンマ/インデントのミスがあればここで検出）。

- [ ] **Step 3: LifeDepletedSheet の引数とボタンブロックを復元**

`AppView.swift` の `private struct LifeDepletedSheet: View {` のプロパティ宣言を、現行の

```swift
    let balance: LifeBalance
    let dailyChallenge: DailyChallengeState?
    let onClose: () -> Void
    let onPlayDaily: () -> Void
```

に対して、`adService`・`canWatchMore`・`onWatchAd` を追加して次の形にする:

```swift
    let balance: LifeBalance
    let dailyChallenge: DailyChallengeState?
    let adService: RewardedAdService
    let canWatchMore: Bool
    let onClose: () -> Void
    let onWatchAd: () -> Void
    let onPlayDaily: () -> Void
```

そのうえで、`body` 内のライフ枚数 `HStack { ... }` ブロックの**直後**（`if let dailyChallenge {` の直前）に、広告ボタン／上限到達文言を挿入:

```swift
            if adService.canRequestAds {
                if canWatchMore {
                    Button(action: onWatchAd) {
                        HStack {
                            Text(localization.string(adService.rewardButtonTitleKey))
                            Spacer(minLength: 0)
                            Image(systemName: "play.rectangle.fill")
                        }
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(AppTheme.accentOrange)
                        )
                    }
                    .buttonStyle(.tapSound)
                    .disabled(!adService.isRewardButtonEnabled)
                } else {
                    Text(localization.string("life.depleted.adLimitReached"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
```

> 注: 旧コードはボタンに `.buttonStyle(.plain)` を使っていたが、現行はタップ SFX のため `.buttonStyle(.tapSound)` がアプリ全体の標準（[[audio-system]]）。`AppTheme.accentOrange` / `AppTheme.textSecondary` / `localization.string(_:)` はいずれも既存。

- [ ] **Step 4: AppView に状態と日キー算出を追加**

`AppView` の `@State`/`private let` 宣言群（例: `private let playerProfileStore = PlayerProfileStore()` 付近, 55〜75行目あたり）に追加:

```swift
    @State private var rewardedAdService = RewardedAdService()
    @State private var rewardedAdQuota = RewardedAdQuota()
```

そして `private var appCalendar: Calendar { ... }`（262行目付近）の直後に、当日キーの算出を追加:

```swift
    private var todayQuotaKey: String {
        let components = appCalendar.dateComponents([.year, .month, .day], from: Date.now)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
```

- [ ] **Step 5: `.lifeDepleted` シートの呼び出しを更新**

`AppView.swift` の `.lifeDepleted` ケース（431行目付近）を、現行の

```swift
        case .lifeDepleted:
            LifeDepletedSheet(
                balance: lifeBalance,
                dailyChallenge: homeSnapshot.dailyChallenge,
                onClose: {
                    pendingLevelEntry = nil
                    activeSheet = nil
                },
                onPlayDaily: {
                    pendingLevelEntry = nil
                    activeSheet = nil
                    openDailyChallenge(source: .dailyHero)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
```

から、`adService`/`canWatchMore`/`onWatchAd` を加え、`.task` でロードを起動する次の形にする:

```swift
        case .lifeDepleted:
            LifeDepletedSheet(
                balance: lifeBalance,
                dailyChallenge: homeSnapshot.dailyChallenge,
                adService: rewardedAdService,
                canWatchMore: rewardedAdQuota.canWatch(on: todayQuotaKey),
                onClose: {
                    pendingLevelEntry = nil
                    activeSheet = nil
                },
                onWatchAd: {
                    Task { await handleRewardedLifeRequest() }
                },
                onPlayDaily: {
                    pendingLevelEntry = nil
                    activeSheet = nil
                    openDailyChallenge(source: .dailyHero)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .task { await rewardedAdService.refreshConsentAndLoadAds() }
```

> `.task` でシート表示時に SDK 起動＋同意＋プリロードを行う（SDK 未導入時は即 inert）。

- [ ] **Step 6: handleRewardedLifeRequest を追加（現行シグネチャ準拠）**

`attemptOpenLevel(...)` メソッド（617〜657行目付近）の**直後**に追加:

```swift
    private func handleRewardedLifeRequest() async {
        guard let profile = currentProfile else { return }
        let dayKey = todayQuotaKey
        guard rewardedAdQuota.canWatch(on: dayKey) else {
            await refreshCurrentContext(presentDailyPopup: false)
            return
        }

        let outcome = await rewardedAdService.presentRewardedAd()

        switch outcome {
        case .rewarded:
            rewardedAdQuota.recordWatch(on: dayKey)
            _ = playerProfileStore.grantRewardedLife(
                at: Date.now,
                profile: profile,
                calendar: appCalendar
            )
            saveContext(reason: "rewarded_life")
            await refreshCurrentContext(presentDailyPopup: false)

            if let pendingLevelEntry,
               let level = levelRepository.level(storageKey: pendingLevelEntry.storageKey) {
                activeSheet = nil
                self.pendingLevelEntry = nil
                attemptOpenLevel(
                    level: level,
                    routeContext: pendingLevelEntry.routeContext,
                    source: pendingLevelEntry.source
                )
            } else {
                activeSheet = nil
            }
        case .cancelled, .failed:
            await refreshCurrentContext(presentDailyPopup: false)
        }
    }
```

> **現行 API との整合（重要）**: `refreshCurrentContext` は現行 `func refreshCurrentContext(presentDailyPopup: Bool)`（旧 `refreshAds:` 引数は廃止済み）なので `presentDailyPopup:` のみで呼ぶ。`attemptOpenLevel(level:routeContext:source:)`・`PendingLevelEntry`（`storageKey`/`routeContext`/`source`）・`levelRepository.level(storageKey:) -> LevelManifest?`・`saveContext(reason:)`・`currentProfile` はいずれも現行 AppView に存在（確認済み）。

- [ ] **Step 7: ビルドとテストが通ることを確認**

Run: `xcodebuild ... build` → SUCCEEDED
Run: `xcodebuild ... test` → 全テスト PASS（既存 + Task1/2 追加分）。
Expected: アプリは完全に配線済みだが SDK 未導入のため `canRequestAds=false` で広告ボタンは非表示、既存挙動を維持。

- [ ] **Step 8: コミット**

```bash
git add PixelColoringGame/App/AppView.swift PixelColoringGame/Resources/Localizable.xcstrings
git commit -m "feat(ads): wire rewarded-life flow into LifeDepletedSheet + AppView (quota-gated)"
```

---

### Task 5: SDK パッケージ ＋ Info.plist ＋ Privacy を追加（機能を有効化）

> ここで初めて `canImport(GoogleMobileAds)` が true になり、実広告パスがコンパイル対象になる。SPM 解決のため**ネットワークが必要**。

> **実施メモ（更新）**: Step 3（Info.plist）は完了（`GADApplicationIdentifier` テスト ＋ `SKAdNetworkItems` 47件を git の削除前構成から忠実に復元）。**`NSUserTrackingUsageDescription` は追加しない**（旧来の出荷構成は UMP 同意のみで ATT/IDFA を使わず、復元した `RewardedAdService` も `requestTrackingAuthorization` を呼ばない）。**Step 4（PrivacyInfo）は変更不要**：d532d21 が PrivacyInfo から消したのは広告ではなく CrashData だけで、旧来も広告トラッキングをアプリ側マニフェストに宣言していない（GoogleMobileAds SDK が自前の privacy manifest を同梱、アプリは `NSPrivacyTracking=false` のまま）。将来パーソナライズ広告（IDFA/ATT）を使う場合のみ `NSUserTrackingUsageDescription` 追加＋ATT 要求＋PrivacyInfo 更新が必要。**Step 2（SPM パッケージ追加）はユーザーが Xcode の「Add Package Dependencies」で実施**する分担とした。

**Files:**
- Modify: `PixelColoringGame.xcodeproj/project.pbxproj`
- Modify: `PixelColoringGame/Info.plist`
- Modify: `PixelColoringGame/PrivacyInfo.xcprivacy`

- [ ] **Step 1: 現行 SDK バージョンと API 名を確認**

context7 もしくは公式ドキュメントで、現在の Google Mobile Ads (Swift Package) の最新メジャーと、本計画で使う API 名が一致するか確認する:
`MobileAds.shared.start`, `RewardedAd.load(with:request:)`, `RewardedAd.present(from:_:)`, `Request()`, `FullScreenContentDelegate`, `FullScreenPresentingAd`, UMP の `ConsentInformation.shared`, `ConsentForm.loadAndPresentIfRequired(from:)`, `RequestParameters`, `ConsentInformation.shared.canRequestAds`。
- 一致するメジャー（既定は復元元の v12 / UMP v3）で次の Step に進む。
- API 名が変わっている場合は Task 3 の該当箇所を最新名に修正してから進む。
- **Swift 6 strict-concurrency の必須確認**: `RewardedAdService` は `@MainActor`。SDK 追加後のビルドで `FullScreenContentDelegate` 適合が「Main actor-isolated ... cannot satisfy nonisolated protocol requirement」エラーになる場合は、`extension RewardedAdService: @preconcurrency FullScreenContentDelegate { ... }` にするか、各デリゲートメソッド（`adDidDismissFullScreenContent` / `ad(_:didFailToPresentFullScreenContentWithError:)`）に `@MainActor` を付与する。SDK 追加直後のビルドで必ず検証すること（コードレビュー指摘事項）。

- [ ] **Step 2: SPM パッケージ参照を pbxproj に復元**

`PixelColoringGame.xcodeproj/project.pbxproj` に以下4箇所を追加する（プレースホルダ UUID `A0000…` は `d532d21` で削除済みのため再利用で衝突しない）。**Xcode が手元にある場合は「File ▸ Add Package Dependencies…」で2 URL を追加する方が安全**。手編集する場合の挿入内容:

(a) `/* Begin PBXBuildFile section */` 内に:
```
		A0000000000000000000008D /* GoogleMobileAds in Frameworks */ = {isa = PBXBuildFile; productRef = A00000000000000000000092 /* GoogleMobileAds */; };
		A0000000000000000000008E /* GoogleUserMessagingPlatform in Frameworks */ = {isa = PBXBuildFile; productRef = A00000000000000000000093 /* GoogleUserMessagingPlatform */; };
```
(b) アプリターゲットの `PBXFrameworksBuildPhase` の `files = ( ... )` 内に:
```
				A0000000000000000000008D /* GoogleMobileAds in Frameworks */,
				A0000000000000000000008E /* GoogleUserMessagingPlatform in Frameworks */,
```
(c) アプリターゲット（`PBXNativeTarget`）に `packageProductDependencies` を追加（無ければ作る）:
```
			packageProductDependencies = (
				A00000000000000000000092 /* GoogleMobileAds */,
				A00000000000000000000093 /* GoogleUserMessagingPlatform */,
			);
```
かつ `PBXProject` に `packageReferences` を追加（無ければ作る）:
```
			packageReferences = (
				A00000000000000000000090 /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */,
				A00000000000000000000091 /* XCRemoteSwiftPackageReference "swift-package-manager-google-user-messaging-platform" */,
			);
```
(d) ファイル末尾付近に2つの新セクションを追加:
```
/* Begin XCRemoteSwiftPackageReference section */
		A00000000000000000000090 /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/googleads/swift-package-manager-google-mobile-ads.git";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 12.0.0;
			};
		};
		A00000000000000000000091 /* XCRemoteSwiftPackageReference "swift-package-manager-google-user-messaging-platform" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 3.0.0;
			};
		};
/* End XCRemoteSwiftPackageReference section */
/* Begin XCSwiftPackageProductDependency section */
		A00000000000000000000092 /* GoogleMobileAds */ = {
			isa = XCSwiftPackageProductDependency;
			package = A00000000000000000000090 /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */;
			productName = GoogleMobileAds;
		};
		A00000000000000000000093 /* GoogleUserMessagingPlatform */ = {
			isa = XCSwiftPackageProductDependency;
			package = A00000000000000000000091 /* XCRemoteSwiftPackageReference "swift-package-manager-google-user-messaging-platform" */;
			productName = GoogleUserMessagingPlatform;
		};
/* End XCSwiftPackageProductDependency section */
```
> 参考: 削除前の正確なエントリは `git show d532d21^:PixelColoringGame.xcodeproj/project.pbxproj` で確認できる。

- [ ] **Step 3: Info.plist に AdMob 設定を追加**

`PixelColoringGame/Info.plist` の `<dict>` 直下に追加:
```xml
	<key>GADApplicationIdentifier</key>
	<string>ca-app-pub-3940256099942544~1458002511</string>
	<key>NSUserTrackingUsageDescription</key>
	<string>あなたに合った広告を表示するために使用します。許可しない場合も広告は表示されますが、内容は最適化されません。</string>
```
さらに `SKAdNetworkItems` 配列（47件）を、削除前の Info.plist から復元して追加する:
```
git show d532d21^:PixelColoringGame/Info.plist
```
の出力から `<key>SKAdNetworkItems</key> ... </array>` ブロックをそのまま `Info.plist` の `<dict>` 内へコピーする。

- [ ] **Step 4: PrivacyInfo.xcprivacy にトラッキング/収集データを申告**

`PixelColoringGame/PrivacyInfo.xcprivacy` を更新する。Google 公式の Privacy manifest 指針（Step 1 で確認）に従い、最低限以下を反映:
- `NSPrivacyTracking` を `true` に（ATT を使う場合）。
- `NSPrivacyTrackingDomains` に Google 提示のドメインを追加。
- `NSPrivacyCollectedDataTypes` に Device ID 等（広告用途・トラッキング目的）を追加。
> 正確な値は Google の最新ドキュメントに従う。SDK 同梱の Privacy manifest があれば、アプリ側は重複申告しないこと。

- [ ] **Step 5: ビルドが通り、SDK が解決されることを確認**

Run（ネットワーク有効・サンドボックス無効で）: `xcodebuild ... build`
Expected: SwiftPM が GoogleMobileAds/UserMessagingPlatform を解決し、`canImport(GoogleMobileAds)` が true の実広告パスを含めて SUCCEEDED。`Package.resolved` は自動生成される。

- [ ] **Step 6: テストが引き続き通ることを確認**

Run: `xcodebuild ... test`
Expected: 全テスト PASS。

- [ ] **Step 7: コミット**

```bash
git add PixelColoringGame.xcodeproj PixelColoringGame/Info.plist PixelColoringGame/PrivacyInfo.xcprivacy
git commit -m "feat(ads): add GoogleMobileAds + UMP SPM deps, Info.plist & privacy manifest (test IDs)"
```

---

### Task 6: シミュレータで手動検証

自動 UI 操作はこの環境では不可（[[ios-build-test-cli]]）。手動で受け入れ条件を確認する。

**Files:** なし（検証のみ）

- [ ] **Step 1: ビルドしてシミュレータにインストール・起動**

```bash
xcrun simctl boot "iPhone 17" || true
xcodebuild ... build
xcrun simctl install booted "$(find build/DerivedData2 -name 'PixelColoringGame.app' -type d | head -1)"
xcrun simctl launch booted com.pixelbloom.app
```

- [ ] **Step 2: 受け入れ条件を手動確認**

- ライフを 0 まで消費 → Journey レベルに入ろうとする → `LifeDepletedSheet` にテスト広告の視聴ボタンが出る。
- 視聴完了 → 回復ライフが +1 され、保留中レベルへ自動入場できる。
- 同日 6 回目はボタンが消え、`life.depleted.adLimitReached` の文言が表示される。
- 広告を途中で閉じる → ライフ・回数とも変化しない。
- スクリーンショット: `xcrun simctl io booted screenshot /tmp/life_depleted.png`

- [ ] **Step 3: 結果を記録**

検証結果（OK/NG と気づき）を PR 本文に追記する。

---

## リリース前の非コード作業（本実装の範囲外・別途対応）

- 「ad-free」を謳う公開 README ／ App Store 説明文・プライバシー栄養成分表示の整合更新。
- テスト ID → **本番 AdMob ID** への差し替え（`RewardedAdService.testRewardedAdUnitID` と `Info.plist` の `GADApplicationIdentifier`）。
- ATT/同意まわりの実機・審査確認。

## 受け入れ条件（Definition of Done）

1. ライフ0で Journey 入場 → 視聴ボタン表示（テスト広告ロード時）。
2. 視聴完了 → 回復ライフ +1、保留中レベルへ自動再入場。
3. 同日6回目はブロックされ案内文表示、日付変更でリセット。
4. キャンセル/失敗時はライフ・回数とも不変。
5. SDK 未導入でもビルド通過・既存挙動維持（Task 4 終了時点で確認済み）。
6. 既存テスト全通過 ＋ `RewardedAdQuotaTests` / `GrantRewardedLifeTests` が追加・通過。
