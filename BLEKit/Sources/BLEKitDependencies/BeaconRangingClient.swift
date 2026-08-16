import BLEKitHardware
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct BeaconRangingClient: Sendable {
    public var events: @Sendable () -> AsyncStream<BeaconRangingEvent> = { AsyncStream { $0.finish() } }
    public var requestWhenInUseAuthorization: @Sendable () -> Void
    public var startRanging: @Sendable (_ uuids: [UUID]) -> Void
    public var stopRanging: @Sendable (_ uuids: [UUID]) -> Void
    public var stopAllRanging: @Sendable () -> Void
}

extension BeaconRangingClient: DependencyKey {
    public static let liveValue: BeaconRangingClient = {
        let ranger = LiveBeaconRanging()
        return BeaconRangingClient(
            events: { ranger.events() },
            requestWhenInUseAuthorization: { ranger.requestWhenInUseAuthorization() },
            startRanging: { ranger.startRanging(uuids: $0) },
            stopRanging: { ranger.stopRanging(uuids: $0) },
            stopAllRanging: { ranger.stopAllRanging() }
        )
    }()

    public static let testValue = BeaconRangingClient()
}

extension DependencyValues {
    public var beaconRanging: BeaconRangingClient {
        get { self[BeaconRangingClient.self] }
        set { self[BeaconRangingClient.self] = newValue }
    }
}
