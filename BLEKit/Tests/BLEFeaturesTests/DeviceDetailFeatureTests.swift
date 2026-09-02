import BLEKitCore
import BLEKitDependencies
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

        fakeConnection.send(.disconnected(reason: nil))
        await store.receive(\.connectionEvent) {
            $0.connectionStatus = .disconnected
            $0.services = []
        }

        fakeConnection.finish()
        await store.finish()
    }

    @Test("an unexpected disconnect keeps its reason and surfaces a reconnect affordance")
    func unexpectedDisconnectRetainsReason() async {
        let recorded = LockIsolated<[BLELogEvent]>([])
        let device = DiscoveredDeviceFixtures.plainSensor
        let fakeConnection = FakePeripheralConnectionClient(identifier: device.identifier)
        let store = TestStore(initialState: DeviceDetailFeature.State(device: device)) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bluetoothScanner.makeConnection = { _ in fakeConnection.client }
            $0.bleLog = LogClient { event in recorded.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off

        await store.send(.connectTapped)
        fakeConnection.send(.stateChanged(.connected))
        await store.receive(\.connectionEvent)
        fakeConnection.send(.servicesDiscovered(GATTFixtures.allServices))
        await store.receive(\.connectionEvent)

        fakeConnection.send(.disconnected(reason: "The specified device has disconnected from us."))
        await store.receive(\.connectionEvent) {
            $0.connectionStatus = .disconnected
            $0.services = []
            $0.disconnectReason = "The specified device has disconnected from us."
        }

        // Reconnecting clears the stale reason.
        await store.send(.connectTapped) {
            $0.connectionStatus = .connecting
            $0.disconnectReason = nil
        }

        fakeConnection.finish()
        await store.finish()

        #expect(recorded.value.contains(
            .peripheralDisconnected(
                identifier: device.identifier,
                name: device.name,
                reason: "The specified device has disconnected from us."
            )
        ))
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

    @Test("a characteristic value update for an included service is merged into that nested service")
    func characteristicUpdateMergesIntoIncludedService() async {
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

        var updatedCharacteristic = GATTFixtures.txPowerLevelCharacteristic
        updatedCharacteristic.latestValue = Data([0x09])

        await store.send(.readTapped(
            service: GATTFixtures.txPowerService.identifier,
            characteristic: updatedCharacteristic.identifier
        ))

        fakeConnection.send(.characteristicUpdated(
            serviceIdentifier: GATTFixtures.txPowerService.identifier,
            characteristic: updatedCharacteristic
        ))
        await store.receive(\.connectionEvent) {
            $0.services[id: GATTFixtures.genericAccessService.identifier]?
                .includedServices[0].characteristics[0] = updatedCharacteristic
        }

        fakeConnection.finish()
        await store.finish()
    }

    @Test("discovered descriptors survive a later characteristic value update that omits them")
    func descriptorsSurviveCharacteristicUpdate() async {
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

        // The fixture's Battery Level characteristic carries a CCCD descriptor.
        #expect(GATTFixtures.batteryLevelCharacteristic.descriptors.isEmpty == false)

        var updatedCharacteristic = GATTFixtures.batteryLevelCharacteristic
        updatedCharacteristic.latestValue = Data([0x2A])
        updatedCharacteristic.descriptors = []

        await store.send(.readTapped(
            service: GATTFixtures.batteryService.identifier,
            characteristic: updatedCharacteristic.identifier
        ))
        fakeConnection.send(.characteristicUpdated(
            serviceIdentifier: GATTFixtures.batteryService.identifier,
            characteristic: updatedCharacteristic
        ))
        await store.receive(\.connectionEvent) {
            var expected = updatedCharacteristic
            expected.descriptors = GATTFixtures.batteryLevelCharacteristic.descriptors
            $0.services[id: GATTFixtures.batteryService.identifier]?.characteristics[0] = expected
        }

        fakeConnection.finish()
        await store.finish()
    }

    @Test("reading descriptors merges the decoded value into the owning characteristic")
    func readingDescriptorMergesValue() async {
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

        let cccd = GATTIdentifier(rawValue: "2902")
        await store.send(.readDescriptorsTapped(
            service: GATTFixtures.batteryService.identifier,
            characteristic: GATTFixtures.batteryLevelCharacteristic.identifier
        ))

        // The hardware layer re-emits the whole characteristic with the descriptor value filled in.
        var updated = GATTFixtures.batteryLevelCharacteristic
        updated.descriptors = [GATTDescriptor(identifier: cccd, value: .uint(0x0001))]
        fakeConnection.send(.characteristicUpdated(
            serviceIdentifier: GATTFixtures.batteryService.identifier,
            characteristic: updated
        ))
        await store.receive(\.connectionEvent) {
            $0.services[id: GATTFixtures.batteryService.identifier]?.characteristics[0] = updated
        }

        let stored = store.state.services[id: GATTFixtures.batteryService.identifier]?.characteristics[0].descriptors.first
        #expect(stored?.value == .uint(0x0001))
        #expect(stored?.interpretedValue == "Notifications enabled")

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

    @Test("connect / disconnect transitions are recorded as critical events on the injected log")
    func connectionTransitionsRecordCriticalEvents() async {
        let recorded = LockIsolated<[BLELogEvent]>([])
        let device = DiscoveredDeviceFixtures.plainSensor
        let fakeConnection = FakePeripheralConnectionClient(identifier: device.identifier)
        let store = TestStore(initialState: DeviceDetailFeature.State(device: device)) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bluetoothScanner.makeConnection = { _ in fakeConnection.client }
            $0.bleLog = LogClient { event in recorded.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off

        await store.send(.connectTapped)
        fakeConnection.send(.stateChanged(.connected))
        await store.receive(\.connectionEvent)
        // A duplicate .connected event must not log a second time.
        fakeConnection.send(.stateChanged(.connected))
        await store.receive(\.connectionEvent)
        fakeConnection.send(.disconnected(reason: nil))
        await store.receive(\.connectionEvent)

        fakeConnection.finish()
        await store.finish()

        #expect(recorded.value == [
            .peripheralConnected(identifier: device.identifier, name: device.name),
            .peripheralDisconnected(identifier: device.identifier, name: device.name, reason: nil),
        ])
    }

    @Test("a GATT operation failure is recorded as a critical error event")
    func operationFailureRecordsCriticalEvent() async {
        let recorded = LockIsolated<[BLELogEvent]>([])
        let device = DiscoveredDeviceFixtures.plainSensor
        let fakeConnection = FakePeripheralConnectionClient(identifier: device.identifier)
        let store = TestStore(initialState: DeviceDetailFeature.State(device: device)) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bluetoothScanner.makeConnection = { _ in fakeConnection.client }
            $0.bleLog = LogClient { event in recorded.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off

        await store.send(.connectTapped)
        fakeConnection.send(.operationFailed(.characteristicNotFound))
        await store.receive(\.connectionEvent)

        fakeConnection.finish()
        await store.finish()

        #expect(recorded.value == [
            .peripheralOperationFailed(
                identifier: device.identifier,
                name: device.name,
                reason: "characteristicNotFound"
            ),
        ])
    }

    @Test("an invalid write input is recorded as a rejected-write critical event")
    func invalidWriteInputRecordsCriticalEvent() async {
        let recorded = LockIsolated<[BLELogEvent]>([])
        let store = TestStore(initialState: DeviceDetailFeature.State(device: DiscoveredDeviceFixtures.plainSensor)) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bleLog = LogClient { event in recorded.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off

        let characteristic = GATTFixtures.deviceNameCharacteristic.identifier
        await store.send(.writeFormatChanged(characteristic: characteristic, format: .hex))
        await store.send(.writeInputChanged(characteristic: characteristic, text: "ZZ"))
        await store.send(.writeTapped(service: GATTFixtures.genericAccessService.identifier, characteristic: characteristic))
        await store.finish()

        #expect(recorded.value == [
            .characteristicWriteRejected(
                characteristic: characteristic.rawValue,
                reason: "Hex input may only contain 0-9 and A-F."
            ),
        ])
    }

    @Test("a failed connection is recorded as a connection-failure critical event")
    func failedConnectionRecordsCriticalEvent() async {
        let recorded = LockIsolated<[BLELogEvent]>([])
        let device = DiscoveredDeviceFixtures.plainSensor
        let fakeConnection = FakePeripheralConnectionClient(identifier: device.identifier)
        let store = TestStore(initialState: DeviceDetailFeature.State(device: device)) {
            DeviceDetailFeature()
        } withDependencies: {
            $0.bluetoothScanner.makeConnection = { _ in fakeConnection.client }
            $0.bleLog = LogClient { event in recorded.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off

        await store.send(.connectTapped)
        fakeConnection.send(.stateChanged(.failed("out of range")))
        await store.receive(\.connectionEvent)

        fakeConnection.finish()
        await store.finish()

        #expect(recorded.value == [
            .peripheralConnectionFailed(identifier: device.identifier, name: device.name, reason: "out of range"),
        ])
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
