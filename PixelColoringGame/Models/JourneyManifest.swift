import Foundation
import SwiftUI

struct JourneyManifest: Decodable, Hashable {
    let schemaVersion: Int
    let titleKey: String
    let subtitleKey: String
    let collectionTitleKey: String
    let chapters: [JourneyChapter]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case title
        case titleKey
        case subtitle
        case subtitleKey
        case collectionTitle
        case collectionTitleKey
        case chapters
    }

    init(
        schemaVersion: Int,
        titleKey: String,
        subtitleKey: String,
        collectionTitleKey: String,
        chapters: [JourneyChapter]
    ) {
        self.schemaVersion = schemaVersion
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.collectionTitleKey = collectionTitleKey
        self.chapters = chapters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        titleKey = try container.decodeIfPresent(String.self, forKey: .titleKey)
            ?? container.decode(String.self, forKey: .title)
        subtitleKey = try container.decodeIfPresent(String.self, forKey: .subtitleKey)
            ?? container.decode(String.self, forKey: .subtitle)
        collectionTitleKey = try container.decodeIfPresent(String.self, forKey: .collectionTitleKey)
            ?? container.decode(String.self, forKey: .collectionTitle)
        chapters = try container.decode([JourneyChapter].self, forKey: .chapters)
    }

    func localizedTitle(using localization: AppLocalization) -> String {
        localization.string(titleKey)
    }

    func localizedSubtitle(using localization: AppLocalization) -> String {
        localization.string(subtitleKey)
    }

    func localizedCollectionTitle(using localization: AppLocalization) -> String {
        localization.string(collectionTitleKey)
    }
}

struct JourneyChapter: Decodable, Hashable, Identifiable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let accentHex: String
    let badgeTitleKey: String
    let levelKeys: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case titleKey
        case subtitle
        case subtitleKey
        case accentHex
        case badgeTitle
        case badgeTitleKey
        case levelKeys
    }

    init(
        id: String,
        titleKey: String,
        subtitleKey: String,
        accentHex: String,
        badgeTitleKey: String,
        levelKeys: [String]
    ) {
        self.id = id
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.accentHex = accentHex
        self.badgeTitleKey = badgeTitleKey
        self.levelKeys = levelKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        titleKey = try container.decodeIfPresent(String.self, forKey: .titleKey)
            ?? container.decode(String.self, forKey: .title)
        subtitleKey = try container.decodeIfPresent(String.self, forKey: .subtitleKey)
            ?? container.decode(String.self, forKey: .subtitle)
        accentHex = try container.decode(String.self, forKey: .accentHex)
        badgeTitleKey = try container.decodeIfPresent(String.self, forKey: .badgeTitleKey)
            ?? container.decode(String.self, forKey: .badgeTitle)
        levelKeys = try container.decode([String].self, forKey: .levelKeys)
    }

    var accentColor: Color {
        Color(hex: accentHex)
    }

    func localizedTitle(using localization: AppLocalization) -> String {
        localization.string(titleKey)
    }

    func localizedSubtitle(using localization: AppLocalization) -> String {
        localization.string(subtitleKey)
    }

    func localizedBadgeTitle(using localization: AppLocalization) -> String {
        localization.string(badgeTitleKey)
    }
}

struct JourneyCatalog: Hashable {
    let manifest: JourneyManifest
    let chapters: [JourneyCatalogChapter]
    let levelsByKey: [String: LevelManifest]

    init(manifest: JourneyManifest, levels: [LevelManifest]) {
        self.manifest = manifest

        let levelLookup = Dictionary(uniqueKeysWithValues: levels.map { ($0.storageKey, $0) })
        self.levelsByKey = levelLookup
        self.chapters = manifest.chapters.map { chapter in
            let resolvedLevels = chapter.levelKeys.compactMap { key in
                levelLookup[key]
            }

            let missingLevelKeys = Set(chapter.levelKeys).subtracting(resolvedLevels.map(\.storageKey))
            if !missingLevelKeys.isEmpty {
                assertionFailure("Journey chapter \(chapter.id) is missing level keys: \(missingLevelKeys)")
            }

            return JourneyCatalogChapter(chapter: chapter, levels: resolvedLevels)
        }
    }

    func chapter(id: String) -> JourneyCatalogChapter? {
        chapters.first(where: { $0.id == id })
    }

    func chapter(containingLevelStorageKey storageKey: String) -> JourneyCatalogChapter? {
        chapters.first(where: { chapter in
            chapter.levels.contains(where: { $0.storageKey == storageKey })
        })
    }

    func level(storageKey: String) -> LevelManifest? {
        levelsByKey[storageKey]
    }
}

struct JourneyCatalogChapter: Identifiable, Hashable {
    let chapter: JourneyChapter
    let levels: [LevelManifest]

    var id: String { chapter.id }
}
