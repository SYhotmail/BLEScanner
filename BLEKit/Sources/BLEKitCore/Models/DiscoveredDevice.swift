import Foundation

/// A BLE device discovered during scanning, as surfaced to the UI layer.
public struct DiscoveredDevice: Identifiable, Equatable, Sendable {
    public var id: UUID { identifier }
    public let identifier: UUID
    public var name: String?
    public var rssi: Int
    public var lastSeenDate: Date
    public var firstSeenDate: Date
    public var isConnectable: Bool
    public var advertisedServiceIdentifiers: [GATTIdentifier]
    public var txPowerLevel: Int?
    public var beacon: BeaconReading?

    public init(
        identifier: UUID,
        name: String? = nil,
        rssi: Int,
        lastSeenDate: Date = .now,
        firstSeenDate: Date? = nil,
        isConnectable: Bool = false,
        advertisedServiceIdentifiers: [GATTIdentifier] = [],
        txPowerLevel: Int? = nil,
        beacon: BeaconReading? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.rssi = rssi
        self.lastSeenDate = lastSeenDate
        self.firstSeenDate = firstSeenDate ?? lastSeenDate
        self.isConnectable = isConnectable
        self.advertisedServiceIdentifiers = advertisedServiceIdentifiers
        self.txPowerLevel = txPowerLevel
        self.beacon = beacon
    }

    /// The heuristic proximity bucket, using the beacon's ranged reading when available
    /// and falling back to an RSSI-only estimate otherwise.
    public var proximity: Proximity {
        if let beacon {
            return beacon.rangedProximity
                ?? ProximityClassifier.classify(rssi: rssi, measuredPower: beacon.measuredPower)
        }
        return ProximityClassifier.classify(rssiOnly: rssi)
    }
}
