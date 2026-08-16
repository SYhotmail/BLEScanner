import BLEKitHardware
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct BluetoothScannerClient: Sendable {
    public var scanEvents: @Sendable () -> AsyncStream<BLEScanEvent> = { AsyncStream { $0.finish() } }
    public var startScanning: @Sendable () -> Void
    public var stopScanning: @Sendable () -> Void
    public var makeConnection: @Sendable (_ identifier: UUID) throws -> PeripheralConnectionClient
}

extension BluetoothScannerClient: DependencyKey {
    public static let liveValue: BluetoothScannerClient = {
        let manager = LiveBLECentralManager()
        return BluetoothScannerClient(
            scanEvents: { manager.scanEvents() },
            startScanning: { manager.startScanning() },
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
