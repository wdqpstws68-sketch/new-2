import Foundation
import UIKit

@MainActor
struct LevelRepository {
    let bundle: Bundle
    let levels: [LevelManifest]
    private let levelsByStorageKey: [String: LevelManifest]
    private let previewCache = LevelPreviewImageCache.shared

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        let resolvedLevels = Self.loadLevels(from: bundle)
        self.levels = resolvedLevels
        self.levelsByStorageKey = Dictionary(uniqueKeysWithValues: resolvedLevels.map { ($0.storageKey, $0) })
    }

    init(bundle: Bundle = .main, levels: [LevelManifest]) {
        self.bundle = bundle
        self.levels = levels.sorted(by: { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.id < rhs.id
            }
            return lhs.sortOrder < rhs.sortOrder
        })
        self.levelsByStorageKey = Dictionary(uniqueKeysWithValues: self.levels.map { ($0.storageKey, $0) })
    }

    func level(storageKey: String) -> LevelManifest? {
        levelsByStorageKey[storageKey]
    }

    func thumbnailImage(for level: LevelManifest) -> UIImage? {
        previewImage(for: level, kind: .thumbnail)
    }

    func solvedImage(for level: LevelManifest) -> UIImage? {
        previewImage(for: level, kind: .solved)
    }

    func silhouetteImage(for level: LevelManifest, side _: CGFloat = 240) -> UIImage? {
        previewImage(for: level, kind: .silhouette)
    }

    private func previewImage(
        for level: LevelManifest,
        kind: LevelRepositoryPreviewKind,
        side: CGFloat? = nil
    ) -> UIImage? {
        let requestedSide = max(side ?? kind.defaultSide, 1)
        let cacheKey = LevelPreviewCacheKey(
            storageKey: level.storageKey,
            kind: kind,
            side: requestedSide
        )

        if let cached = previewCache.image(for: cacheKey) {
            return cached
        }

        let image: UIImage?
        switch kind {
        case .thumbnail:
            image = bundledImage(named: level.thumbnailAsset, subdirectory: "GeneratedThumbnails")
                ?? LevelPreviewRenderer.renderSolved(level: level, side: requestedSide)
        case .solved:
            image = bundledImage(named: level.solvedAsset, subdirectory: "GeneratedSolved")
                ?? LevelPreviewRenderer.renderSolved(level: level, side: requestedSide)
        case .silhouette:
            image = LevelPreviewRenderer.renderSilhouette(level: level, side: requestedSide)
        }

        guard let image else { return nil }
        previewCache.insert(image, for: cacheKey)
        return image
    }

    private func bundledImage(named assetName: String, subdirectory: String) -> UIImage? {
        guard let url = bundle.url(forResource: assetName, withExtension: "png", subdirectory: subdirectory) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private static func loadLevels(from bundle: Bundle) -> [LevelManifest] {
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Levels") else {
            return []
        }

        let decoder = JSONDecoder()

        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? decoder.decode(LevelManifest.self, from: data) else {
                return nil
            }
            return manifest
        }
        .sorted(by: { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.id < rhs.id
            }
            return lhs.sortOrder < rhs.sortOrder
        })
    }
}

private enum LevelRepositoryPreviewKind: String {
    case thumbnail
    case solved
    case silhouette

    var defaultSide: CGFloat {
        switch self {
        case .thumbnail, .silhouette:
            return 240
        case .solved:
            return 480
        }
    }
}

private struct LevelPreviewCacheKey: Hashable {
    let storageKey: String
    let kind: LevelRepositoryPreviewKind
    let side: CGFloat

    var rawValue: NSString {
        let normalizedSide = Int(side.rounded(.toNearestOrAwayFromZero))
        return "\(storageKey)#\(kind.rawValue)#\(normalizedSide)" as NSString
    }
}

@MainActor
private final class LevelPreviewImageCache {
    static let shared = LevelPreviewImageCache()

    private let storage = NSCache<NSString, UIImage>()

    func image(for key: LevelPreviewCacheKey) -> UIImage? {
        storage.object(forKey: key.rawValue)
    }

    func insert(_ image: UIImage, for key: LevelPreviewCacheKey) {
        storage.setObject(image, forKey: key.rawValue)
    }
}
