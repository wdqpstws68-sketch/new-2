import Foundation
import SwiftData

struct JourneyResetResult: Equatable {
    let didApply: Bool
    let deletedCount: Int
    let shouldShowNotice: Bool
}

@MainActor
struct JourneyResetCoordinator {
    static let defaultSchemaVersion = 2
    static let appliedSchemaKey = "journey.reset.applied.schema"
    static let pendingNoticeSchemaKey = "journey.reset.pending.notice.schema"

    private let defaults: UserDefaults
    private let schemaVersion: Int

    init(defaults: UserDefaults = .standard, schemaVersion: Int = defaultSchemaVersion) {
        self.defaults = defaults
        self.schemaVersion = schemaVersion
    }

    func applyIfNeeded(in context: ModelContext) throws -> JourneyResetResult {
        if defaults.integer(forKey: Self.appliedSchemaKey) >= schemaVersion {
            return consumePendingNotice(didApply: false, deletedCount: 0)
        }

        let progressRecords = try context.fetch(FetchDescriptor<LevelProgress>())
        for record in progressRecords {
            context.delete(record)
        }

        if context.hasChanges {
            try context.save()
        }

        defaults.set(schemaVersion, forKey: Self.appliedSchemaKey)
        if !progressRecords.isEmpty {
            defaults.set(schemaVersion, forKey: Self.pendingNoticeSchemaKey)
        }

        AppLogger.progressResetApplied(deletedCount: progressRecords.count)
        return consumePendingNotice(didApply: true, deletedCount: progressRecords.count)
    }

    private func consumePendingNotice(didApply: Bool, deletedCount: Int) -> JourneyResetResult {
        let shouldShowNotice = defaults.integer(forKey: Self.pendingNoticeSchemaKey) == schemaVersion
        if shouldShowNotice {
            defaults.removeObject(forKey: Self.pendingNoticeSchemaKey)
        }

        return JourneyResetResult(
            didApply: didApply,
            deletedCount: deletedCount,
            shouldShowNotice: shouldShowNotice
        )
    }
}
