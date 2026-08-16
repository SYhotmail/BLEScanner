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

    public static let batteryService = GATTService(
        identifier: GATTIdentifier(rawValue: "180F"),
        name: "Battery Service",
        characteristics: [batteryLevelCharacteristic]
    )

    public static let genericAccessService = GATTService(
        identifier: GATTIdentifier(rawValue: "1800"),
        name: "Generic Access",
        characteristics: [deviceNameCharacteristic]
    )

    public static let allServices: [GATTService] = [genericAccessService, batteryService]
}
