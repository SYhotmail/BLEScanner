import BLEKitCore
import Foundation

public enum BluetoothState: Sendable, Equatable {
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn
}

public struct BLEAdvertisement: Sendable, Equatable {
    public let identifier: UUID
    public let name: String?
    public let rssi: Int
    public let isConnectable: Bool
    public let serviceIdentifiers: [GATTIdentifier]
    public let manufacturerData: Data?
    public let timestamp: Date

    public init(
        identifier: UUID,
        name: String?,
        rssi: Int,
        isConnectable: Bool,
        serviceIdentifiers: [GATTIdentifier],
        manufacturerData: Data?,
        timestamp: Date = .now
    ) {
        self.identifier = identifier
        self.name = name
        self.rssi = rssi
        self.isConnectable = isConnectable
        self.serviceIdentifiers = serviceIdentifiers
        self.manufacturerData = manufacturerData
        self.timestamp = timestamp
    }
}

public enum BLEScanEvent: Sendable, Equatable {
    case stateChanged(BluetoothState)
    case discovered(BLEAdvertisement)
}

public enum BLEHardwareError: Error, Sendable, Equatable {
    case peripheralNotFound
    case serviceNotFound
    case characteristicNotFound
    case operationFailed(String)
}

/// Bridges `CBCentralManagerDelegate` scanning callbacks to `AsyncStream`. Conformers confine
/// all mutable state to a single dedicated serial queue (matching the queue passed to
/// `CBCentralManager(delegate:queue:)`), which is what backs their `@unchecked Sendable`
/// conformance rather than actor isolation.
public protocol BLECentralManaging: AnyObject, Sendable {
    func scanEvents() -> AsyncStream<BLEScanEvent>
    func startScanning()
    func stopScanning()
    /// Vends a connection for a previously discovered (or previously known) identifier.
    /// Reuses an existing connection object if one is already active for this identifier.
    func makeConnection(for identifier: UUID) throws -> any BLEPeripheralConnection
}
