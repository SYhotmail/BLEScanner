#if DEBUG
import BLEKitCore
import BLEKitDependencies
import BLEKitHardware
import BLEKitTestSupport
import Foundation

/// Vends one `AutopilotPeripheralConnectionClient` per identifier, matching how the real
/// `LiveBLECentralManager` caches connections. Without this, `DeviceDetailFeature` calling
/// `makeConnection` a second time (e.g. after `.connected`, to call `discoverServices()`)
/// would get a fresh instance with nobody subscribed to its event stream.
final class AutopilotConnectionCache: @unchecked Sendable {
    private let lock = NSLock()
    private var connectionsByIdentifier: [UUID: AutopilotPeripheralConnectionClient] = [:]

    func connection(for identifier: UUID) -> PeripheralConnectionClient {
        lock.lock()
        defer { lock.unlock() }
        if let existing = connectionsByIdentifier[identifier] {
            return existing.client
        }
        let connection = AutopilotPeripheralConnectionClient(identifier: identifier)
        connectionsByIdentifier[identifier] = connection
        return connection.client
    }
}

/// A self-driving `PeripheralConnectionClient` for `-UITesting`: connect/discover/read calls
/// respond on their own after a short delay, since a real XCUITest process can't reach into
/// this app process to trigger canned events the way an in-process unit test can.
final class AutopilotPeripheralConnectionClient: @unchecked Sendable {
    let identifier: UUID
    private let channel = TestEventChannel<PeripheralConnectionEvent>()

    init(identifier: UUID) {
        self.identifier = identifier
    }

    var client: PeripheralConnectionClient {
        PeripheralConnectionClient(
            identifier: identifier,
            events: { [channel] in channel.stream() },
            connect: { [channel] in
                channel.send(.stateChanged(.connecting))
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    channel.send(.stateChanged(.connected))
                }
            },
            disconnect: { [channel] in
                channel.send(.stateChanged(.disconnected))
            },
            discoverServices: { [channel] in
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    channel.send(.servicesDiscovered(UITestFixtures.services))
                }
            },
            readValue: { [channel] service, _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    var updated = UITestFixtures.batteryCharacteristic
                    updated.latestValue = Data([0x55])
                    channel.send(.characteristicUpdated(serviceIdentifier: service, characteristic: updated))
                }
            },
            writeValue: { [channel] _, service, characteristic, _ in
                channel.send(.writeCompleted(serviceIdentifier: service, characteristicIdentifier: characteristic))
            },
            setNotify: { _, _, _ in }
        )
    }
}
#endif
