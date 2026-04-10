import XCTest
@testable import PixelColoringGame

final class FilledCellsCodecTests: XCTestCase {
    func testRoundTripPreservesIndices() {
        let original: Set<Int> = [0, 2, 5, 9, 23, 44]
        let encoded = FilledCellsCodec.encode(original, cellCount: 48)
        let decoded = FilledCellsCodec.decode(encoded, cellCount: 48)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(FilledCellsCodec.countFilledBits(in: encoded), original.count)
    }
}
