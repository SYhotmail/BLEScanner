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
        case writeFormatChanged(characteristic: GATTIdentifier, format: WriteFormat)
        case writeInputChanged(characteristic: GATTIdentifier, text: String)
        case writeTapped(service: GATTIdentifier, characteristic: GATTIdentifier)
        case notifyToggled(service: GATTIdentifier, characteristic: GATTIdentifier, enabled: Bool)
    }

    private enum CancelID: Hashable {
        case connection
    }

    @Dependency(\.bluetoothScanner) var bluetoothScanner

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
                state.connectionStatus = status
                if status == .connected {
                    return discoverServicesEffect(identifier: state.device.identifier)
                }
                if status == .disconnected {
                    state.services = []
                }
                return .none

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
        if let index = characteristics.firstIndex(where: { $0.id == characteristic.id }) {
            characteristics[index] = characteristic
        } else {
            characteristics.append(characteristic)
        }
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
