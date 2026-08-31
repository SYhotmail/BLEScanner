import BLEKitCore
import BLEKitHardware
import Foundation

/// A `Sendable` façade over a single `BLEPeripheralConnection`, handed out per-device by
/// `BluetoothScannerClient.makeConnection`. Not registered as a global `DependencyKey` itself —
/// each connected device gets its own instance.
public struct PeripheralConnectionClient: Sendable {
    public var identifier: UUID
    public var events: @Sendable () -> AsyncStream<PeripheralConnectionEvent>
    public var connect: @Sendable () -> Void
    public var disconnect: @Sendable () -> Void
    public var discoverServices: @Sendable () -> Void
    public var readValue: @Sendable (_ service: GATTIdentifier, _ characteristic: GATTIdentifier) -> Void
    public var readDescriptor: @Sendable (_ service: GATTIdentifier, _ characteristic: GATTIdentifier, _ descriptor: GATTIdentifier) -> Void
    public var writeValue: @Sendable (_ data: Data, _ service: GATTIdentifier, _ characteristic: GATTIdentifier, _ withResponse: Bool) -> Void
    public var setNotify: @Sendable (_ enabled: Bool, _ service: GATTIdentifier, _ characteristic: GATTIdentifier) -> Void

    public init(
        identifier: UUID,
        events: @escaping @Sendable () -> AsyncStream<PeripheralConnectionEvent>,
        connect: @escaping @Sendable () -> Void,
        disconnect: @escaping @Sendable () -> Void,
        discoverServices: @escaping @Sendable () -> Void,
        readValue: @escaping @Sendable (GATTIdentifier, GATTIdentifier) -> Void,
        readDescriptor: @escaping @Sendable (GATTIdentifier, GATTIdentifier, GATTIdentifier) -> Void,
        writeValue: @escaping @Sendable (Data, GATTIdentifier, GATTIdentifier, Bool) -> Void,
        setNotify: @escaping @Sendable (Bool, GATTIdentifier, GATTIdentifier) -> Void
    ) {
        self.identifier = identifier
        self.events = events
        self.connect = connect
        self.disconnect = disconnect
        self.discoverServices = discoverServices
        self.readValue = readValue
        self.readDescriptor = readDescriptor
        self.writeValue = writeValue
        self.setNotify = setNotify
    }

    /// Wraps a live `BLEPeripheralConnection`, forwarding every call directly.
    public static func live(_ connection: any BLEPeripheralConnection) -> PeripheralConnectionClient {
        PeripheralConnectionClient(
            identifier: connection.identifier,
            events: { connection.events() },
            connect: { connection.connect() },
            disconnect: { connection.disconnect() },
            discoverServices: { connection.discoverServices() },
            readValue: { connection.readValue(serviceIdentifier: $0, characteristicIdentifier: $1) },
            readDescriptor: { connection.readDescriptor(serviceIdentifier: $0, characteristicIdentifier: $1, descriptorIdentifier: $2) },
            writeValue: { connection.writeValue($0, serviceIdentifier: $1, characteristicIdentifier: $2, withResponse: $3) },
            setNotify: { connection.setNotify($0, serviceIdentifier: $1, characteristicIdentifier: $2) }
        )
    }
}
