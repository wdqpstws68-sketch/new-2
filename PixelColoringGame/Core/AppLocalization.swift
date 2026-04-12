import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case japanese = "ja"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case spanish = "es"
    case german = "de"
    case french = "fr"
    case korean = "ko"

    static let storageKey = "selectedAppLanguageCode"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        case .spanish:
            return "Español"
        case .german:
            return "Deutsch"
        case .french:
            return "Français"
        case .korean:
            return "한국어"
        }
    }

    var badgeLabel: String {
        switch self {
        case .english:
            return "EN"
        case .japanese:
            return "JA"
        case .simplifiedChinese:
            return "简"
        case .traditionalChinese:
            return "繁"
        case .spanish:
            return "ES"
        case .german:
            return "DE"
        case .french:
            return "FR"
        case .korean:
            return "KO"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func bestMatch(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            if let match = match(languageIdentifier: identifier) {
                return match
            }
        }

        return .english
    }

    static func match(languageIdentifier: String) -> AppLanguage? {
        let normalized = languageIdentifier.replacingOccurrences(of: "_", with: "-")

        if normalized.hasPrefix("ja") {
            return .japanese
        }

        if normalized == "zh-Hant"
            || normalized.hasPrefix("zh-TW")
            || normalized.hasPrefix("zh-HK")
            || normalized.hasPrefix("zh-MO") {
            return .traditionalChinese
        }

        if normalized == "zh-Hans"
            || normalized.hasPrefix("zh-CN")
            || normalized.hasPrefix("zh-SG")
            || normalized.hasPrefix("zh") {
            return .simplifiedChinese
        }

        if normalized.hasPrefix("es") {
            return .spanish
        }

        if normalized.hasPrefix("de") {
            return .german
        }

        if normalized.hasPrefix("fr") {
            return .french
        }

        if normalized.hasPrefix("ko") {
            return .korean
        }

        if normalized.hasPrefix("en") {
            return .english
        }

        return nil
    }
}

@Observable
final class AppLocalization {
    private let defaults: UserDefaults
    private let sourceBundle: Bundle
    private let persistSelection: Bool

    var language: AppLanguage {
        didSet {
            guard persistSelection, language != oldValue else { return }
            defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages,
        bundle: Bundle = .main,
        persistSelection: Bool = true
    ) {
        self.defaults = defaults
        self.sourceBundle = bundle
        self.persistSelection = persistSelection

        if let stored = defaults.string(forKey: AppLanguage.storageKey),
           let storedLanguage = AppLanguage(rawValue: stored) {
            self.language = storedLanguage
        } else {
            self.language = AppLanguage.bestMatch(preferredLanguages: preferredLanguages)
        }
    }

    var locale: Locale {
        language.locale
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
    }

    func string(_ key: String) -> String {
        resolvedString(for: key)
    }

    func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = resolvedString(for: key)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private func resolvedString(for key: String) -> String {
        let localized = localizedBundle.localizedString(forKey: key, value: key, table: nil)
        if localized != key {
            return localized
        }

        return englishBundle.localizedString(forKey: key, value: key, table: nil)
    }

    private var localizedBundle: Bundle {
        sourceBundle.localizedBundle(for: language)
    }

    private var englishBundle: Bundle {
        sourceBundle.localizedBundle(for: .english)
    }
}

private extension Bundle {
    func localizedBundle(for language: AppLanguage) -> Bundle {
        guard let path = path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return self
        }

        return bundle
    }
}
