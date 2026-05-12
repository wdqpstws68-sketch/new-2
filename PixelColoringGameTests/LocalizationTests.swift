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
        let dailyRepository = DailyChallengeRepository(bundle: .main, levelRepository: repository)
        let manifest = journeyRepository.manifest
        let journeyLevels = Set(manifest.chapters.flatMap(\.levelKeys))
        let monthlyLevelKeys = Set(dailyRepository.events.flatMap(\.dailyLevelKeys))
        let monthlyLevels = repository.levels.filter { monthlyLevelKeys.contains($0.storageKey) }
        let otherLevels = repository.levels.filter {
            !journeyLevels.contains($0.storageKey) && !monthlyLevelKeys.contains($0.storageKey)
        }

        XCTAssertEqual(dailyRepository.events.count, 12)
        XCTAssertEqual(dailyRepository.events.reduce(0) { $0 + $1.entries.count }, 366)
        XCTAssertFalse(manifest.chapters.isEmpty)
        XCTAssertEqual(monthlyLevels.count, 366)
        XCTAssertEqual(repository.levels.count, journeyLevels.count + monthlyLevels.count)
        XCTAssertTrue(otherLevels.isEmpty)

        for language in AppLanguage.allCases {
            let localization = makeLocalization(preferredLanguages: [language.rawValue])
            let manifestTitle = manifest.localizedTitle(using: localization)

            XCTAssertNotEqual(manifestTitle, manifest.titleKey)

            for chapter in manifest.chapters {
                XCTAssertNotEqual(chapter.localizedTitle(using: localization), chapter.titleKey)
            }

            for level in repository.levels.filter({ journeyLevels.contains($0.storageKey) }) {
                XCTAssertFalse(level.localizedTitle(using: localization).isEmpty)
                XCTAssertFalse(level.localizedDifficulty(using: localization).isEmpty)
                XCTAssertFalse(level.localizedCategory(using: localization).isEmpty)
            }

            for level in monthlyLevels {
                XCTAssertFalse(level.localizedTitle(using: localization).isEmpty)
                XCTAssertFalse(level.localizedDifficulty(using: localization).isEmpty)
                XCTAssertFalse(level.localizedCategory(using: localization).isEmpty)
            }

            let requiredKeys = [
                "completion.month.headline.cleared",
                "completion.month.headline.perfect",
                "completion.month.detail.return",
                "completion.month.action.return",
                "completion.month.stamp.default",
                "completion.month.stamp.perfect",
                "daily.hero.action.playToday",
                "daily.hero.action.replayPick",
                "daily.hero.action.viewMonth",
                "daily.hero.progress.monthComplete",
                "event.currentMonth",
                "month.detail.reward",
                "month.detail.artworks",
                "month.detail.navigationFallback",
                "month.detail.missing.title",
                "month.detail.missing.subtitle",
                "month.detail.missing.action",
            ]

            for key in requiredKeys {
                XCTAssertNotEqual(localization.string(key), key, "Missing localization for \(language.rawValue): \(key)")
            }

            XCTAssertNotEqual(
                localization.string("completion.month.detail", "Moonflower Glow", "April Daily"),
                "completion.month.detail"
            )
            XCTAssertNotEqual(
                localization.string("collection.events.progress", 3, 31),
                "collection.events.progress"
            )
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
        XCTAssertEqual(localization.string("collection.page.ribbon.incomplete"), "Finish every artwork in this chapter to earn its ribbon.")
        XCTAssertEqual(localization.string("journey.locked.subtitle"), "Unlock this chapter to reveal all of its artworks.")
        XCTAssertEqual(GameSessionStore.Banner.colorCompleted(colorIndex: 0).text(using: localization), "Color 1 complete!")
        XCTAssertTrue(snapshot.collectionRevealState[0].accessibilityLabel(using: localization).contains("Ribbon not earned yet."))
        XCTAssertEqual(localization.string("daily.catalog.title"), "Today's Artwork")
        XCTAssertEqual(localization.string("life.depleted.title"), "No lives left")
        XCTAssertEqual(localization.string("collection.section.daily"), "Daily")
        XCTAssertEqual(localization.string("daily.hero.action.playToday"), "Play Today")
        XCTAssertEqual(localization.string("daily.hero.action.viewMonth"), "View Month")
        XCTAssertEqual(localization.string("daily.hero.progress.monthComplete"), "Monthly Complete")
        XCTAssertEqual(localization.string("completion.month.action.return"), "Back to Month")
        XCTAssertEqual(localization.string("completion.month.detail", "Moonflower Glow", "April Daily"), "You finished Moonflower Glow and advanced April Daily.")
        XCTAssertEqual(localization.string("collection.events.progress", 2, 5), "2/5 complete")
        XCTAssertEqual(localization.string("month.detail.reward"), "Monthly reward")
        XCTAssertEqual(localization.string("badge.streak7.title"), "7-Day Glow")
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
