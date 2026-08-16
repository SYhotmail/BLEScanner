import BLEKitCore
import CoreBluetooth
import Foundation

/// Confines all mutable state and CoreBluetooth calls/callbacks to the same dedicated serial
/// queue as the owning `LiveBLECentralManager`, which is what backs the `@unchecked Sendable`
/// conformance.
public final class LiveBLEPeripheralConnection: NSObject, BLEPeripheralConnection, @unchecked Sendable {
    public let identifier: UUID
    private let peripheral: CBPeripheral
    private let centralManager: CBCentralManager
    private let queue: DispatchQueue
    private var continuation: AsyncStream<PeripheralConnectionEvent>.Continuation?

    init(peripheral: CBPeripheral, centralManager: CBCentralManager, queue: DispatchQueue) {
        self.identifier = peripheral.identifier
        self.peripheral = peripheral
        self.centralManager = centralManager
        self.queue = queue
        super.init()
        peripheral.delegate = self
    }

    public func events() -> AsyncStream<PeripheralConnectionEvent> {
        AsyncStream { continuation in
            queue.async { self.continuation = continuation }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.queue.async { self.continuation = nil }
            }
        }
    }

    public func connect() {
        queue.async {
            self.continuation?.yield(.stateChanged(.connecting))
            self.centralManager.connect(self.peripheral, options: nil)
        }
    }

    public func disconnect() {
        queue.async {
            self.continuation?.yield(.stateChanged(.disconnecting))
            self.centralManager.cancelPeripheralConnection(self.peripheral)
        }
    }

    public func discoverServices() {
        queue.async { self.peripheral.discoverServices(nil) }
    }

    public func readValue(serviceIdentifier: GATTIdentifier, characteristicIdentifier: GATTIdentifier) {
        queue.async {
            guard let characteristic = self.characteristic(serviceIdentifier: serviceIdentifier, characteristicIdentifier: characteristicIdentifier) else {
                self.continuation?.yield(.operationFailed(.characteristicNotFound))
                return
            }
            self.peripheral.readValue(for: characteristic)
        }
    }

    public func writeValue(
        _ data: Data,
        serviceIdentifier: GATTIdentifier,
        characteristicIdentifier: GATTIdentifier,
        withResponse: Bool
    ) {
        queue.async {
            guard let characteristic = self.characteristic(serviceIdentifier: serviceIdentifier, characteristicIdentifier: characteristicIdentifier) else {
                self.continuation?.yield(.operationFailed(.characteristicNotFound))
                return
            }
            self.peripheral.writeValue(data, for: characteristic, type: withResponse ? .withResponse : .withoutResponse)
            if !withResponse {
                // CoreBluetooth never calls back for .withoutResponse writes, so report completion immediately.
                self.continuation?.yield(.writeCompleted(serviceIdentifier: serviceIdentifier, characteristicIdentifier: characteristicIdentifier))
            }
        }
    }

    public func setNotify(_ enabled: Bool, serviceIdentifier: GATTIdentifier, characteristicIdentifier: GATTIdentifier) {
        queue.async {
            guard let characteristic = self.characteristic(serviceIdentifier: serviceIdentifier, characteristicIdentifier: characteristicIdentifier) else {
                self.continuation?.yield(.operationFailed(.characteristicNotFound))
                return
            }
            self.peripheral.setNotifyValue(enabled, for: characteristic)
        }
    }

    func handleDidConnect() {
        continuation?.yield(.stateChanged(.connected))
    }

    func handleDidFailToConnect(error: Error?) {
        continuation?.yield(.stateChanged(.failed(error?.localizedDescription ?? "Failed to connect")))
    }

    func handleDidDisconnect(error: Error?) {
        continuation?.yield(.stateChanged(.disconnected))
    }

    private func characteristic(
        serviceIdentifier: GATTIdentifier,
        characteristicIdentifier: GATTIdentifier
    ) -> CBCharacteristic? {
        peripheral.services?
            .first { GATTIdentifier(rawValue: $0.uuid.uuidString) == serviceIdentifier }?
            .characteristics?
            .first { GATTIdentifier(rawValue: $0.uuid.uuidString) == characteristicIdentifier }
    }
}

extension LiveBLEPeripheralConnection: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            continuation?.yield(.operationFailed(.operationFailed(error.localizedDescription)))
            return
        }
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            continuation?.yield(.operationFailed(.operationFailed(error.localizedDescription)))
            return
        }
        emitServiceSnapshotIfComplete()
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let service = characteristic.service else { return }
        continuation?.yield(.characteristicUpdated(
            serviceIdentifier: GATTIdentifier(rawValue: service.uuid.uuidString),
            characteristic: gattCharacteristic(from: characteristic)
        ))
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let service = characteristic.service else { return }
        if let error {
            continuation?.yield(.operationFailed(.operationFailed(error.localizedDescription)))
        } else {
            continuation?.yield(.writeCompleted(
                serviceIdentifier: GATTIdentifier(rawValue: service.uuid.uuidString),
                characteristicIdentifier: GATTIdentifier(rawValue: characteristic.uuid.uuidString)
            ))
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let service = characteristic.service else { return }
        continuation?.yield(.characteristicUpdated(
            serviceIdentifier: GATTIdentifier(rawValue: service.uuid.uuidString),
            characteristic: gattCharacteristic(from: characteristic)
        ))
    }

    private func emitServiceSnapshotIfComplete() {
        guard let services = peripheral.services else { return }
        guard services.allSatisfy({ $0.characteristics != nil }) else { return }
        let gattServices = services.map { service in
            GATTService(
                identifier: GATTIdentifier(rawValue: service.uuid.uuidString),
                characteristics: (service.characteristics ?? []).map(gattCharacteristic(from:))
            )
        }
        continuation?.yield(.servicesDiscovered(gattServices))
    }

    private func gattCharacteristic(from characteristic: CBCharacteristic) -> GATTCharacteristic {
        GATTCharacteristic(
            identifier: GATTIdentifier(rawValue: characteristic.uuid.uuidString),
            properties: GATTCharacteristicProperties(cbProperties: characteristic.properties),
            latestValue: characteristic.value,
            isNotifying: characteristic.isNotifying
        )
    }
}
