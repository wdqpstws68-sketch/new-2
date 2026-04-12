import XCTest
@testable import PixelColoringGame

final class LocalizationTests: XCTestCase {
    func testAppLanguageMatchesPreferredLanguageIdentifiers() {
        XCTAssertEqual(AppLanguage.match(languageIdentifier: "ja-JP"), .japanese)
        XCTAssertEqual(AppLanguage.match(languageIdentifier: "zh-Hans-CN"), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.match(languageIdentifier: "zh-HK"), .traditionalChinese)
        XCTAssertEqual(AppLanguage.match(languageIdentifier: "es-MX"), .spanish)
        XCTAssertEqual(AppLanguage.match(languageIdentifier: "de-DE"), .german)
        XCTAssertEqual(AppLanguage.match(languageIdentifier: "fr-FR"), .french)
        XCTAssertEqual(AppLanguage.match(languageIdentifier: "ko-KR"), .korean)
        XCTAssertEqual(AppLanguage.match(languageIdentifier: "en-US"), .english)
    }

    func testUnsupportedPreferredLanguageFallsBackToEnglish() {
        let localization = makeLocalization(preferredLanguages: ["it-IT"])
        XCTAssertEqual(localization.language, .english)
    }

    func testSelectedLanguagePersistsAcrossInstances() {
        let defaults = makeDefaults()
        let first = AppLocalization(
            defaults: defaults,
            preferredLanguages: [AppLanguage.english.rawValue],
            persistSelection: true
        )

        first.setLanguage(.french)

        let second = AppLocalization(
            defaults: defaults,
            preferredLanguages: [AppLanguage.english.rawValue],
            persistSelection: false
        )
        XCTAssertEqual(second.language, .french)
    }

    @MainActor
    func testLocalizedResourcesResolveForAllSupportedLanguages() throws {
        let repository = LevelRepository(bundle: .main)
        let journeyRepository = JourneyRepository(bundle: .main, levelRepository: repository)
        let manifest = journeyRepository.manifest
        let firstLevelCandidate = repository.levels.first
        let firstChapterCandidate = manifest.chapters.first
        let firstLevel = try XCTUnwrap(firstLevelCandidate)
        let firstChapter = try XCTUnwrap(firstChapterCandidate)

        for language in AppLanguage.allCases {
            let localization = makeLocalization(preferredLanguages: [language.rawValue])
            let manifestTitle = manifest.localizedTitle(using: localization)
            let chapterTitle = firstChapter.localizedTitle(using: localization)
            let levelTitle = firstLevel.localizedTitle(using: localization)
            let difficultyTitle = firstLevel.localizedDifficulty(using: localization)
            let categoryTitle = firstLevel.localizedCategory(using: localization)

            XCTAssertNotEqual(manifestTitle, manifest.titleKey)
            XCTAssertNotEqual(chapterTitle, firstChapter.titleKey)
            XCTAssertNotEqual(levelTitle, firstLevel.titleKey)
            XCTAssertNotEqual(difficultyTitle, firstLevel.difficultyKey)
            XCTAssertNotEqual(categoryTitle, firstLevel.categoryKey)
        }
    }

    func testLocalizedDisplayStringsCoverCtaProgressBannerAndAccessibility() throws {
        let localization = makeLocalization(preferredLanguages: [AppLanguage.english.rawValue])
        let level = makeLevel(id: "alpha", titleKey: "level.alpha.title", sortOrder: 1)
        let chapter = JourneyChapter(
            id: "chapter-1",
            titleKey: "journey.test.chapter.one.title",
            subtitleKey: "journey.test.chapter.one.subtitle",
            accentHex: "FF8A2A",
            badgeTitleKey: "journey.test.chapter.one.badge",
            levelKeys: [level.storageKey]
        )
        let manifest = JourneyManifest(
            schemaVersion: 2,
            titleKey: "journey.test.title",
            subtitleKey: "journey.test.subtitle",
            collectionTitleKey: "journey.test.collectionTitle",
            chapters: [chapter]
        )
        let catalog = JourneyCatalog(manifest: manifest, levels: [level])
        let snapshot = JourneyProgressSnapshot(
            catalog: catalog,
            progressValues: [
                level.storageKey: JourneyLevelProgressValue(
                    filledCellCount: 2,
                    completedAt: nil,
                    updatedAt: .now
                )
            ]
        )

        let chapterProgress = try XCTUnwrap(snapshot.chapter(id: "chapter-1"))
        XCTAssertEqual(localization.string(snapshot.primaryCTA.buttonTitleKey), "Continue Current Chapter")
        XCTAssertEqual(chapterProgress.progressLabel(using: localization), "0/1 artworks complete")
        XCTAssertNil(chapterProgress.lockReason(using: localization))
        XCTAssertEqual(GameSessionStore.Banner.colorCompleted(colorIndex: 0).text(using: localization), "Color 1 complete!")
        XCTAssertTrue(snapshot.collectionRevealState[0].accessibilityLabel(using: localization).contains("Ribbon not earned yet."))
    }

    private func makeLocalization(preferredLanguages: [String]) -> AppLocalization {
        AppLocalization(
            defaults: makeDefaults(),
            preferredLanguages: preferredLanguages,
            bundle: .main,
            persistSelection: false
        )
    }

    private func makeLevel(id: String, titleKey: String, sortOrder: Int) -> LevelManifest {
        LevelManifest(
            schemaVersion: 2,
            id: id,
            levelVersion: 1,
            titleKey: titleKey,
            prompt: titleKey,
            boardWidth: 2,
            boardHeight: 2,
            difficultyKey: "level.difficulty.easy",
            estimatedMinutes: 3,
            sortOrder: sortOrder,
            categoryKey: "level.category.test",
            paintableCellCount: 4,
            palette: [
                LevelPaletteEntry(index: 0, hex: "#FF0000", targetCellCount: 4)
            ],
            cells: [0, 0, 0, 0],
            perColorCellIndices: [
                LevelColorCellIndexGroup(index: 0, cellIndices: [0, 1, 2, 3])
            ],
            thumbnailAsset: "\(id)-thumb",
            solvedAsset: "\(id)-solved"
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
