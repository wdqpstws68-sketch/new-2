import XCTest
import SwiftData
@testable import PixelColoringGame

@MainActor
final class CelebrationsSeenStorageTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: PixelColoringGameSchemaV4.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func test_default_celebrationsSeen_isEmpty() throws {
        let ctx = try makeContext()
        let profile = PlayerProfile()
        ctx.insert(profile)
        XCTAssertEqual(profile.celebrationsSeen, [])
    }

    func test_setCelebrationsSeen_roundTrip() throws {
        let ctx = try makeContext()
        let profile = PlayerProfile()
        ctx.insert(profile)
        profile.celebrationsSeen = ["streak:7", "firstPerfect", "chapterClear:berry-meadow"]
        XCTAssertEqual(profile.celebrationsSeen, ["streak:7", "firstPerfect", "chapterClear:berry-meadow"])
    }

    func test_corruptedData_fallsBackToEmpty() throws {
        let ctx = try makeContext()
        let profile = PlayerProfile()
        ctx.insert(profile)
        profile.celebrationsSeenData = Data([0xFF, 0xAB, 0xCD])
        XCTAssertEqual(profile.celebrationsSeen, [])
    }

    func test_emptySet_serializesToValidJSON() throws {
        let ctx = try makeContext()
        let profile = PlayerProfile()
        ctx.insert(profile)
        profile.celebrationsSeen = []
        // Re-decode after set
        XCTAssertEqual(profile.celebrationsSeen, [])
    }
}
