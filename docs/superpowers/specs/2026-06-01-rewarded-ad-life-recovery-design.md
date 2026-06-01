# 設計書：報酬型広告によるライフ回復（AdMob 再導入 / v1.1）

- **日付**: 2026-06-01
- **対象**: PixelColoringGame（iOS / Swift 6 / iOS 17+ / SwiftUI）
- **ステータス**: 承認済み（実装計画へ移行可）

## 1. 背景

直近リリース `d532d21`「feat(v1.0): finalize ad-free release — remove AdMob」で AdMob を全削除し、広告なし(ad-free)で v1.0 をリリースした。本件は、その方針を一部転換し、**ライフ切れ時に動画（報酬型）広告を1本視聴すると回復ライフが +1 される**仕組みを v1.1 として再導入する。

調査により以下が判明している（実装の前提）:

- ライフ系統は完成済み。`Core/PlayerProfileStore.swift` に `LifeBalance`（`refillableLives` 最大3 ＋ `bonusLives` 最大3、8時間で1回復）と、**未使用のフック `grantRewardedLife(at:profile:calendar:)`（+1 回復ライフ、上限3でクランプ）** が現存。
- ライフ切れ時の導線も現存：`consumeLifeIfNeeded` が `.unavailable` を返すと `AppView.swift` が `activeSheet = .lifeDepleted` を立て、`LifeDepletedSheet` を表示する（現状は広告ボタンを剥がした状態）。
- 旧 AdMob 実装一式は `d532d21` の親コミットに残存（git から復元可能）:
  - `RewardedAdService`（`@MainActor @Observable final class : NSObject`、`presentRewardedAd() async -> RewardOutcome`、`FullScreenContentDelegate` 実装、UMP 同意処理）。
  - `LifeDepletedSheet` の `adService`/`onWatchAd` 引数と視聴ボタンブロック。
  - `AppView.handleRewardedLifeRequest()`（`presentRewardedAd` → `.rewarded` で `grantRewardedLife` 呼び出し → 保留中レベルへ自動再入場）。
- 広告ボタン用ローカライズキーは **すべて現存**：`life.depleted.watchAd` / `life.depleted.loadingAd` / `life.depleted.retryAd`。
- 旧 `refreshConsentAndLoadAds()` は v1.0 で **空実装(no-op)** だった。v1.1 では実際に「SDK 起動 → UMP 同意 → 広告ロード」を行う**新規実装**が必要。

## 2. ゴールと範囲

ライフ切れ時に動画広告を1本見ると **回復ライフ +1**（上限3）。**1日5回**まで。まずは Google 公式テストIDで実装し、リリース前に本番IDへ差し替える。

### やること
- 報酬型（rewarded）広告のみ。
- 報酬 = 回復ライフ +1（`grantRewardedLife()` をそのまま使用、上限3でクランプ）。
- 1日5回の上限（新規 `RewardedAdQuota`）。
- 表示位置はライフ切れ時の `LifeDepletedSheet` 内のみ。
- テストID先行。

### やらないこと（YAGNI）
- バナー広告の復活。
- ライフ表示部などへの常時「動画で+1」ボタン（プロアクティブ・トップアップ）。
- 本番 AdMob ID の設定（リリース前の人手対応として別管理）。
- メディエーション。

## 3. アーキテクチャ／コンポーネント

既存パターンに準拠：`@Observable @MainActor` サービスを `AppView.init()` で `@State` 生成し、`.environment()` で注入。永続化は SwiftData（ライフ本体）＋ UserDefaults（派生・リセット前提の状態）。

