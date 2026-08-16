import BLEKitCore
import Foundation

public enum PeripheralConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed(String)
}

public enum PeripheralConnectionEvent: Sendable, Equatable {
    case stateChanged(PeripheralConnectionState)
    case servicesDiscovered([GATTService])
    case characteristicUpdated(serviceIdentifier: GATTIdentifier, characteristic: GATTCharacteristic)
    case writeCompleted(serviceIdentifier: GATTIdentifier, characteristicIdentifier: GATTIdentifier)
    case operationFailed(BLEHardwareError)
}

/// A connection to a single peripheral. All results (service discovery, reads, write
/// confirmations, notified values) arrive via `events()` rather than as direct return
/// values, matching CoreBluetooth's delegate-callback-driven design.
public protocol BLEPeripheralConnection: AnyObject, Sendable {
    var identifier: UUID { get }
    func events() -> AsyncStream<PeripheralConnectionEvent>
    func connect()
    func disconnect()
    func discoverServices()
    func readValue(serviceIdentifier: GATTIdentifier, characteristicIdentifier: GATTIdentifier)
    func writeValue(
        _ data: Data,
        serviceIdentifier: GATTIdentifier,
        characteristicIdentifier: GATTIdentifier,
        withResponse: Bool
    )
    func setNotify(_ enabled: Bool, serviceIdentifier: GATTIdentifier, characteristicIdentifier: GATTIdentifier)
}
