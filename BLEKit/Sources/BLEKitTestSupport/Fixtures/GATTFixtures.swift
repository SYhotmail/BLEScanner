import BLEKitCore
import Foundation

public enum GATTFixtures {
    public static let batteryLevelCharacteristic = GATTCharacteristic(
        identifier: GATTIdentifier(rawValue: "2A19"),
        name: "Battery Level",
        properties: [.read, .notify],
        latestValue: Data([0x64])
    )

    public static let deviceNameCharacteristic = GATTCharacteristic(
        identifier: GATTIdentifier(rawValue: "2A00"),
        name: "Device Name",
        properties: [.read, .write],
        latestValue: Data("BLEScanner Fixture".utf8)
    )

    public static let txPowerLevelCharacteristic = GATTCharacteristic(
        identifier: GATTIdentifier(rawValue: "2A07"),
        name: "Tx Power Level",
        properties: [.read],
        latestValue: Data([0x04])
    )

    public static let batteryService = GATTService(
        identifier: GATTIdentifier(rawValue: "180F"),
        name: "Battery Service",
        characteristics: [batteryLevelCharacteristic]
    )

    /// A secondary service referenced by `genericAccessService` via GATT service inclusion.
    public static let txPowerService = GATTService(
        identifier: GATTIdentifier(rawValue: "1804"),
        name: "Tx Power",
        characteristics: [txPowerLevelCharacteristic]
    )

    public static let genericAccessService = GATTService(
        identifier: GATTIdentifier(rawValue: "1800"),
        name: "Generic Access",
        characteristics: [deviceNameCharacteristic],
        includedServices: [txPowerService]
    )

    public static let allServices: [GATTService] = [genericAccessService, batteryService]
}
