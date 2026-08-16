import Foundation
import Testing
@testable import BLEKitCore

@Suite("ProximityClassifier")
struct ProximityClassifierTests {
    @Test(
        "classifies beacon readings by estimated distance",
        arguments: [
            (rssi: -50, measuredPower: Int8(-59), expected: Proximity.immediate), // ~0.35m
            (rssi: -59, measuredPower: Int8(-59), expected: Proximity.near), // exactly 1m
            (rssi: -65, measuredPower: Int8(-59), expected: Proximity.near),
            (rssi: -90, measuredPower: Int8(-59), expected: Proximity.far),
            (rssi: 0, measuredPower: Int8(-59), expected: Proximity.unknown),
        ]
    )
    func classifiesBeaconReadings(rssi: Int, measuredPower: Int8, expected: Proximity) {
        #expect(ProximityClassifier.classify(rssi: rssi, measuredPower: measuredPower) == expected)
    }

    @Test("classify(rssi:measuredPower:) is unknown without a measured power")
    func unknownWithoutMeasuredPower() {
        #expect(ProximityClassifier.classify(rssi: -50, measuredPower: nil) == .unknown)
    }

    @Test(
        "classifies plain devices by RSSI threshold only",
        arguments: [
            (rssi: -40, expected: Proximity.immediate),
            (rssi: -50, expected: Proximity.immediate),
            (rssi: -51, expected: Proximity.near),
            (rssi: -74, expected: Proximity.near),
            (rssi: -75, expected: Proximity.near),
            (rssi: -76, expected: Proximity.far),
            (rssi: -95, expected: Proximity.far),
            (rssi: 0, expected: Proximity.unknown),
        ]
    )
    func classifiesRSSIOnly(rssi: Int, expected: Proximity) {
        #expect(ProximityClassifier.classify(rssiOnly: rssi) == expected)
    }

    @Test("a ranged proximity always supersedes the heuristic")
    func rangedResultSupersedesHeuristic() {
        #expect(ProximityClassifier.merge(heuristic: .far, ranged: .immediate) == .immediate)
        #expect(ProximityClassifier.merge(heuristic: .far, ranged: nil) == .far)
    }
}
