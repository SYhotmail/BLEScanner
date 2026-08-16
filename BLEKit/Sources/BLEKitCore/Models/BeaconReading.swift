import Foundation

/// The result of parsing an Apple iBeacon frame from advertisement manufacturer data,
/// optionally enriched with an authoritative CoreLocation ranging result.
public struct BeaconReading: Equatable, Sendable, Codable {
    public let uuid: UUID
    public let major: UInt16
    public let minor: UInt16
    /// Calibrated Tx power at 1 meter, as broadcast by the beacon.
    public let measuredPower: Int8
    /// Set only when CoreLocation enhanced ranging has supplied a reading for this UUID.
    public var rangedProximity: Proximity?

    public init(uuid: UUID, major: UInt16, minor: UInt16, measuredPower: Int8, rangedProximity: Proximity? = nil) {
        self.uuid = uuid
        self.major = major
        self.minor = minor
        self.measuredPower = measuredPower
        self.rangedProximity = rangedProximity
    }
}
