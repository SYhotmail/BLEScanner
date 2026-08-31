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
            
            guard characteristic.properties.contains(.read) else {
                self.continuation?.yield(.operationFailed(.cannotBeRead))
                return
            }
            self.peripheral.readValue(for: characteristic)
        }
    }

    public func readDescriptor(
        serviceIdentifier: GATTIdentifier,
        characteristicIdentifier: GATTIdentifier,
        descriptorIdentifier: GATTIdentifier
    ) {
        queue.async {
            guard let descriptor = self.descriptor(
                serviceIdentifier: serviceIdentifier,
                characteristicIdentifier: characteristicIdentifier,
                descriptorIdentifier: descriptorIdentifier
            ) else {
                self.continuation?.yield(.operationFailed(.characteristicNotFound))
                return
            }
            self.peripheral.readValue(for: descriptor)
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
        let candidateServices = (peripheral.services ?? [])
            .flatMap { [$0] + ($0.includedServices ?? []) }
        return candidateServices
            .first { GATTIdentifier(rawValue: $0.uuid.uuidString) == serviceIdentifier }?
            .characteristics?
            .first { GATTIdentifier(rawValue: $0.uuid.uuidString) == characteristicIdentifier }
    }

    private func descriptor(
        serviceIdentifier: GATTIdentifier,
        characteristicIdentifier: GATTIdentifier,
        descriptorIdentifier: GATTIdentifier
    ) -> CBDescriptor? {
        characteristic(serviceIdentifier: serviceIdentifier, characteristicIdentifier: characteristicIdentifier)?
            .descriptors?
            .first { GATTIdentifier(rawValue: $0.uuid.uuidString) == descriptorIdentifier }
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
            peripheral.discoverIncludedServices(nil, for: service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        if let error {
            continuation?.yield(.operationFailed(.operationFailed(error.localizedDescription)))
            return
        }
        for included in service.includedServices ?? [] where included.characteristics == nil {
            peripheral.discoverCharacteristics(nil, for: included)
        }
        emitServiceSnapshotIfComplete()
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            continuation?.yield(.operationFailed(.operationFailed(error.localizedDescription)))
            return
        }
        for characteristic in service.characteristics ?? [] {
            peripheral.discoverDescriptors(for: characteristic)
        }
        emitServiceSnapshotIfComplete()
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
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

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard let characteristic = descriptor.characteristic, let service = characteristic.service else { return }
        if let error {
            continuation?.yield(.operationFailed(.operationFailed(error.localizedDescription)))
            return
        }
        // Re-emit the owning characteristic: `gattCharacteristic(from:)` rebuilds its descriptor
        // list, and CoreBluetooth keeps every previously-read `CBDescriptor.value` populated, so
        // the reducer's existing characteristic-merge picks up the new descriptor value.
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
        // Every top-level service must have had both its characteristics and its included
        // services discovered, every included service must have had its characteristics
        // discovered, and every characteristic must have had its descriptors discovered,
        // before the snapshot is complete.
        guard services.allSatisfy({ $0.characteristics != nil && $0.includedServices != nil }) else { return }
        let includedServices = services.flatMap { $0.includedServices ?? [] }
        guard includedServices.allSatisfy({ $0.characteristics != nil }) else { return }
        let allCharacteristics = (services + includedServices).flatMap { $0.characteristics ?? [] }
        guard allCharacteristics.allSatisfy({ $0.descriptors != nil }) else { return }

        let gattServices = services.map { service in
            GATTService(
                identifier: GATTIdentifier(rawValue: service.uuid.uuidString),
                characteristics: (service.characteristics ?? []).map(gattCharacteristic(from:)),
                includedServices: (service.includedServices ?? []).map { included in
                    GATTService(
                        identifier: GATTIdentifier(rawValue: included.uuid.uuidString),
                        characteristics: (included.characteristics ?? []).map(gattCharacteristic(from:))
                    )
                }
            )
        }
        continuation?.yield(.servicesDiscovered(gattServices))
    }

    private func gattCharacteristic(from characteristic: CBCharacteristic) -> GATTCharacteristic {
        GATTCharacteristic(
            identifier: GATTIdentifier(rawValue: characteristic.uuid.uuidString),
            properties: GATTCharacteristicProperties(cbProperties: characteristic.properties),
            latestValue: characteristic.value,
            isNotifying: characteristic.isNotifying,
            descriptors: (characteristic.descriptors ?? []).map { descriptor in
                GATTDescriptor(
                    identifier: GATTIdentifier(rawValue: descriptor.uuid.uuidString),
                    value: normalizedDescriptorValue(descriptor.value)
                )
            }
        )
    }

    /// `CBDescriptor.value` is `Any?`; for the well-known descriptors CoreBluetooth only ever
    /// vends `NSNumber`, `NSString`, or `NSData`. Anything else collapses to `nil`.
    private func normalizedDescriptorValue(_ value: Any?) -> GATTDescriptorValue? {
        switch value {
        case let number as NSNumber: .uint(number.uint64Value)
        case let string as NSString: .string(string as String)
        case let data as Data: .data(data)
        case let data as NSData: .data(data as Data)
        default: nil
        }
    }
}
