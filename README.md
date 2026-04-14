# PixelColoringGame

SwiftUI / iOS 17 で作った、可変盤面サイズ対応のドット絵色塗りゲーム MVP です。

## What Is Included

- `PixelColoringGame.xcodeproj`
  - `Home / Play / Completion` の 3 画面
  - `SwiftData` によるローカル進捗保存
  - `HintService`, `GameSessionStore`, `ProgressStore`, `LevelRepository`
- `PixelColoringGame/Resources`
  - curated journey / daily レベル
  - thumbnail / solved PNG
- `Scripts/pixel_level_pipeline.py`
  - curated sample pack 生成
  - PixelLab SDK を使う単発レベル生成フロー

既存の同梱章は主に `24x24` ですが、新規の Pixellab 章は `32x32` を採用できます。盤面サイズは各レベルのマニフェスト (`boardWidth` / `boardHeight`) ごとに可変です。

## Regenerate The Bundled Levels

```bash
python3 Scripts/pixel_level_pipeline.py generate-sample-pack --output PixelColoringGame/Resources
```

## Build

```bash
xcodebuild build \
  -scheme PixelColoringGame \
  -project PixelColoringGame.xcodeproj \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PixelColoringGameDerived \
  CODE_SIGNING_ALLOWED=NO
```

## PixelLab Flow

`build-level` は PixelLab の Python SDK を環境に入れた前提です。

新規 Pixellab レベルでは、主題の視認性を優先して高めの `render-size` から `board-size` へ落とす運用を推奨します。細部を増やしすぎず、縮小サムネイルでも主題が一目で分かることを品質基準にします。

```bash
python3 Scripts/pixel_level_pipeline.py build-level \
  --pixellab \
  --prompt "simple moonflower blossom sticker, centered, five large petals, chunky pixel art, very readable silhouette, indigo and cream, no background, no text, no extra details" \
  --level-id moonflower \
  --title "Moonflower Glow" \
  --title-key "level.moonflower.title" \
  --category plants \
  --category-key "level.category.plants" \
  --difficulty Medium \
  --difficulty-key "level.difficulty.medium" \
  --estimated-minutes 6 \
  --sort-order 21 \
  --board-size 32 \
  --render-size 128 \
  --max-colors 4 \
  --style-preset simple-sticker \
  --output-folder PixelColoringGame/Resources
```
