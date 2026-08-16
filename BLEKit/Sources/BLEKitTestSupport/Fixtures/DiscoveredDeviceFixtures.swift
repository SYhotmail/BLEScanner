import BLEKitCore
import Foundation

public enum DiscoveredDeviceFixtures {
    public static let plainSensor = DiscoveredDevice(
        identifier: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Living Room Sensor",
        rssi: -55
    )

    public static let weakSignalDevice = DiscoveredDevice(
        identifier: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "Garage Sensor",
        rssi: -88
    )

    public static let unnamedDevice = DiscoveredDevice(
        identifier: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        name: nil,
        rssi: -70
    )

    public static let iBeaconDevice = DiscoveredDevice(
        identifier: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        name: "Estimote Beacon",
        rssi: -60,
        beacon: BeaconReading(
            uuid: UUID(uuidString: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")!,
            major: 1,
            minor: 2,
            measuredPower: -59
        )
    )

    public static let all: [DiscoveredDevice] = [plainSensor, weakSignalDevice, unnamedDevice, iBeaconDevice]
}
