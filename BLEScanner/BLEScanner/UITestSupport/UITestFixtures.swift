#if DEBUG
import BLEKitCore
import BLEKitHardware
import Foundation

/// Canned data the app seeds itself with when launched with `-UITesting`, since XCUITest
/// drives a separate process and can't reach into this app's fake dependency instances.
enum UITestFixtures {
    static let sensorIdentifier = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let sensorAdvertisement = BLEAdvertisement(
        identifier: sensorIdentifier,
        name: "Living Room Sensor",
        rssi: -55,
        isConnectable: true,
        serviceIdentifiers: [],
        manufacturerData: nil
    )

    static let garageIdentifier = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let garageAdvertisement = BLEAdvertisement(
        identifier: garageIdentifier,
        name: "Garage Sensor",
        rssi: -80,
        isConnectable: true,
        serviceIdentifiers: [],
        manufacturerData: nil
    )

    static let batteryCharacteristic = GATTCharacteristic(
        identifier: GATTIdentifier(rawValue: "2A19"),
        name: "Battery Level",
        properties: [.read, .notify]
    )

    static let batteryService = GATTService(
        identifier: GATTIdentifier(rawValue: "180F"),
        name: "Battery Service",
        characteristics: [batteryCharacteristic]
    )

    static let services: [GATTService] = [batteryService]
}
#endif
