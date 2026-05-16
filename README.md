# Pixel Bloom

A calm, ad-free pixel-art coloring game for iOS.

Color a small pixel artwork pixel by pixel — pick a number from the palette,
tap the matching cells, and watch the picture bloom. Designed as a gentle daily
reset: simple to pick up, satisfying to finish, with a growing collection to
come back to.

## Features

- **Hundreds of curated artworks** — animals, plants, seasonal scenes, snacks.
- **Daily Challenge** — a fresh hand-picked artwork each day, with streaks.
- **Monthly events** — month-long themed collections.
- **Local progress** — saved on-device with SwiftData; works fully offline.
- **Ad-free** — no ads, no accounts, no in-app purchases.
- **Accessibility-first** — respects Reduce Motion and Low Power Mode.
- **Localized** — English and Japanese.

## Tech Stack

- SwiftUI, iOS 17+, Swift 6
- SwiftData for local persistence
- Universal (iPhone & iPad)

## Project Layout

```
PixelColoringGame/
  App/            App entry & root navigation
  Core/           Stores, repositories, localization, audio
  Features/       Title, Journey, Daily, Game, Completion, Collection
  Models/         Level / journey manifests
  Resources/      Bundled levels, localized strings, assets
  Utilities/      Design system & helpers
Scripts/          Level-pack generation tooling
docs/             Privacy / support pages, release notes
```

## Build

```bash
xcodebuild build \
  -scheme PixelColoringGame \
  -project PixelColoringGame.xcodeproj \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

## Test

```bash
xcodebuild test \
  -scheme PixelColoringGame \
  -project PixelColoringGame.xcodeproj \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PixelColoringGameTests \
  CODE_SIGNING_ALLOWED=NO
```

## License

Released under the [MIT License](LICENSE).
