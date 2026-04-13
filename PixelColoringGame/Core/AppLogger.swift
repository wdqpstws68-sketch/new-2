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

    static func chapterUnlocked(chapterID: String) {
        logger.log("chapter_unlocked chapter=\(chapterID, privacy: .public)")
    }

    static func collectionBookOpened(chapterID: String?) {
        logger.log("collection_book_opened chapter=\(chapterID ?? "none", privacy: .public)")
    }

    static func progressResetApplied(deletedCount: Int) {
        logger.log("progress_reset_applied deletedCount=\(deletedCount, privacy: .public)")
    }
}
