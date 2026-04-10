import Foundation

enum FilledCellsCodec {
    static func encode(_ filledIndices: Set<Int>, cellCount: Int) -> Data {
        guard cellCount > 0 else { return Data() }

        var bytes = Array(repeating: UInt8.zero, count: (cellCount + 7) / 8)

        for index in filledIndices where index >= 0 && index < cellCount {
            let byteIndex = index / 8
            let bitIndex = index % 8
            bytes[byteIndex] |= 1 << bitIndex
        }

        return Data(bytes)
    }

    static func decode(_ data: Data, cellCount: Int) -> Set<Int> {
        guard cellCount > 0 else { return [] }

        var result = Set<Int>()
        let bytes = Array(data)

        for index in 0..<cellCount {
            let byteIndex = index / 8
            guard byteIndex < bytes.count else { break }

            let bitIndex = index % 8
            let mask = UInt8(1 << bitIndex)
            if bytes[byteIndex] & mask != 0 {
                result.insert(index)
            }
        }

        return result
    }

    static func countFilledBits(in data: Data) -> Int {
        data.reduce(0) { partialResult, byte in
            partialResult + Int(byte.nonzeroBitCount)
        }
    }
}
