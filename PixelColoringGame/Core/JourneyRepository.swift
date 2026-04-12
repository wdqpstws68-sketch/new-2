import Foundation

@MainActor
struct JourneyRepository {
    let bundle: Bundle
    let manifest: JourneyManifest
    let catalog: JourneyCatalog

    init(bundle: Bundle = .main, levelRepository: LevelRepository? = nil) {
        let resolvedLevelRepository = levelRepository ?? LevelRepository(bundle: bundle)
        let resolvedManifest = Self.loadManifest(from: bundle) ?? Self.fallbackManifest(from: resolvedLevelRepository.levels)

        self.bundle = bundle
        self.manifest = resolvedManifest
        self.catalog = JourneyCatalog(manifest: resolvedManifest, levels: resolvedLevelRepository.levels)
    }

    init(bundle: Bundle = .main, manifest: JourneyManifest, levelRepository: LevelRepository) {
        self.bundle = bundle
        self.manifest = manifest
        self.catalog = JourneyCatalog(manifest: manifest, levels: levelRepository.levels)
    }

    func chapter(id: String) -> JourneyCatalogChapter? {
        catalog.chapter(id: id)
    }

    func chapter(containingLevelStorageKey storageKey: String) -> JourneyCatalogChapter? {
        catalog.chapter(containingLevelStorageKey: storageKey)
    }

    func level(storageKey: String) -> LevelManifest? {
        catalog.level(storageKey: storageKey)
    }

    private static func loadManifest(from bundle: Bundle) -> JourneyManifest? {
        guard let url = bundle.url(forResource: "journey", withExtension: "json", subdirectory: "Journey"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(JourneyManifest.self, from: data)
    }

    private static func fallbackManifest(from levels: [LevelManifest]) -> JourneyManifest {
        let orderedLevels = levels.sorted(by: { $0.sortOrder < $1.sortOrder })
        let chapterPairs = stride(from: 0, to: orderedLevels.count, by: 2).map {
            Array(orderedLevels[$0 ..< min($0 + 2, orderedLevels.count)])
        }

        let accentColors = ["FF8A2A", "5DD64D", "7C6E98", "F6B35F", "F18FB5"]
        let chapters = chapterPairs.enumerated().map { index, chapterLevels in
            JourneyChapter(
                id: "chapter-\(index + 1)",
                titleKey: "journey.fallback.chapter.\(index + 1).title",
                subtitleKey: "journey.fallback.chapter.subtitle",
                accentHex: accentColors[index % accentColors.count],
                badgeTitleKey: "journey.fallback.chapter.badge",
                levelKeys: chapterLevels.map(\.storageKey)
            )
        }

        return JourneyManifest(
            schemaVersion: 1,
            titleKey: "journey.fallback.title",
            subtitleKey: "journey.fallback.subtitle",
            collectionTitleKey: "journey.fallback.collectionTitle",
            chapters: chapters
        )
    }
}
