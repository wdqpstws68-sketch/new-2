import Foundation

extension AppLocalization {
    @MainActor
    static let preview = AppLocalization(
        preferredLanguages: [AppLanguage.english.rawValue],
        persistSelection: false
    )
}
