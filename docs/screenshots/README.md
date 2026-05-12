# App Store Screenshots

このディレクトリは App Store Connect に提出するスクリーンショットの保管場所。

## 自動撮影済み

| ファイル | デバイス | 言語 | シーン |
|---|---|---|---|
| `iphone/01-title.png` | iPhone 17 (1320×2868) | ja | タイトル画面 |

iPhone 17 のスクリーンショットは `xcrun simctl io booted screenshot ...` で自動撮影しました。これは App Store Connect の iPhone 6.7"/6.9" カテゴリ向け解像度 (1290×2796) と非常に近く、Apple が自動でスケーリングを許容する範囲です。

## 残りの撮影手順 (手動推奨)

`docs/superpowers/phase4-release-runbook.md` のステップ 5 を参照。

### 残ったシーンと撮影方法

各デバイス × jp/en で以下 4 シーンを撮影 (合計 32 PNG):

1. **02-play.png**: 任意のレベルを開いて中ズーム、パレットトレイ表示、色を塗ってる瞬間
2. **03-completion.png**: レベル完成 → CompletionView の confetti 演出が見える瞬間
3. **04-collection.png**: コレクションタブ → 完成済みピクセルアートが並んだ画面
4. **05-daily.png**: デイリータブ → 月のカレンダー表示

### コマンド (各デバイスごと)

```bash
# 1. シミュレータ起動・アプリ起動
xcrun simctl boot "iPhone 17 Pro Max"
open -a Simulator
xcrun simctl install booted /tmp/PixelColoringGameDerived/Build/Products/Debug-iphonesimulator/PixelColoringGame.app
xcrun simctl launch booted com.pixelbloom.app

# 2. シミュレータの言語切替 (en の場合)
xcrun simctl shutdown booted
xcrun simctl boot "iPhone 17 Pro Max"
# Simulator アプリ > Device > Erase All Content and Settings... して
# Settings > General > Language & Region で言語を English に変更

# 3. アプリで該当画面に手動でナビゲートしてスクリーンショット
# Simulator アプリで Cmd+S を押して保存
# または:
xcrun simctl io booted screenshot docs/screenshots/iphone/02-play.png
```

### キャッチコピー焼き込み

1枚目のタイトル画面に「やさしい色で、心ほどける時間。」(jp) or "Relaxing pixel coloring." (en) を焼き込むのは Figma や Canva などの外部ツールで後処理が楽。素のスクリーンショット + テキストオーバーレイのテンプレを作るだけ。

## 必要な解像度 (App Store Connect)

| カテゴリ | 解像度 | スケーリング許容 |
|---|---|---|
| iPhone 6.9" (iPhone 17 Pro Max) | 1320×2868 | これ自体が新フォーマット |
| iPhone 6.7" (iPhone 15 Pro Max) | 1290×2796 | 6.9"から派生可 |
| iPhone 6.5" (iPhone 11 Pro Max) | 1242×2688 | 同上 |
| iPad Pro 13" (M5) | 2064×2752 | これ自体が新フォーマット |
| iPad Pro 12.9" (3rd-6th gen) | 2048×2732 | 13"から派生可 |

App Store Connect は同一 PNG を複数解像度カテゴリにアップロードできるので、最低限「6.9"」と「13"」の jp/en × 5 = 20 枚を撮影すれば残りは自動派生で対応可能です。