| 区分 | 配置 | 内容 |
|---|---|---|
| `RewardedAdService` | 新規ファイル `PixelColoringGame/Core/Ads/RewardedAdService.swift` | 旧実装（AppView 内）を**独立ファイルへ抽出して復元**。`@MainActor @Observable final class : NSObject`。`Availability` / `RewardOutcome` enum、`canRequestAds`/`availability`/`isPresenting`/`lastErrorMessage`、`isRewardButtonEnabled`、`rewardButtonTitleKey` を復元。`presentRewardedAd()` と `FullScreenContentDelegate` 拡張はほぼそのまま。**`refreshConsentAndLoadAds()` は新規実装**（`MobileAds.shared.start()` → UMP 同意取得/提示 → `canRequestAds = ConsentInformation.shared.canRequestAds` → `preloadRewardedAd(force:)`）。全体を `#if canImport(GoogleMobileAds)` / `#if canImport(UserMessagingPlatform)` でガードし、SDK 未導入でもビルド・動作（`canRequestAds=false` で広告非表示）。 |
| `RewardedAdQuota` | 新規ファイル `PixelColoringGame/Core/Ads/RewardedAdQuota.swift` | 1日上限(5)の管理。`AudioSettings` 同様 UserDefaults に `watchedCount: Int` と `dayKey: String` を保存。API: `canWatchMore`、`remainingToday`、`recordWatch(dayKey:)`、`refresh(dayKey:)`（日付が変われば 0 にリセット）。日付境界は `appCalendar`（デイリーチャレンジと同じローカル日付キー）を使用。SwiftData スキーマ移行を避けるため UserDefaults を採用。上限定数 `dailyLimit = 5`。 |
| `LifeDepletedSheet` | 既存 `PixelColoringGame/App/AppView.swift`（1130付近）を改修 | `adService: RewardedAdService` と `onWatchAd: () -> Void` 引数、視聴ボタンブロック（既存ローカライズキー使用）を復元。さらに **「本日の上限到達」状態**を追加：`!quota.canWatchMore` のときはボタンを出さず案内文（新規キー `life.depleted.adLimitReached`）。`remainingToday` を `quota` から受け取る引数を追加。 |
| `AppView` 配線 | 既存 `PixelColoringGame/App/AppView.swift` を改修 | `@State private var rewardedAdService` と `@State private var rewardedAdQuota` を `init` で生成。`.lifeDepleted` ケース（431付近）で `adService`/`onWatchAd`/quota 情報を渡すよう復元。`handleRewardedLifeRequest()` を復元し、報酬獲得時に **quota 確認 → `grantRewardedLife` → `recordWatch` → `saveContext` → `refreshCurrentContext` → 保留中レベルがあれば `attemptOpenLevel` で自動再入場**。`.lifeDepleted` を立てる直前（654付近）または bootstrap 時に `refreshConsentAndLoadAds()` を起動。 |

> 補足: `AppView.swift` は現在1227行で最大ファイル。広告サービスを `Core/Ads/` に切り出すのは責務分離の観点でも妥当（`AudioPlayerService` が独立ファイルなのと同じ流儀）。

## 4. データフロー

```
ライフ0で Journey 入場
  → consumeLifeIfNeeded(.journey) → .unavailable(balance)
  → AppView: rewardedAdService.refreshConsentAndLoadAds() を起動、activeSheet = .lifeDepleted
  → LifeDepletedSheet:
        adService.canRequestAds && quota.canWatchMore のとき
          → 「動画を見て+1」ボタン（availability に応じ watchAd/loadingAd/retryAd 文言）
        それ以外
          → ボタン非表示 or 上限到達案内（adLimitReached）。デイリー導線は常に表示。
  → ボタンタップ → onWatchAd → handleRewardedLifeRequest()
        → outcome = await rewardedAdService.presentRewardedAd()
        → .rewarded:
              guard quota.canWatchMore
              grantRewardedLife(at: .now, profile:, calendar: appCalendar)  // +1 上限3
              quota.recordWatch(dayKey:)
              saveContext(reason: "rewarded_life")
              await refreshCurrentContext(refreshAds: false, presentDailyPopup: false)
              保留中レベルがあれば activeSheet=nil → attemptOpenLevel で自動再入場
              なければ activeSheet=nil
        → .cancelled / .failed:
              ライフ・quota とも消費せず、refreshCurrentContext のみ
```

## 5. エッジ／エラー処理

