import Foundation
import Testing
@testable import BLEKitCore

@Suite("GATTModels")
struct GATTModelsTests {
    @Test("GATTService.displayName prefers an explicitly discovered name")
    func serviceDisplayNamePrefersExplicitName() {
        let service = GATTService(identifier: GATTIdentifier(rawValue: "180D"), name: "Custom Label")
        #expect(service.displayName == "Custom Label")
    }

    @Test("GATTService.displayName falls back to the Bluetooth SIG name")
    func serviceDisplayNameUsesSIGName() {
        let service = GATTService(identifier: GATTIdentifier(rawValue: "180D"))
        #expect(service.displayName == "Heart Rate")
    }

    @Test("GATTService.displayName falls back to the raw UUID for a vendor service")
    func serviceDisplayNameUsesRawUUID() {
        let identifier = GATTIdentifier(rawValue: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        let service = GATTService(identifier: identifier)
        #expect(service.displayName == identifier.rawValue)
    }

    @Test("GATTCharacteristic.displayName resolves the same three ways")
    func characteristicDisplayName() {
        let explicit = GATTCharacteristic(
            identifier: GATTIdentifier(rawValue: "2A19"),
            name: "My Battery",
            properties: .read
        )
        #expect(explicit.displayName == "My Battery")

        let sig = GATTCharacteristic(identifier: GATTIdentifier(rawValue: "2A19"), properties: .read)
        #expect(sig.displayName == "Battery Level")

        let vendorIdentifier = GATTIdentifier(rawValue: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
        let vendor = GATTCharacteristic(identifier: vendorIdentifier, properties: .notify)
        #expect(vendor.displayName == vendorIdentifier.rawValue)
    }
}
