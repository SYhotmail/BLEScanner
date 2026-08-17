import BLEKitCore
import BLEKitHardware
import BLEKitTestSupport
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing
@testable import BLEFeatures

@MainActor
@Suite("ScannerFeature", .dependencies)
struct ScannerFeatureTests {
    @Test("onAppear starts scanning and upserts discovered devices into history")
    func onAppearDiscoversAndRecordsHistory() async {
        // Non-exhaustive: `onAppear` merges several effects (history load, scan stream, start
        // ranging check) whose resulting actions can interleave in either order, so this drains
        // everything and asserts final state rather than an exact action sequence.
        let fakeScanner = FakeBluetoothScannerClient()
        let historyClient = InMemoryHistoryClient()
        let store = TestStore(initialState: ScannerFeature.State()) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.bluetoothScanner = fakeScanner.client
            $0.beaconRanging = FakeBeaconRangingClient().client
            $0.history = historyClient.client
            // Default scan mode is `.periodic`, which spawns a periodic-restart timer effect
            // alongside the scan stream; a `TestClock` that's never advanced keeps it suspended
            // instead of firing, and `.onDisappear` below cancels it before `store.finish()`.
            $0.continuousClock = TestClock()
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.skipReceivedActions()

        let advertisement = BLEAdvertisement(
            identifier: DiscoveredDeviceFixtures.plainSensor.identifier,
            name: "Living Room Sensor",
            rssi: -55,
            isConnectable: true,
            serviceIdentifiers: [],
            manufacturerData: nil
        )
        fakeScanner.send(.discovered(advertisement))
        fakeScanner.finish()
        await store.skipReceivedActions()

        #expect(store.state.devices[id: advertisement.identifier]?.rssi == -55)
        #expect(store.state.devices[id: advertisement.identifier]?.name == "Living Room Sensor")
        #expect(store.state.history.records[id: advertisement.identifier.uuidString]?.lastRSSI == -55)

        await store.send(.onDisappear)
        await store.finish()
    }

    @Test("periodic scan mode restarts the underlying scan on each tick of the configured period")
    func periodicScanRestartsOnEachTick() async {
        let fakeScanner = FakeBluetoothScannerClient()
        let clock = TestClock()
        var state = ScannerFeature.State()
        state.$settings.withLock { $0.scanPeriod = 2 }
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.bluetoothScanner = fakeScanner.client
            $0.beaconRanging = FakeBeaconRangingClient().client
            $0.history = InMemoryHistoryClient().client
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.skipReceivedActions()
        #expect(fakeScanner.startScanningCallCount == 1)

        await clock.advance(by: .seconds(2))
        #expect(fakeScanner.stopScanningCallCount == 1)
        #expect(fakeScanner.startScanningCallCount == 2)

        await clock.advance(by: .seconds(2))
        #expect(fakeScanner.stopScanningCallCount == 2)
        #expect(fakeScanner.startScanningCallCount == 3)

        await store.send(.onDisappear)
        await store.finish()
    }

    @Test("onAppear does not start scanning when scan mode is manual")
    func onAppearDoesNotScanWhenManual() async {
        let fakeScanner = FakeBluetoothScannerClient()
        var state = ScannerFeature.State()
        state.$settings.withLock { $0.scanMode = .manual }
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.bluetoothScanner = fakeScanner.client
            $0.beaconRanging = FakeBeaconRangingClient().client
            $0.history = InMemoryHistoryClient().client
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.skipReceivedActions()

        #expect(store.state.isScanning == false)

        fakeScanner.finish()
        await store.finish()
    }

    @Test("scanToggleTapped starts and stops scanning when scan mode is manual")
    func scanToggleTappedStartsAndStopsScanningWhenManual() async {
        let fakeScanner = FakeBluetoothScannerClient()
        let state = ScannerFeature.State()
        state.$settings.withLock { $0.scanMode = .manual }
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.bluetoothScanner = fakeScanner.client
        }
        store.exhaustivity = .off

        await store.send(.scanToggleTapped) {
            $0.isScanning = true
        }
        await store.send(.scanToggleTapped) {
            $0.isScanning = false
        }

