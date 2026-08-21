import BLEKitCore
import CoreBluetooth
import Foundation

enum BLEAdvertisementDecoder {
    /// Converts `kCBAdvDataTimestamp` / `CBAdvertisementDataTimestampKey`
    /// into a `Date`.
    ///
    /// Apple reports this as CFAbsoluteTime:
    /// seconds since 2001-01-01 00:00:00 UTC.
    static func decodeAdvertisementTimestamp(
        from advertisementData: [String: Any]
    ) -> Date? {
        guard let rawValue = advertisementData["kCBAdvDataTimestamp"] as? Double
                ?? advertisementData["CBAdvertisementDataTimestampKey"] as? Double
        else {
            return nil
        }
        
        return Date(timeIntervalSinceReferenceDate: rawValue)
    }
}

/// Confines all mutable state and CoreBluetooth calls/callbacks to a single dedicated serial
/// queue (passed as both the delegate queue and the queue every public method dispatches
/// onto), which is what backs the `@unchecked Sendable` conformance.
public final class LiveBLECentralManager: NSObject, BLECentralManaging, @unchecked Sendable {
    private let queue: DispatchQueue
    private let centralManager: CBCentralManager
    
    private var scanContinuation: AsyncStream<BLEScanEvent>.Continuation?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var connections: [UUID: LiveBLEPeripheralConnection] = [:]

    override public init() {
        let queue = DispatchQueue(label: "com.blescanner.central-manager")
        let centralManager = CBCentralManager(delegate: nil, queue: queue)
        self.queue = queue
        self.centralManager = centralManager
        super.init()
        centralManager.delegate = self
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

    public func startScanning(allowDuplicates: Bool) {
        queue.async {
            guard self.centralManager.state == .poweredOn else { return }
            self.centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
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
        let state = central.state
        let isOn = state == .poweredOn

        if !isOn {
            for connection in connections.values {
                connection.handleDidDisconnect(error: nil)
            }
            connections.removeAll()
            discoveredPeripherals.removeAll()
        }

        scanContinuation?.yield(.stateChanged(BluetoothState(state)))
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let identifier = peripheral.identifier
        discoveredPeripherals[identifier] = peripheral
        
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue == true
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let txPowerLevel = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue

        let advDataTimestamp = BLEAdvertisementDecoder.decodeAdvertisementTimestamp(from: advertisementData)

        let advertisement = BLEAdvertisement(
            identifier: identifier,
            name: name,
            rssi: RSSI.intValue,
            isConnectable: isConnectable || peripheral.state == .connected || peripheral.state == .connecting,
            serviceIdentifiers: serviceUUIDs.map { GATTIdentifier(rawValue: $0.uuidString) },
            manufacturerData: manufacturerData,
            txPowerLevel: txPowerLevel,
            timestamp: advDataTimestamp ?? Date()
        )
        scanContinuation?.yield(.discovered(advertisement))
    }
    
    private func connectionForPeripheral(_ peripheral: CBPeripheral) -> LiveBLEPeripheralConnection? {
        connections[peripheral.identifier]
    }
    
    private func removePeripheral(_ peripheral: CBPeripheral) {
        let identifier = peripheral.identifier
        connections.removeValue(forKey: identifier)
        discoveredPeripherals.removeValue(forKey: identifier)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionForPeripheral(peripheral)?.handleDidConnect()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionForPeripheral(peripheral)?.handleDidFailToConnect(error: error)
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connectionForPeripheral(peripheral)?.handleDidDisconnect(error: error)
        removePeripheral(peripheral)
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
