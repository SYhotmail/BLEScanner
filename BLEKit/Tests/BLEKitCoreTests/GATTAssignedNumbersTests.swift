import Foundation
import Testing
@testable import BLEKitCore

@Suite("GATTAssignedNumbers")
struct GATTAssignedNumbersTests {
    @Test(
        "assignedNumber accepts the 16-bit, 32-bit, and SIG-base 128-bit forms of the same UUID",
        arguments: [
            "180D",
            "0000180D",
            "0000180D-0000-1000-8000-00805F9B34FB",
        ]
    )
    func assignedNumberNormalizesWidths(rawValue: String) {
        #expect(GATTAssignedNumbers.assignedNumber(for: GATTIdentifier(rawValue: rawValue)) == 0x180D)
    }

    @Test("assignedNumber returns nil for a vendor UUID that is not on the SIG base")
    func assignedNumberRejectsVendorUUID() {
        #expect(GATTAssignedNumbers.assignedNumber(for: GATTIdentifier(rawValue: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")) == nil)
    }

    @Test("serviceName resolves adopted service UUIDs and returns nil otherwise")
    func serviceNameLookup() {
        #expect(GATTAssignedNumbers.serviceName(for: GATTIdentifier(rawValue: "180D")) == "Heart Rate")
        #expect(GATTAssignedNumbers.serviceName(for: GATTIdentifier(rawValue: "180F")) == "Battery")
        #expect(GATTAssignedNumbers.serviceName(for: GATTIdentifier(rawValue: "FFF0")) == nil)
    }

    @Test("characteristicName resolves adopted characteristic UUIDs")
    func characteristicNameLookup() {
        #expect(GATTAssignedNumbers.characteristicName(for: GATTIdentifier(rawValue: "2A19")) == "Battery Level")
        #expect(GATTAssignedNumbers.characteristicName(for: GATTIdentifier(rawValue: "2A00")) == "Device Name")
    }

    @Test("descriptorName resolves adopted descriptor UUIDs")
    func descriptorNameLookup() {
        #expect(
            GATTAssignedNumbers.descriptorName(for: GATTIdentifier(rawValue: "2902"))
                == "Client Characteristic Configuration"
        )
    }

    @Test(
        "well-known UUIDs keep their published names, guarding against a bad table regeneration",
        arguments: [
            (raw: "1800", expected: "GAP"),
            (raw: "1801", expected: "GATT"),
            (raw: "180A", expected: "Device Information"),
            (raw: "181A", expected: "Environmental Sensing"),
        ]
    )
    func fixedRegressionNames(raw: String, expected: String) {
        #expect(GATTAssignedNumbers.serviceName(for: GATTIdentifier(rawValue: raw)) == expected)
    }
}
