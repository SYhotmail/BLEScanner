import BLEKitDependencies
import BLEKitHardware
import Foundation

public final class FakeBluetoothScannerClient: @unchecked Sendable {
    private let channel = TestEventChannel<BLEScanEvent>()
    public var connectionProvider: @Sendable (UUID) throws -> PeripheralConnectionClient

    public init(
        connectionProvider: @escaping @Sendable (UUID) throws -> PeripheralConnectionClient = { identifier in
            FakePeripheralConnectionClient(identifier: identifier).client
        }
    ) {
        self.connectionProvider = connectionProvider
    }

    public func send(_ event: BLEScanEvent) {
        channel.send(event)
    }

    public func finish() {
        channel.finish()
    }

    public var client: BluetoothScannerClient {
        BluetoothScannerClient(
            scanEvents: { [channel] in channel.stream() },
            startScanning: {},
            stopScanning: {},
            makeConnection: { [connectionProvider] identifier in try connectionProvider(identifier) }
        )
    }
}