- **SDK 未導入 / `canImport(GoogleMobileAds)`=false**：`canRequestAds=false` → ボタン非表示。自然回復のみで通常動作（既存挙動を壊さない）。
- **広告ロード失敗**：`availability=.failed` → ボタンは `life.depleted.retryAd` 文言で再ロードを促す。
- **視聴途中キャンセル**：`.cancelled` → ライフも quota も消費しない。
- **上限(5/日)到達**：ボタンを案内文（`life.depleted.adLimitReached`）に差し替え。デイリー導線は引き続き表示。
- **報酬獲得時に既に満タン**：シートは 0 ライフ時のみ表示＋`grantRewardedLife` が上限3でクランプ済みなので安全。
- **UMP 同意**：拒否/制限時も非パーソナライズ広告は表示可。`canRequestAds` は `ConsentInformation.shared.canRequestAds` を反映。
- **Swift 6 strict concurrency**：SDK のデリゲートコールバック（`FullScreenContentDelegate`）は `@MainActor` 隔離下で扱う。`RewardedAdService` 全体が `@MainActor` のため整合。

## 6. ビルド／設定変更（非 Swift）

- **project.pbxproj**：`d532d21` で削除された2つの SPM パッケージを復元。
  - GoogleMobileAds: `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`
  - UserMessagingPlatform: `https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git`
  - メジャーバージョンは**実装時に最新を確認**してから固定（旧 = GoogleMobileAds v12 / UMP v3）。`XCRemoteSwiftPackageReference` ＋ `packageProductDependencies` ＋ Frameworks 追加が必要。可能なら Xcode の「Add Package」で再追加、または `d532d21` の該当 hunk を revert。
- **Info.plist**：`GADApplicationIdentifier`（テスト `ca-app-pub-3940256099942544~1458002511`）、`SKAdNetworkItems`（47件）、`NSUserTrackingUsageDescription` を復元。
- **PrivacyInfo.xcprivacy**：AdMob 向けにトラッキング/収集データ項目を追記（Google 公開のプライバシーマニフェスト指針に準拠）。現状は `NSPrivacyTracking=false`・収集なし・API理由は UserDefaults/FileTimestamp/SystemBootTime/DiskSpace のみ。
- **ローカライズ（`Localizable.xcstrings`）**：既存キー流用。新規は `life.depleted.adLimitReached`（en/ja）のみ。
- **広告ユニットID（テスト）**：Rewarded `ca-app-pub-3940256099942544/1712485313`。

## 7. テスト

- `RewardedAdQuota` の純ロジックを単体テスト：加算／日付変更でリセット／5で `canWatchMore=false`／`remainingToday` の整合。
- 既存 `PlayerProfileStoreTests` 系に「枯渇(0)→`grantRewardedLife`→+1（上限3でクランプ）」のテストを追加。
- `handleRewardedLifeRequest` をテスト可能にするため、`presentRewardedAd` を担う薄いプロトコル（例 `RewardedAdPresenting`）で抽象化し、フェイクで検証（任意・推奨）。
- 手動：シミュレータ＋テスト広告ユニットで「広告表示 → +1 付与 → 6回目がブロック → 翌日にリセット」を確認。

## 8. リリース前の非コード作業（本実装の範囲外・要対応として記録）

- 「ad-free」を謳う公開 README ／ App Store の説明文・プライバシー栄養成分表示の整合更新。
- テストID → **本番ID 差し替え**（差し替え忘れは規約違反/収益化されない）。
- App Store 審査向けの ATT/プライバシー設定の最終確認。

## 9. 受け入れ条件（Definition of Done）

1. ライフ0で Journey 入場 → `LifeDepletedSheet` に動画視聴ボタンが出る（テスト広告がロードされている場合）。
2. 視聴完了 → 回復ライフが +1 され、保留中レベルがあれば自動で入場できる。
3. 同日6回目の視聴はブロックされ、案内文が表示される。日付が変わるとリセットされる。
4. 視聴キャンセル/失敗時はライフ・回数とも変化しない。
5. SDK 未導入状態でもビルドが通り、広告ボタンは非表示で既存挙動が維持される。
6. 既存テストが全て通り、`RewardedAdQuota` と `grantRewardedLife` のテストが追加されている。
