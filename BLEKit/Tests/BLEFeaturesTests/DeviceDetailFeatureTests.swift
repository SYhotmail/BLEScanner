import BLEKitCore
import BLEKitHardware
import BLEKitTestSupport
import ComposableArchitecture
import Foundation
import Testing
@testable import BLEFeatures

@MainActor
@Suite("DeviceDetailFeature")
struct DeviceDetailFeatureTests {
    @Test("connecting discovers services once connected")
    func connectingDiscoversServices() async {
        let fakeConnection = FakePeripheralConnectionClient(identifier: DiscoveredDeviceFixtures.plainSensor.identifier)
        let store = TestStore(initialState: DeviceDetailFeature.State(device: DiscoveredDeviceFixtures.plainSensor)) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bluetoothScanner.makeConnection = { _ in fakeConnection.client }
        }

        await store.send(.connectTapped) {
            $0.connectionStatus = .connecting
        }

        fakeConnection.send(.stateChanged(.connected))
        await store.receive(\.connectionEvent) {
            $0.connectionStatus = .connected
        }

        fakeConnection.send(.servicesDiscovered(GATTFixtures.allServices))
        await store.receive(\.connectionEvent) {
            $0.services = IdentifiedArray(uniqueElements: GATTFixtures.allServices)
        }

        fakeConnection.finish()
        await store.finish()
    }

    @Test("disconnection clears the discovered services")
    func disconnectionClearsServices() async {
        // The connection's event stream only has a live subscriber once `.connectTapped` has
        // started the long-running effect, so this drives a real connect first.
        let fakeConnection = FakePeripheralConnectionClient(identifier: DiscoveredDeviceFixtures.plainSensor.identifier)
        let store = TestStore(initialState: DeviceDetailFeature.State(device: DiscoveredDeviceFixtures.plainSensor)) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bluetoothScanner.makeConnection = { _ in fakeConnection.client }
        }

        await store.send(.connectTapped) {
            $0.connectionStatus = .connecting
        }
        fakeConnection.send(.stateChanged(.connected))
        await store.receive(\.connectionEvent) {
            $0.connectionStatus = .connected
        }
        fakeConnection.send(.servicesDiscovered(GATTFixtures.allServices))
        await store.receive(\.connectionEvent) {
            $0.services = IdentifiedArray(uniqueElements: GATTFixtures.allServices)
        }

        await store.send(.disconnectTapped) {
            $0.connectionStatus = .disconnecting
        }

        fakeConnection.send(.stateChanged(.disconnected))
        await store.receive(\.connectionEvent) {
            $0.connectionStatus = .disconnected
            $0.services = []
        }

        fakeConnection.finish()
        await store.finish()
    }

    @Test("a characteristic value update is merged into its owning service")
    func characteristicUpdateMergesIntoService() async {
        let fakeConnection = FakePeripheralConnectionClient(identifier: DiscoveredDeviceFixtures.plainSensor.identifier)
        let store = TestStore(initialState: DeviceDetailFeature.State(device: DiscoveredDeviceFixtures.plainSensor)) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bluetoothScanner.makeConnection = { _ in fakeConnection.client }
        }

        await store.send(.connectTapped) {
            $0.connectionStatus = .connecting
        }
        fakeConnection.send(.stateChanged(.connected))
        await store.receive(\.connectionEvent) {
            $0.connectionStatus = .connected
        }
        fakeConnection.send(.servicesDiscovered(GATTFixtures.allServices))
        await store.receive(\.connectionEvent) {
            $0.services = IdentifiedArray(uniqueElements: GATTFixtures.allServices)
        }

        var updatedCharacteristic = GATTFixtures.batteryLevelCharacteristic
        updatedCharacteristic.latestValue = Data([0x32])

        await store.send(.readTapped(service: GATTFixtures.batteryService.identifier, characteristic: updatedCharacteristic.identifier))

        fakeConnection.send(.characteristicUpdated(serviceIdentifier: GATTFixtures.batteryService.identifier, characteristic: updatedCharacteristic))
        await store.receive(\.connectionEvent) {
            $0.services[id: GATTFixtures.batteryService.identifier]?.characteristics[0] = updatedCharacteristic
        }

        fakeConnection.finish()
        await store.finish()
    }

    @Test("writing with valid hex input clears any prior error")
    func writingValidHexClearsError() async {
        let fakeConnection = FakePeripheralConnectionClient(identifier: DiscoveredDeviceFixtures.plainSensor.identifier)
        var initialState = DeviceDetailFeature.State(device: DiscoveredDeviceFixtures.plainSensor)
        initialState.writeErrorsByCharacteristic[GATTFixtures.deviceNameCharacteristic.identifier] = "stale error"

        let store = TestStore(initialState: initialState) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bluetoothScanner.makeConnection = { _ in fakeConnection.client }
        }

        await store.send(.writeFormatChanged(characteristic: GATTFixtures.deviceNameCharacteristic.identifier, format: .hex)) {
            $0.writeFormatsByCharacteristic[GATTFixtures.deviceNameCharacteristic.identifier] = .hex
            $0.writeErrorsByCharacteristic[GATTFixtures.deviceNameCharacteristic.identifier] = nil
        }
        await store.send(.writeInputChanged(characteristic: GATTFixtures.deviceNameCharacteristic.identifier, text: "0A1F")) {
            $0.writeInputsByCharacteristic[GATTFixtures.deviceNameCharacteristic.identifier] = "0A1F"
        }
        await store.send(.writeTapped(service: GATTFixtures.genericAccessService.identifier, characteristic: GATTFixtures.deviceNameCharacteristic.identifier))
    }

    @Test("writing with invalid hex input surfaces a validation error and does not write")
    func writingInvalidHexSurfacesError() async {
        let store = TestStore(initialState: DeviceDetailFeature.State(device: DiscoveredDeviceFixtures.plainSensor)) {
            DeviceDetailFeature()
        }

        await store.send(.writeFormatChanged(characteristic: GATTFixtures.deviceNameCharacteristic.identifier, format: .hex)) {
            $0.writeFormatsByCharacteristic[GATTFixtures.deviceNameCharacteristic.identifier] = .hex
        }
        await store.send(.writeInputChanged(characteristic: GATTFixtures.deviceNameCharacteristic.identifier, text: "ZZ")) {
            $0.writeInputsByCharacteristic[GATTFixtures.deviceNameCharacteristic.identifier] = "ZZ"
        }
        await store.send(.writeTapped(service: GATTFixtures.genericAccessService.identifier, characteristic: GATTFixtures.deviceNameCharacteristic.identifier)) {
            $0.writeErrorsByCharacteristic[GATTFixtures.deviceNameCharacteristic.identifier] = "Hex input may only contain 0-9 and A-F."
        }
    }

    @Test("a failed connection is surfaced as a failed status")
    func failedConnectionSurfacesStatus() async {
        // Non-exhaustive: the wrapped error's exact `localizedDescription` isn't worth pinning
        // down in a test; only the resulting `.failed` case matters here.
        struct ConnectionError: Error {}
        let store = TestStore(initialState: DeviceDetailFeature.State(device: DiscoveredDeviceFixtures.plainSensor)) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bluetoothScanner.makeConnection = { _ in throw ConnectionError() }
        }
        store.exhaustivity = .off

        await store.send(.connectTapped)
        await store.receive(\.connectionEvent)
        await store.finish()

        guard case .failed = store.state.connectionStatus else {
            Issue.record("Expected a failed connection status, got \(store.state.connectionStatus)")
            return
        }
    }
}
