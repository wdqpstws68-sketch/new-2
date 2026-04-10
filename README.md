# PixelColoringGame

SwiftUI / iOS 17 で作った、24x24 固定のドット絵色塗りゲーム MVP です。

## What Is Included

- `PixelColoringGame.xcodeproj`
  - `Home / Play / Completion` の 3 画面
  - `SwiftData` によるローカル進捗保存
  - `HintService`, `GameSessionStore`, `ProgressStore`, `LevelRepository`
- `PixelColoringGame/Resources`
  - curated 10 レベル
  - thumbnail / solved PNG
- `Scripts/pixel_level_pipeline.py`
  - curated sample pack 生成
  - PixelLab SDK を使う単発レベル生成フローの枠組み

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

```bash
python3 Scripts/pixel_level_pipeline.py build-level \
  --pixellab \
  --prompt "cute snail sticker" \
  --level-id snail-02 \
  --title "Snail 02" \
  --category animals \
  --difficulty Medium \
  --estimated-minutes 5 \
  --sort-order 11 \
  --output-folder PixelColoringGame/Resources
```
