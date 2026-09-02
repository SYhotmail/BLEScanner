import BLEKitCore
import BLEKitDependencies
import BLEKitHardware
import ComposableArchitecture
import Foundation

@Reducer
public struct DeviceDetailFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public var id: UUID { device.identifier }
        public var device: DiscoveredDevice
        public var connectionStatus: PeripheralConnectionState = .disconnected
        public var services: IdentifiedArrayOf<GATTService> = []
        public var writeFormatsByCharacteristic: [GATTIdentifier: WriteFormat] = [:]
        public var writeInputsByCharacteristic: [GATTIdentifier: String] = [:]
        public var writeErrorsByCharacteristic: [GATTIdentifier: String] = [:]

        public init(device: DiscoveredDevice) {
            self.device = device
        }
    }

    public enum Action: Equatable {
        case connectTapped
        case disconnectTapped
        case connectionEvent(PeripheralConnectionEvent)
        case readTapped(service: GATTIdentifier, characteristic: GATTIdentifier)
        case readDescriptorsTapped(service: GATTIdentifier, characteristic: GATTIdentifier)
        case writeFormatChanged(characteristic: GATTIdentifier, format: WriteFormat)
        case writeInputChanged(characteristic: GATTIdentifier, text: String)
        case writeTapped(service: GATTIdentifier, characteristic: GATTIdentifier)
        case notifyToggled(service: GATTIdentifier, characteristic: GATTIdentifier, enabled: Bool)
    }

    private enum CancelID: Hashable {
        case connection
    }

    @Dependency(\.bluetoothScanner) var bluetoothScanner
    @Dependency(\.bleLog) var bleLog

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .connectTapped:
                state.connectionStatus = .connecting
                return connectEffect(identifier: state.device.identifier)
                    .cancellable(id: CancelID.connection, cancelInFlight: true)

            case .disconnectTapped:
                state.connectionStatus = .disconnecting
                return disconnectEffect(identifier: state.device.identifier)

            case let .connectionEvent(.stateChanged(status)):
                let previous = state.connectionStatus
                state.connectionStatus = status
                let logEffect = connectionLogEffect(previous: previous, status: status, device: state.device)
                if status == .connected {
                    return .merge(logEffect, discoverServicesEffect(identifier: state.device.identifier))
                }
                if status == .disconnected {
                    state.services = []
                }
                return logEffect

            case let .connectionEvent(.servicesDiscovered(services)):
                state.services = IdentifiedArray(uniqueElements: services)
                return .none

            case let .connectionEvent(.characteristicUpdated(serviceIdentifier, characteristic)):
                update(characteristic: characteristic, serviceIdentifier: serviceIdentifier, in: &state)
                return .none

            case .connectionEvent(.writeCompleted):
                return .none

            case .connectionEvent(.operationFailed):
                return .none

            case let .readTapped(service, characteristic):
                return readEffect(identifier: state.device.identifier, service: service, characteristic: characteristic)

            case let .readDescriptorsTapped(service, characteristic):
                let descriptors = descriptorIdentifiers(service: service, characteristic: characteristic, in: state)
                guard !descriptors.isEmpty else { return .none }
                return readDescriptorsEffect(
                    identifier: state.device.identifier,
                    service: service,
                    characteristic: characteristic,
                    descriptors: descriptors
                )

            case let .writeFormatChanged(characteristic, format):
                state.writeFormatsByCharacteristic[characteristic] = format
                state.writeErrorsByCharacteristic[characteristic] = nil
                return .none

            case let .writeInputChanged(characteristic, text):
                state.writeInputsByCharacteristic[characteristic] = text
                state.writeErrorsByCharacteristic[characteristic] = nil
                return .none

            case let .writeTapped(service, characteristic):
                let format = state.writeFormatsByCharacteristic[characteristic] ?? .text
                let text = state.writeInputsByCharacteristic[characteristic] ?? ""
                do {
                    let data = try CharacteristicValueCodec.encode(text, as: format)
                    state.writeErrorsByCharacteristic[characteristic] = nil
                    return writeEffect(
                        identifier: state.device.identifier,
                        data: data,
                        service: service,
                        characteristic: characteristic
                    )
                } catch {
                    state.writeErrorsByCharacteristic[characteristic] = Self.describeWriteError(error)
                    return .none
                }

            case let .notifyToggled(service, characteristic, enabled):
                return notifyEffect(
                    identifier: state.device.identifier,
                    enabled: enabled,
                    service: service,
                    characteristic: characteristic
                )
            }
        }
    }

    /// Records a critical connection-lifecycle transition (connected / disconnected / failed) to
    /// `OSLog`. Returns `.none` for intermediate states and for no-op repeats of the same state.
    private func connectionLogEffect(
        previous: PeripheralConnectionState,
        status: PeripheralConnectionState,
        device: DiscoveredDevice
    ) -> Effect<Action> {
        guard previous != status else { return .none }
        let bleLog = bleLog
        let identifier = device.identifier
        let name = device.name
        switch status {
        case .connected:
            return .run { _ in bleLog.record(.peripheralConnected(identifier: identifier, name: name)) }
        case .disconnected:
            return .run { _ in bleLog.record(.peripheralDisconnected(identifier: identifier, name: name)) }
        case let .failed(reason):
            return .run { _ in
                bleLog.record(.peripheralConnectionFailed(identifier: identifier, name: name, reason: reason))
            }
        case .connecting, .disconnecting:
            return .none
        }
    }

    private func connectEffect(identifier: UUID) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        return .run { send in
            do {
                let connection = try bluetoothScanner.makeConnection(identifier)
                connection.connect()
                for await event in connection.events() {
                    await send(.connectionEvent(event))
                }
            } catch {
                await send(.connectionEvent(.stateChanged(.failed(error.localizedDescription))))
            }
        }
    }

    private func disconnectEffect(identifier: UUID) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        return .run { _ in bluetoothScanner.disconnect(identifier: identifier) }
    }

    private func discoverServicesEffect(identifier: UUID) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        return .run { _ in
            guard let connection = try? bluetoothScanner.makeConnection(identifier) else { return }
            connection.discoverServices()
        }
    }

    private func readEffect(identifier: UUID, service: GATTIdentifier, characteristic: GATTIdentifier) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        return .run { _ in
            guard let connection = try? bluetoothScanner.makeConnection(identifier) else { return }
            connection.readValue(service, characteristic)
        }
    }

    private func readDescriptorsEffect(
        identifier: UUID,
        service: GATTIdentifier,
        characteristic: GATTIdentifier,
        descriptors: [GATTIdentifier]
    ) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        return .run { _ in
            guard let connection = try? bluetoothScanner.makeConnection(identifier) else { return }
            for descriptor in descriptors {
                connection.readDescriptor(service, characteristic, descriptor)
            }
        }
    }

    /// The identifiers of every descriptor on `characteristic`, whether it sits directly under
    /// `service` or under one of its included services.
    private func descriptorIdentifiers(
        service: GATTIdentifier,
        characteristic: GATTIdentifier,
        in state: State
    ) -> [GATTIdentifier] {
        for topLevel in state.services {
            let owner = topLevel.identifier == service
                ? topLevel
                : topLevel.includedServices.first { $0.identifier == service }
            guard let owner else { continue }
            return owner.characteristics
                .first { $0.identifier == characteristic }?
                .descriptors.map(\.identifier) ?? []
        }
        return []
    }

    private func writeEffect(
        identifier: UUID,
        data: Data,
        service: GATTIdentifier,
        characteristic: GATTIdentifier
    ) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        return .run { _ in
            guard let connection = try? bluetoothScanner.makeConnection(identifier) else { return }
            connection.writeValue(data, service, characteristic, true)
        }
    }

    private func notifyEffect(
        identifier: UUID,
        enabled: Bool,
        service: GATTIdentifier,
        characteristic: GATTIdentifier
    ) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        return .run { _ in
            guard let connection = try? bluetoothScanner.makeConnection(identifier) else { return }
            connection.setNotify(enabled, service, characteristic)
        }
    }

    private func update(characteristic: GATTCharacteristic, serviceIdentifier: GATTIdentifier, in state: inout State) {
        for topLevelID in state.services.ids {
            guard var service = state.services[id: topLevelID] else { continue }
            if service.identifier == serviceIdentifier {
                Self.merge(characteristic, into: &service.characteristics)
                state.services[id: topLevelID] = service
                return
            }
            if let index = service.includedServices.firstIndex(where: { $0.identifier == serviceIdentifier }) {
                Self.merge(characteristic, into: &service.includedServices[index].characteristics)
                state.services[id: topLevelID] = service
                return
            }
        }
    }

    private static func merge(_ characteristic: GATTCharacteristic, into characteristics: inout [GATTCharacteristic]) {
        guard let index = characteristics.firstIndex(where: { $0.id == characteristic.id }) else {
            characteristics.append(characteristic)
            return
        }
        var merged = characteristic
        let existing = characteristics[index]
        // Read/notify updates carry whatever descriptors CoreBluetooth still has attached; if an
        // update arrives without them, keep the ones discovery already found.
        if merged.descriptors.isEmpty {
            merged.descriptors = existing.descriptors
        } else {
            // Carry forward any descriptor value this snapshot doesn't itself include, so reading
            // one descriptor never blanks out a value already read for one of its siblings.
            merged.descriptors = merged.descriptors.map { incoming in
                guard incoming.value == nil,
                      let prior = existing.descriptors.first(where: { $0.id == incoming.id }),
                      prior.value != nil
                else { return incoming }
                var filled = incoming
                filled.value = prior.value
                return filled
            }
            for prior in existing.descriptors where !merged.descriptors.contains(where: { $0.id == prior.id }) {
                merged.descriptors.append(prior)
            }
        }
        characteristics[index] = merged
    }

    private static func describeWriteError(_ error: Error) -> String {
        switch error as? CharacteristicValueCodecError {
        case .emptyInput:
            return "Enter a value to write."
        case .invalidHexLength:
            return "Hex input must have an even number of digits."
        case .invalidHexCharacter:
            return "Hex input may only contain 0-9 and A-F."
        case nil:
            return error.localizedDescription
        }
    }
}
