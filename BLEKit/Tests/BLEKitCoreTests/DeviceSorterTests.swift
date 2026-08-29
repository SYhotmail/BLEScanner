import Foundation
import Testing
@testable import BLEKitCore

@Suite("DeviceSorter")
struct DeviceSorterTests {
    static let idA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000000")!
    static let idB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000000")!
    static let idC = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000000")!

    static func device(_ id: UUID, rssi: Int, firstSeen: TimeInterval) -> DiscoveredDevice {
        DiscoveredDevice(
            identifier: id,
            name: nil,
            rssi: rssi,
            lastSeenDate: Date(timeIntervalSinceReferenceDate: firstSeen),
            firstSeenDate: Date(timeIntervalSinceReferenceDate: firstSeen)
        )
    }

    @Test("rssi order puts the strongest signal first")
    func rssiOrder() {
        let weak = Self.device(Self.idA, rssi: -90, firstSeen: 0)
        let strong = Self.device(Self.idB, rssi: -40, firstSeen: 100)
        let mid = Self.device(Self.idC, rssi: -65, firstSeen: 50)

        let sorted = DeviceSorter.sorted([weak, strong, mid], by: .rssi)

        #expect(sorted.map(\.rssi) == [-40, -65, -90])
    }

    @Test("appearance order lists devices oldest-first regardless of signal")
    func appearanceOrder() {
        let first = Self.device(Self.idA, rssi: -90, firstSeen: 0)
        let second = Self.device(Self.idB, rssi: -40, firstSeen: 50)
        let third = Self.device(Self.idC, rssi: -65, firstSeen: 100)

        let sorted = DeviceSorter.sorted([third, first, second], by: .appearance)

        #expect(sorted.map(\.id) == [first.id, second.id, third.id])
    }

    @Test("appearance order breaks firstSeenDate ties on the identifier, deterministically")
    func appearanceOrderTieBreak() {
        let a = Self.device(Self.idA, rssi: -50, firstSeen: 10)
        let b = Self.device(Self.idB, rssi: -50, firstSeen: 10)

        #expect(DeviceSorter.sorted([b, a], by: .appearance).map(\.id) == [a.id, b.id])
        #expect(DeviceSorter.sorted([a, b], by: .appearance).map(\.id) == [a.id, b.id])
    }
}
