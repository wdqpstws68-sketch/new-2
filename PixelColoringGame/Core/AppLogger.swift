import Foundation
import OSLog

enum AppLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PixelColoringGame",
        category: "Journey"
    )

    static func journeyHomeViewed(currentChapterID: String?) {
        logger.log("journey_home_viewed currentChapter=\(currentChapterID ?? "none", privacy: .public)")
    }

    static func levelStarted(storageKey: String, chapterID: String?) {
        logger.log("level_started storageKey=\(storageKey, privacy: .public) chapter=\(chapterID ?? "none", privacy: .public)")
    }

    static func levelCompleted(storageKey: String, chapterID: String) {
        logger.log("level_completed storageKey=\(storageKey, privacy: .public) chapter=\(chapterID, privacy: .public)")
    }

    static func dailyChallengeOpened(dayKey: String, storageKey: String, eventID: String?) {
        logger.log("daily_opened day=\(dayKey, privacy: .public) storageKey=\(storageKey, privacy: .public) event=\(eventID ?? "none", privacy: .public)")
    }

    static func dailyChallengeCompleted(dayKey: String, storageKey: String, eventID: String?) {
        logger.log("daily_completed day=\(dayKey, privacy: .public) storageKey=\(storageKey, privacy: .public) event=\(eventID ?? "none", privacy: .public)")
    }

    static func eventDetailOpened(eventID: String) {
        logger.log("event_detail_opened event=\(eventID, privacy: .public)")
    }

    static func eventArtworkStarted(eventID: String, storageKey: String) {
        logger.log("event_artwork_started event=\(eventID, privacy: .public) storageKey=\(storageKey, privacy: .public)")
    }

    static func eventArtworkCompleted(eventID: String, storageKey: String) {
        logger.log("event_artwork_completed event=\(eventID, privacy: .public) storageKey=\(storageKey, privacy: .public)")
    }

    static func eventDetailMissing(eventID: String) {
        logger.log("event_detail_missing event=\(eventID, privacy: .public)")
    }

    static func chapterUnlocked(chapterID: String) {
        logger.log("chapter_unlocked chapter=\(chapterID, privacy: .public)")
    }

    static func collectionBookOpened(chapterID: String?) {
        logger.log("collection_book_opened chapter=\(chapterID ?? "none", privacy: .public)")
    }

    static func progressResetApplied(deletedCount: Int) {
        logger.log("progress_reset_applied deletedCount=\(deletedCount, privacy: .public)")
    }

    static func persistenceStoreLoadFailed(error: Error) {
        logger.error("persistence_store_load_failed error=\(String(describing: error), privacy: .public)")
    }

    static func persistenceStoreRecovered(storeURL: URL) {
        logger.log("persistence_store_recovered url=\(storeURL.path(percentEncoded: false), privacy: .public)")
    }

    static func persistenceSaveFailed(reason: String, error: Error) {
        logger.error("persistence_save_failed reason=\(reason, privacy: .public) error=\(String(describing: error), privacy: .public)")
    }

    static func audioBGMLoadFailed(resource: String, error: Error) {
        logger.error("audio_bgm_load_failed resource=\(resource, privacy: .public) error=\(String(describing: error), privacy: .public)")
    }

    static func audioBGMMissing(resource: String) {
        logger.error("audio_bgm_missing resource=\(resource, privacy: .public)")
    }

    static func audioSFXMissing(resource: String) {
        logger.error("audio_sfx_missing resource=\(resource, privacy: .public)")
    }

    static func audioSFXPreloadFailed(resource: String, error: Error) {
        logger.error("audio_sfx_preload_failed resource=\(resource, privacy: .public) error=\(String(describing: error), privacy: .public)")
    }

    static func audioSessionConfigFailed(error: Error) {
        logger.error("audio_session_config_failed error=\(String(describing: error), privacy: .public)")
    }
}
