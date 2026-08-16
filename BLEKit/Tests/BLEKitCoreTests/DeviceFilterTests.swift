import Foundation
import Testing
@testable import BLEKitCore

@Suite("DeviceFilter")
struct DeviceFilterTests {
    static func device(name: String? = "Sensor Tag", identifier: UUID = UUID(), rssi: Int = -60) -> DiscoveredDevice {
        DiscoveredDevice(identifier: identifier, name: name, rssi: rssi)
    }

    @Test("an all-disabled filter matches everything")
    func allDisabledMatchesEverything() {
        let device = Self.device(name: nil, rssi: -100)
        #expect(DeviceFilter.matches(device, criteria: .default))
    }

    @Test("name filter matches case-insensitive substrings")
    func nameFilterCaseInsensitiveSubstring() {
        let device = Self.device(name: "Living Room Sensor")
        var criteria = FilterCriteria.default
        criteria.isNameFilterEnabled = true
        criteria.nameQuery = "room"
        #expect(DeviceFilter.matches(device, criteria: criteria))

        criteria.nameQuery = "kitchen"
        #expect(!DeviceFilter.matches(device, criteria: criteria))
    }

    @Test("name filter excludes devices with no name")
    func nameFilterExcludesNilName() {
        let device = Self.device(name: nil)
        var criteria = FilterCriteria.default
        criteria.isNameFilterEnabled = true
        criteria.nameQuery = "anything"
        #expect(!DeviceFilter.matches(device, criteria: criteria))
    }

    @Test("identifier filter matches a substring of the device UUID")
    func identifierFilterSubstring() {
        let identifier = UUID(uuidString: "12345678-ABCD-4EF0-9012-345678ABCDEF")!
        let device = Self.device(identifier: identifier)
        var criteria = FilterCriteria.default
        criteria.isIdentifierFilterEnabled = true
        criteria.identifierQuery = "abcd"
        #expect(DeviceFilter.matches(device, criteria: criteria))

        criteria.identifierQuery = "ffffff"
        #expect(!DeviceFilter.matches(device, criteria: criteria))
    }

    @Test(
        "RSSI filter is inclusive at the boundary",
        arguments: [(rssi: -60, minimum: -60, expected: true), (rssi: -61, minimum: -60, expected: false), (rssi: -59, minimum: -60, expected: true)]
    )
    func rssiFilterBoundary(rssi: Int, minimum: Int, expected: Bool) {
        let device = Self.device(rssi: rssi)
        var criteria = FilterCriteria.default
        criteria.isRSSIFilterEnabled = true
        criteria.minimumRSSI = minimum
        #expect(DeviceFilter.matches(device, criteria: criteria) == expected)
    }

    @Test("combined filters use AND semantics")
    func combinedFiltersUseAndSemantics() {
        let device = Self.device(name: "Beacon A", rssi: -40)
        var criteria = FilterCriteria.default
        criteria.isNameFilterEnabled = true
        criteria.nameQuery = "Beacon"
        criteria.isRSSIFilterEnabled = true
        criteria.minimumRSSI = -50
        #expect(DeviceFilter.matches(device, criteria: criteria))

        criteria.minimumRSSI = -30
        #expect(!DeviceFilter.matches(device, criteria: criteria))
    }
}
