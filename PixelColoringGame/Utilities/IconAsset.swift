import SwiftUI
import UIKit

/// Central abstraction for all custom/generated icon assets.
///
/// Each case maps to an Asset Catalog image (when placed under `Assets.xcassets`)
/// with an SF Symbol fallback when the asset has not yet been produced.
/// This keeps the rest of the codebase stable while pixellab jobs land
/// asynchronously — placing an image in the catalog under the documented name
/// is enough to flip to the custom art.
enum IconAsset {
    case mascot

    case heart
    case streak
    case star

    case tabJourney
    case tabDaily
    case tabLibrary

    case chapterBGBerry
    case chapterBGTide
    case chapterBGPetal

    /// Asset catalog name expected under `Assets.xcassets`.
    var assetName: String {
        switch self {
        case .mascot: return "TitleMascot"
        case .heart: return "IconHeart"
        case .streak: return "IconStreak"
        case .star: return "IconStar"
        case .tabJourney: return "IconTabJourney"
        case .tabDaily: return "IconTabDaily"
        case .tabLibrary: return "IconTabLibrary"
        case .chapterBGBerry: return "ChapterBGBerry"
        case .chapterBGTide: return "ChapterBGTide"
        case .chapterBGPetal: return "ChapterBGPetal"
        }
    }

    var sfSymbolFallback: String {
        switch self {
        case .mascot: return "sparkles"
        case .heart: return "heart.fill"
        case .streak: return "flame.fill"
        case .star: return "star.fill"
        case .tabJourney: return "paintpalette.fill"
        case .tabDaily: return "calendar"
        case .tabLibrary: return "books.vertical.fill"
        case .chapterBGBerry, .chapterBGTide, .chapterBGPetal: return "square.fill"
        }
    }

    /// True when the Asset Catalog contains the generated image.
    /// Used by background views to decide between tiled art vs a solid fallback.
    var hasCustomArt: Bool {
        UIImage(named: assetName) != nil
    }

    /// Returns the generated image when available, otherwise an SF Symbol fallback.
    var image: Image {
        if hasCustomArt {
            return Image(assetName).renderingMode(.original)
        }
        return Image(systemName: sfSymbolFallback)
    }
}
