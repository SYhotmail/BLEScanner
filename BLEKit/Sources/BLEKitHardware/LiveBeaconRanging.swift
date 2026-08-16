import BLEKitCore
import CoreLocation
import Foundation

/// `CLLocationManager` delivers delegate callbacks on the thread it was created on, so this
/// type creates its manager on the main thread and confines every access to the main queue,
/// which is what backs the `@unchecked Sendable` conformance.
public final class LiveBeaconRanging: NSObject, BeaconRanging, @unchecked Sendable {
    private let locationManager: CLLocationManager
    private var continuation: AsyncStream<BeaconRangingEvent>.Continuation?
    private var activeConstraints: [UUID: CLBeaconIdentityConstraint] = [:]

    override public init() {
        if Thread.isMainThread {
            locationManager = CLLocationManager()
        } else {
            locationManager = DispatchQueue.main.sync { CLLocationManager() }
        }
        super.init()
        locationManager.delegate = self
    }

    public func events() -> AsyncStream<BeaconRangingEvent> {
        AsyncStream { continuation in
            DispatchQueue.main.async {
                self.continuation = continuation
                continuation.yield(.authorizationChanged(LocationAuthorizationState(self.locationManager.authorizationStatus)))
            }
            continuation.onTermination = { [weak self] _ in
                DispatchQueue.main.async { self?.continuation = nil }
            }
        }
    }

    public func requestWhenInUseAuthorization() {
        DispatchQueue.main.async { self.locationManager.requestWhenInUseAuthorization() }
    }

    public func startRanging(uuids: [UUID]) {
        DispatchQueue.main.async {
            for uuid in uuids where self.activeConstraints[uuid] == nil {
                let constraint = CLBeaconIdentityConstraint(uuid: uuid)
                self.activeConstraints[uuid] = constraint
                self.locationManager.startRangingBeacons(satisfying: constraint)
            }
        }
    }

    public func stopRanging(uuids: [UUID]) {
        DispatchQueue.main.async {
            for uuid in uuids {
                guard let constraint = self.activeConstraints.removeValue(forKey: uuid) else { continue }
                self.locationManager.stopRangingBeacons(satisfying: constraint)
            }
        }
    }

    public func stopAllRanging() {
        DispatchQueue.main.async {
            for constraint in self.activeConstraints.values {
                self.locationManager.stopRangingBeacons(satisfying: constraint)
            }
            self.activeConstraints.removeAll()
        }
    }
}

extension LiveBeaconRanging: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        continuation?.yield(.authorizationChanged(LocationAuthorizationState(manager.authorizationStatus)))
    }

    public func locationManager(
        _ manager: CLLocationManager,
        didRange beacons: [CLBeacon],
        satisfying beaconConstraint: CLBeaconIdentityConstraint
    ) {
        let ranged = beacons.map { beacon in
            RangedBeacon(
                uuid: beacon.uuid,
                major: UInt16(truncating: beacon.major),
                minor: UInt16(truncating: beacon.minor),
                proximity: Proximity(beacon.proximity),
                accuracyMeters: beacon.accuracy
            )
        }
        continuation?.yield(.rangedBeacons(ranged))
    }

    public func locationManager(
        _ manager: CLLocationManager,
        didFailRangingFor beaconConstraint: CLBeaconIdentityConstraint,
        error: Error
    ) {
        // Ranging for this specific constraint failed; other active constraints are unaffected.
    }
}

extension LocationAuthorizationState {
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorizedAlways: self = .authorizedAlways
        case .authorizedWhenInUse: self = .authorizedWhenInUse
        @unknown default: self = .notDetermined
        }
    }
}

extension Proximity {
    init(_ clProximity: CLProximity) {
        switch clProximity {
        case .immediate: self = .immediate
        case .near: self = .near
        case .far: self = .far
        case .unknown: self = .unknown
        @unknown default: self = .unknown
        }
    }
}
