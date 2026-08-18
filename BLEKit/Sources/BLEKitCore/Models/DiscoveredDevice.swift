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
    public var manufacturer: Manufacturer?

    public init(
        identifier: UUID,
        name: String? = nil,
        rssi: Int,
        lastSeenDate: Date = .now,
        firstSeenDate: Date? = nil,
        isConnectable: Bool = false,
        advertisedServiceIdentifiers: [GATTIdentifier] = [],
        txPowerLevel: Int? = nil,
        beacon: BeaconReading? = nil,
        manufacturer: Manufacturer? = nil
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
        self.manufacturer = manufacturer
    }

    /// The heuristic proximity bucket, using the beacon's ranged reading when available
    /// and falling back to an RSSI-only estimate otherwise.
    ///
    /// Deliberately does *not* feed a non-beacon device's `txPowerLevel` into the same
    /// path-loss formula as `beacon.measuredPower`: that formula assumes its power input is
    /// a calibrated "RSSI at 1 meter" reference, which is what iBeacon's `measuredPower` is
    /// but `CBAdvertisementDataTxPowerLevelKey` is not (it's just the radio's broadcast power
    /// setting) — doing so was tried and produced distance estimates off by orders of
    /// magnitude for realistic values.
    public var proximity: Proximity {
        if let beacon {
            return beacon.rangedProximity
                ?? ProximityClassifier.classify(rssi: rssi, measuredPower: beacon.measuredPower)
        }
        return ProximityClassifier.classify(rssiOnly: rssi)
    }

    /// A rough distance estimate in meters. Uses the beacon's calibrated Tx power when this
    /// is a beacon, otherwise `ProximityClassifier.defaultMeasuredPower` — an assumed generic
    /// reference rather than a real calibration, so treat this as order-of-magnitude only.
    public var estimatedDistanceMeters: Double? {
        let measuredPower = beacon?.measuredPower ?? ProximityClassifier.defaultMeasuredPower
        return ProximityClassifier.estimatedDistanceMeters(rssi: rssi, measuredPower: measuredPower)
    }
}
