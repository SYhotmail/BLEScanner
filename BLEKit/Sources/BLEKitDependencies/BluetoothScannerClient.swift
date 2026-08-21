import BLEKitHardware
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct BluetoothScannerClient: Sendable {
    public var scanEvents: @Sendable () -> AsyncStream<BLEScanEvent> = { AsyncStream { $0.finish() } }
    public var startScanning: @Sendable (_ allowDuplicates: Bool) -> Void
    public var stopScanning: @Sendable () -> Void
    public var makeConnection: @Sendable (_ identifier: UUID) throws -> PeripheralConnectionClient
}

extension BluetoothScannerClient: DependencyKey {
    public static let liveValue: BluetoothScannerClient = {
        let manager = LiveBLECentralManager()
        return BluetoothScannerClient(
            scanEvents: { manager.scanEvents() },
            startScanning: { manager.startScanning(allowDuplicates: $0) },
            stopScanning: { manager.stopScanning() },
            makeConnection: { identifier in
                .live(try manager.makeConnection(for: identifier))
            }
        )
    }()

    public static let testValue = BluetoothScannerClient()
}

extension DependencyValues {
    public var bluetoothScanner: BluetoothScannerClient {
        get { self[BluetoothScannerClient.self] }
        set { self[BluetoothScannerClient.self] = newValue }
    }
}

extension BluetoothScannerClient {
    /// Best-effort disconnect for a peripheral by identifier, silently doing nothing if no
    /// cached connection exists — shared by call sites that just want "make sure this
    /// peripheral is disconnected" without caring whether a connection was ever established.
    public func disconnect(identifier: UUID) {
        guard let connection = try? makeConnection(identifier) else { return }
        connection.disconnect()
    }
}