        fakeScanner.finish()
        await store.finish()
    }

    @Test("scanToggleTapped does nothing when scan mode is periodic")
    func scanToggleTappedNoOpWhenPeriodic() async {
        let store = TestStore(initialState: ScannerFeature.State()) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.scanToggleTapped)
    }

    @Test("filteredSortedDevices applies the shared filter criteria and sorts by RSSI")
    func filteredSortedDevicesAppliesFilterAndSort() {
        var state = ScannerFeature.State()
        state.devices = [
            DiscoveredDeviceFixtures.weakSignalDevice,
            DiscoveredDeviceFixtures.plainSensor,
            DiscoveredDeviceFixtures.unnamedDevice,
        ]

        #expect(state.filteredSortedDevices.map(\.id) == [
            DiscoveredDeviceFixtures.plainSensor.id,
            DiscoveredDeviceFixtures.unnamedDevice.id,
            DiscoveredDeviceFixtures.weakSignalDevice.id,
        ])
    }

    @Test("rowTapped presents the device detail screen")
    func rowTappedPresentsDeviceDetail() async {
        var state = ScannerFeature.State()
        state.devices = [DiscoveredDeviceFixtures.plainSensor]
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.rowTapped(DiscoveredDeviceFixtures.plainSensor.id)) {
            $0.destination = DeviceDetailFeature.State(device: DiscoveredDeviceFixtures.plainSensor)
        }
    }

    @Test("connectTapped presents the device detail screen and starts connecting")
    func connectTappedPresentsDeviceDetailAndConnects() async {
        let fakeConnection = FakePeripheralConnectionClient(identifier: DiscoveredDeviceFixtures.plainSensor.identifier)
        var state = ScannerFeature.State()
        state.devices = [DiscoveredDeviceFixtures.plainSensor]
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.bluetoothScanner.makeConnection = { _ in fakeConnection.client }
        }

        await store.send(.connectTapped(DiscoveredDeviceFixtures.plainSensor.id)) {
            $0.destination = DeviceDetailFeature.State(device: DiscoveredDeviceFixtures.plainSensor)
        }
        await store.receive(\.destination.presented.connectTapped) {
            $0.destination?.connectionStatus = .connecting
        }

        fakeConnection.finish()
        await store.finish()
    }

    @Test("trackBeaconTapped registers a known beacon and starts ranging when enabled")
    func trackBeaconTappedRegistersAndStartsRanging() async {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let fakeRanging = FakeBeaconRangingClient()
        let state = ScannerFeature.State()
        state.$settings.withLock { $0.isEnhancedRangingEnabled = true }
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.beaconRanging = fakeRanging.client
            $0.date = .constant(fixedDate)
        }

        let beaconUUID = UUID(uuidString: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")!
        let beacon = BeaconReading(uuid: beaconUUID, major: 1, minor: 2, measuredPower: -59)

        await store.send(.trackBeaconTapped(beacon)) {
            $0.$knownBeacons.withLock {
                $0.append(KnownBeacon(uuid: beaconUUID, label: "Beacon \(beaconUUID.uuidString.prefix(8))", dateAdded: fixedDate))
            }
        }
        await store.receive(\.startRangingIfNeeded)

        fakeRanging.finish()
        await store.finish()
    }

    @Test("a ranged beacon result overrides the RSSI-heuristic proximity for matching devices")
    func rangedBeaconOverridesProximity() async {
        var state = ScannerFeature.State()
        state.devices = [DiscoveredDeviceFixtures.iBeaconDevice]
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        let beaconUUID = DiscoveredDeviceFixtures.iBeaconDevice.beacon!.uuid
        let ranged = RangedBeacon(uuid: beaconUUID, major: 1, minor: 2, proximity: .immediate, accuracyMeters: 0.2)

        await store.send(.beaconRangingEvent(.rangedBeacons([ranged]))) {
            $0.devices[id: DiscoveredDeviceFixtures.iBeaconDevice.id]?.beacon?.rangedProximity = .immediate
        }
    }
}
