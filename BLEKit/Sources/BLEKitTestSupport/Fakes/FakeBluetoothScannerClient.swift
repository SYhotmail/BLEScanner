import BLEKitDependencies
import BLEKitHardware
import Foundation

public final class FakeBluetoothScannerClient: @unchecked Sendable {
    private let channel = TestEventChannel<BLEScanEvent>()
    private let lock = NSLock()
    private var _startScanningCallCount = 0
    private var _stopScanningCallCount = 0
    private var _lastAllowDuplicates: Bool?
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

    public var startScanningCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _startScanningCallCount
    }

    public var stopScanningCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _stopScanningCallCount
    }

    /// `allowDuplicates` passed to the most recent `startScanning` call, or `nil` if it hasn't
    /// been called yet.
    public var lastAllowDuplicates: Bool? {
        lock.lock()
        defer { lock.unlock() }
        return _lastAllowDuplicates
    }

    public var client: BluetoothScannerClient {
        BluetoothScannerClient(
            scanEvents: { [channel] in channel.stream() },
            startScanning: { [self] allowDuplicates in
                lock.lock()
                _startScanningCallCount += 1
                _lastAllowDuplicates = allowDuplicates
                lock.unlock()
            },
            stopScanning: { [self] in
                lock.lock()
                _stopScanningCallCount += 1
                lock.unlock()
            },
            makeConnection: { [connectionProvider] identifier in try connectionProvider(identifier) }
        )
    }
}
