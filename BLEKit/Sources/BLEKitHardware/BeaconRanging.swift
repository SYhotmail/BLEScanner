import BLEKitCore
import Foundation

public enum LocationAuthorizationState: Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways
}

public struct RangedBeacon: Sendable, Equatable {
    public let uuid: UUID
    public let major: UInt16
    public let minor: UInt16
    public let proximity: Proximity
    public let accuracyMeters: Double

    public init(uuid: UUID, major: UInt16, minor: UInt16, proximity: Proximity, accuracyMeters: Double) {
        self.uuid = uuid
        self.major = major
        self.minor = minor
        self.proximity = proximity
        self.accuracyMeters = accuracyMeters
    }
}

public enum BeaconRangingEvent: Sendable, Equatable {
    case authorizationChanged(LocationAuthorizationState)
    case rangedBeacons([RangedBeacon])
}

/// Bridges `CLLocationManagerDelegate` beacon-ranging callbacks to `AsyncStream`, used only
/// for the opt-in "Enhanced Beacon Ranging" feature.
public protocol BeaconRanging: AnyObject, Sendable {
    func events() -> AsyncStream<BeaconRangingEvent>
    func requestWhenInUseAuthorization()
    func startRanging(uuids: [UUID])
    func stopRanging(uuids: [UUID])
    func stopAllRanging()
}
