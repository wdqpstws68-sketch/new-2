import Foundation
import UIKit

@MainActor
struct LevelRepository {
    let bundle: Bundle
    let levels: [LevelManifest]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        self.levels = Self.loadLevels(from: bundle)
    }

    func thumbnailImage(for level: LevelManifest) -> UIImage? {
        bundledImage(named: level.thumbnailAsset, subdirectory: "Resources/GeneratedThumbnails")
            ?? LevelPreviewRenderer.renderSolved(level: level, side: 240)
    }

    func solvedImage(for level: LevelManifest) -> UIImage? {
        bundledImage(named: level.solvedAsset, subdirectory: "Resources/GeneratedSolved")
            ?? LevelPreviewRenderer.renderSolved(level: level, side: 480)
    }

    private func bundledImage(named assetName: String, subdirectory: String) -> UIImage? {
        guard let url = bundle.url(forResource: assetName, withExtension: "png", subdirectory: subdirectory) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private static func loadLevels(from bundle: Bundle) -> [LevelManifest] {
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Resources/Levels") else {
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
                return lhs.title < rhs.title
            }
            return lhs.sortOrder < rhs.sortOrder
        })
    }
}
