import BLEKitCore
import CoreBluetooth
import Foundation

/// Confines all mutable state and CoreBluetooth calls/callbacks to a single dedicated serial
/// queue (passed as both the delegate queue and the queue every public method dispatches
/// onto), which is what backs the `@unchecked Sendable` conformance.
public final class LiveBLECentralManager: NSObject, BLECentralManaging, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.blescanner.central-manager")
    private var centralManager: CBCentralManager!
    private var scanContinuation: AsyncStream<BLEScanEvent>.Continuation?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var connections: [UUID: LiveBLEPeripheralConnection] = [:]

    override public init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }

    public func scanEvents() -> AsyncStream<BLEScanEvent> {
        AsyncStream { continuation in
            queue.async {
                self.scanContinuation = continuation
                continuation.yield(.stateChanged(BluetoothState(self.centralManager.state)))
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.queue.async { self.scanContinuation = nil }
            }
        }
    }

    public func startScanning() {
        queue.async {
            guard self.centralManager.state == .poweredOn else { return }
            self.centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
    }

    public func stopScanning() {
        queue.async { self.centralManager.stopScan() }
    }

    public func makeConnection(for identifier: UUID) throws -> any BLEPeripheralConnection {
        try queue.sync {
            if let existing = connections[identifier] {
                return existing
            }
            let peripheral = discoveredPeripherals[identifier]
                ?? centralManager.retrievePeripherals(withIdentifiers: [identifier]).first
            guard let peripheral else {
                throw BLEHardwareError.peripheralNotFound
            }
            let connection = LiveBLEPeripheralConnection(peripheral: peripheral, centralManager: centralManager, queue: queue)
            connections[identifier] = connection
            return connection
        }
    }
}

extension LiveBLECentralManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        scanContinuation?.yield(.stateChanged(BluetoothState(central.state)))
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        discoveredPeripherals[peripheral.identifier] = peripheral

        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data

        let advertisement = BLEAdvertisement(
            identifier: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            isConnectable: isConnectable,
            serviceIdentifiers: serviceUUIDs.map { GATTIdentifier(rawValue: $0.uuidString) },
            manufacturerData: manufacturerData
        )
        scanContinuation?.yield(.discovered(advertisement))
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connections[peripheral.identifier]?.handleDidConnect()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connections[peripheral.identifier]?.handleDidFailToConnect(error: error)
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connections[peripheral.identifier]?.handleDidDisconnect(error: error)
    }
}

extension BluetoothState {
    init(_ cbState: CBManagerState) {
        switch cbState {
        case .unknown: self = .unknown
        case .resetting: self = .resetting
        case .unsupported: self = .unsupported
        case .unauthorized: self = .unauthorized
        case .poweredOff: self = .poweredOff
        case .poweredOn: self = .poweredOn
        @unknown default: self = .unknown
        }
    }
}
