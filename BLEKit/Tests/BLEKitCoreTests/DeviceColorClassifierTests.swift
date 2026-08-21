import Foundation
import Testing
@testable import BLEKitCore

@Suite("DeviceColorClassifier")
struct DeviceColorClassifierTests {
    @Test("hueBucketIndex is deterministic across repeated calls")
    func deterministic() {
        let identifier = UUID()
        let first = DeviceColorClassifier.hueBucketIndex(for: identifier)
        let second = DeviceColorClassifier.hueBucketIndex(for: identifier)
        #expect(first == second)
    }

    @Test("hueBucketIndex always stays within [0, hueBucketCount)")
    func withinRange() {
        for _ in 0..<200 {
            let bucket = DeviceColorClassifier.hueBucketIndex(for: UUID())
            #expect(bucket >= 0)
            #expect(bucket < DeviceColorClassifier.hueBucketCount)
        }
    }

    @Test(
        "hueBucketIndex matches a fixed FNV-1a hash for known UUIDs, guarding against silent algorithm drift",
        arguments: [
            (uuid: "00000000-0000-0000-0000-000000000001", expectedBucket: 10),
            (uuid: "12345678-1234-1234-1234-123456789ABC", expectedBucket: 17),
            (uuid: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF", expectedBucket: 13),
        ]
    )
    func fixedRegressionValues(uuid: String, expectedBucket: Int) {
        let identifier = UUID(uuidString: uuid)!
        #expect(DeviceColorClassifier.hueBucketIndex(for: identifier) == expectedBucket)
    }

    @Test("hueFraction is hueBucketIndex scaled into [0, 1)")
    func hueFractionMatchesBucketIndex() {
        let identifier = UUID()
        let expected = Double(DeviceColorClassifier.hueBucketIndex(for: identifier))
            / Double(DeviceColorClassifier.hueBucketCount)
        #expect(DeviceColorClassifier.hueFraction(for: identifier) == expected)
    }
}
