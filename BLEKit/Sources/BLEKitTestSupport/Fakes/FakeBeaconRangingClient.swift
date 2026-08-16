import BLEKitDependencies
import BLEKitHardware
import Foundation

public final class FakeBeaconRangingClient: @unchecked Sendable {
    private let channel = TestEventChannel<BeaconRangingEvent>()

    public init() {}

    public func send(_ event: BeaconRangingEvent) {
        channel.send(event)
    }

    public func finish() {
        channel.finish()
    }

    public var client: BeaconRangingClient {
        BeaconRangingClient(
            events: { [channel] in channel.stream() },
            requestWhenInUseAuthorization: {},
            startRanging: { _ in },
            stopRanging: { _ in },
            stopAllRanging: {}
        )
    }
}
