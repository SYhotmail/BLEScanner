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
            // Default scan mode is `.periodic`, which spawns a restart-quiet-timer effect
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

    @Test("continuous (periodic) scan mode restarts on a fixed 5s throttle, scanning with allowDuplicates: true, ignoring the scanPeriod setting")
    func continuousScanRestartsOnFixedThrottle() async {
        let fakeScanner = FakeBluetoothScannerClient()
        let clock = TestClock()
        var state = ScannerFeature.State()
        // Distractor: continuous mode's restart throttle is fixed, not sourced from settings —
        // only `.manual` mode's restart interval uses `scanPeriod`.
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
        #expect(fakeScanner.lastAllowDuplicates == true)

        // The distractor scanPeriod (2s) has no effect: nothing fires at 2s.
        await clock.advance(by: .seconds(2))
        #expect(fakeScanner.stopScanningCallCount == 0)
        #expect(fakeScanner.startScanningCallCount == 1)

        // The fixed 5s throttle fires 3s later (5s total).
        await clock.advance(by: .seconds(3))
        #expect(fakeScanner.stopScanningCallCount == 1)
        #expect(fakeScanner.startScanningCallCount == 2)
        #expect(fakeScanner.lastAllowDuplicates == true)

        await clock.advance(by: .seconds(5))
        #expect(fakeScanner.stopScanningCallCount == 2)
        #expect(fakeScanner.startScanningCallCount == 3)

        await store.send(.onDisappear)
        await store.finish()
    }

    @Test("a burst of advertisements is debounced into a single recompute once the stream is quiet")
    func advertisementRecomputeIsDebounced() async {
        let fakeScanner = FakeBluetoothScannerClient()
        let clock = TestClock()
        var state = ScannerFeature.State()
        state.$settings.withLock { $0.scanMode = .manual }
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

        await store.send(.scanToggleTapped)

        let advertisement = BLEAdvertisement(
            identifier: DiscoveredDeviceFixtures.plainSensor.identifier,
            name: "Living Room Sensor",
            rssi: -55,
            isConnectable: true,
            serviceIdentifiers: [],
            manufacturerData: nil
        )
        fakeScanner.send(.discovered(advertisement))
        await store.skipReceivedActions()

        // Still within the debounce window: the underlying device data updated, but the
        // filtered/sorted snapshot the UI reads hasn't been rebuilt yet.
        #expect(store.state.devices[id: advertisement.identifier]?.rssi == -55)
        #expect(store.state.filteredSortedDevices.isEmpty)

        await clock.advance(by: .milliseconds(300))
        await store.skipReceivedActions()

        #expect(store.state.filteredSortedDevices.map(\.id) == [advertisement.identifier])

        fakeScanner.finish()
        await store.send(.scanToggleTapped)
        await store.finish()
    }

    @Test("manual scan mode restarts on a quiet timer sourced from settings.scanPeriod, scanning with allowDuplicates: false")
    func manualScanRestartUsesConfiguredScanPeriod() async {
        let fakeScanner = FakeBluetoothScannerClient()
        let clock = TestClock()
        var state = ScannerFeature.State()
        state.$settings.withLock {
            $0.scanMode = .manual
            $0.scanPeriod = 2
        }
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

        await store.send(.scanToggleTapped)
        #expect(fakeScanner.startScanningCallCount == 1)
        #expect(fakeScanner.lastAllowDuplicates == false)

        let advertisement = BLEAdvertisement(
            identifier: DiscoveredDeviceFixtures.plainSensor.identifier,
            name: "Living Room Sensor",
            rssi: -55,
            isConnectable: true,
            serviceIdentifiers: [],
            manufacturerData: nil
        )

        // An advertisement arrives every 1s — less than the 2s period — so the quiet timer
        // keeps getting cancelled and re-seeded, and the restart never actually fires.
        for _ in 0 ..< 3 {
            await clock.advance(by: .seconds(1))
            fakeScanner.send(.discovered(advertisement))
            await store.skipReceivedActions()
        }
        #expect(fakeScanner.stopScanningCallCount == 0)
        #expect(fakeScanner.startScanningCallCount == 1)

        // Now the stream goes quiet: once a full period passes with no further advertisements,
        // the restart fires.
        await clock.advance(by: .seconds(2))
        #expect(fakeScanner.stopScanningCallCount == 1)
        #expect(fakeScanner.startScanningCallCount == 2)
        #expect(fakeScanner.lastAllowDuplicates == false)

        fakeScanner.finish()
        await store.send(.scanToggleTapped)
        await store.finish()
    }

    @Test("rescanTapped does nothing when not currently scanning")
    func rescanTappedNoOpWhenNotScanning() async {
        let store = TestStore(initialState: ScannerFeature.State()) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.rescanTapped)
    }

    @Test("rescanTapped immediately restarts the underlying scan while scanning")
    func rescanTappedRestartsScanWhileScanning() async {
        let fakeScanner = FakeBluetoothScannerClient()
        var state = ScannerFeature.State()
        state.$settings.withLock { $0.scanMode = .manual }
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.bluetoothScanner = fakeScanner.client
            $0.continuousClock = TestClock()
        }
        store.exhaustivity = .off

        await store.send(.scanToggleTapped)
        #expect(fakeScanner.startScanningCallCount == 1)
        #expect(fakeScanner.lastAllowDuplicates == false)

        await store.send(.rescanTapped)
        #expect(fakeScanner.stopScanningCallCount == 1)
        #expect(fakeScanner.startScanningCallCount == 2)
        #expect(fakeScanner.lastAllowDuplicates == false)

        fakeScanner.finish()
        await store.send(.scanToggleTapped)
        await store.finish()
    }

    @Test("rescanTapped re-seeds continuous scan mode's fixed restart quiet timer")
    func rescanTappedResetsContinuousRestartTimer() async {
        let fakeScanner = FakeBluetoothScannerClient()
        let clock = TestClock()
        var state = ScannerFeature.State()
        // Distractor: continuous mode ignores scanPeriod for its restart interval.
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

        // Rescan 2s into the fixed 5s quiet period - this both restarts the scan immediately
        // and re-seeds the restart timer.
        await clock.advance(by: .seconds(2))
        await store.send(.rescanTapped)
        #expect(fakeScanner.stopScanningCallCount == 1)
        #expect(fakeScanner.startScanningCallCount == 2)

        // Without the reseed, the original timer would have fired 3s from now; since it was
        // reseeded, it takes a further full 5s to fire.
        await clock.advance(by: .seconds(3))
        #expect(fakeScanner.stopScanningCallCount == 1)

        await clock.advance(by: .seconds(2))
        #expect(fakeScanner.stopScanningCallCount == 2)
        #expect(fakeScanner.startScanningCallCount == 3)

        fakeScanner.finish()
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

    @Test("displayMode is seeded from settings.defaultDisplayMode once and isn't reset by a later onAppear")
    func displayModeSeededOnceNotResetByOnAppear() async {
        let fakeScanner = FakeBluetoothScannerClient()

        // Written via a throwaway state's own $settings, then read back by a *second*,
        // freshly-constructed `State()` below — @Shared storage is keyed by the storage key,
        // not by which State instance wrote it, so this simulates "settings already had a
        // non-default value when this screen was first created."
        var seedState = ScannerFeature.State()
        seedState.$settings.withLock {
            $0.defaultDisplayMode = .radar
            $0.scanMode = .manual
        }

        let state = ScannerFeature.State()
        #expect(state.displayMode == .radar)

        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.bluetoothScanner = fakeScanner.client
            $0.beaconRanging = FakeBeaconRangingClient().client
            $0.history = InMemoryHistoryClient().client
        }
        store.exhaustivity = .off

        await store.send(.displayModeToggled) {
            $0.displayMode = .list
        }

        // Simulates DeviceDetail being pushed then popped back to Scanner: onAppear fires again
        // on the same persistent state, and must not stomp the user's manual toggle back to the
        // settings default.
        await store.send(.onAppear)
        await store.skipReceivedActions()
        #expect(store.state.displayMode == .list)

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
            $0.continuousClock = TestClock()
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
    
    private static func recomputeFilteredSortedDevices(state: inout ScannerFeature.State) {
        state.recomputeFilteredSortedDevices()
    }

    @Test("filteredSortedDevices applies the shared filter criteria and sorts by RSSI")
    func filteredSortedDevicesAppliesFilterAndSort() {
        var state = ScannerFeature.State()
        state.devices = [
            DiscoveredDeviceFixtures.weakSignalDevice,
            DiscoveredDeviceFixtures.plainSensor,
            DiscoveredDeviceFixtures.unnamedDevice,
        ]
        Self.recomputeFilteredSortedDevices(state: &state)

        #expect(state.filteredSortedDevices.map(\.id) == [
            DiscoveredDeviceFixtures.plainSensor.id,
            DiscoveredDeviceFixtures.unnamedDevice.id,
            DiscoveredDeviceFixtures.weakSignalDevice.id,
        ])
    }

    @Test("changing the shared filter criteria recomputes the cached filtered/sorted devices")
    func recomputeFilteredDevicesReflectsFilterCriteriaChange() async {
        var state = ScannerFeature.State()
        state.devices = [
            DiscoveredDeviceFixtures.weakSignalDevice,
            DiscoveredDeviceFixtures.plainSensor,
        ]
        Self.recomputeFilteredSortedDevices(state: &state)
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        #expect(store.state.filteredSortedDevices.count == 2)

        store.state.$filterCriteria.withLock {
            $0.isRSSIFilterEnabled = true
            $0.minimumRSSI = -60
        }

        await store.send(.recomputeFilteredDevices)
        await store.receive(\.filteredSortedDevicesComputed) {
            $0.filteredSortedDevices = [DiscoveredDeviceFixtures.plainSensor]
        }
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

    @Test("rawAdvertisementDataCopyTapped copies the device's advertisement text and clears the toast after a delay")
    func rawAdvertisementDataCopyTappedCopiesAndClearsFeedback() async {
        let clock = TestClock()
        let copiedText = LockIsolated<String?>(nil)
        var state = ScannerFeature.State()
        state.devices = [DiscoveredDeviceFixtures.iBeaconDevice]
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.continuousClock = clock
            $0.pasteboard.setString = { copiedText.setValue($0) }
        }

        await store.send(.rawAdvertisementDataCopyTapped(DiscoveredDeviceFixtures.iBeaconDevice.id)) {
            $0.copyFeedbackDeviceID = DiscoveredDeviceFixtures.iBeaconDevice.id
        }
        #expect(copiedText.value == RawAdvertisementDataBuilder.plainTextDescription(for: DiscoveredDeviceFixtures.iBeaconDevice))

        await clock.advance(by: .seconds(2))
        await store.receive(\.copyFeedbackTimedOut) {
            $0.copyFeedbackDeviceID = nil
        }
    }

    @Test("rawAdvertisementDataCopyTapped does nothing for an unknown device id")
    func rawAdvertisementDataCopyTappedNoOpForUnknownDevice() async {
        let store = TestStore(initialState: ScannerFeature.State()) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.rawAdvertisementDataCopyTapped(DiscoveredDeviceFixtures.iBeaconDevice.id))
    }

    @Test("favoriteToggled stars a connectable device and adds it to favoriteSortedDevices")
    func favoriteToggledStarsConnectableDevice() async {
        var device = DiscoveredDeviceFixtures.plainSensor
        device.isConnectable = true
        var state = ScannerFeature.State()
        state.devices = [device]
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.favoriteToggled(device.id)) {
            $0.$favoriteDeviceIdentifiers.withLock { _ = $0.insert(device.id) }
        }
        await store.receive(\.filteredSortedDevicesComputed) {
            $0.filteredSortedDevices = [device]
            $0.favoriteSortedDevices = [device]
        }

        // Toggling again un-stars it.
        await store.send(.favoriteToggled(device.id)) {
            $0.$favoriteDeviceIdentifiers.withLock { _ = $0.remove(device.id) }
        }
        await store.receive(\.filteredSortedDevicesComputed) {
            $0.favoriteSortedDevices = []
        }
    }

    @Test("favoriteToggled does nothing for a non-connectable device")
    func favoriteToggledNoOpForNonConnectableDevice() async {
        var state = ScannerFeature.State()
        state.devices = [DiscoveredDeviceFixtures.plainSensor] // not connectable
        let store = TestStore(initialState: state) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.favoriteToggled(DiscoveredDeviceFixtures.plainSensor.id))
    }

    @Test("favoriteToggled does nothing for an unknown device id")
    func favoriteToggledNoOpForUnknownDevice() async {
        let store = TestStore(initialState: ScannerFeature.State()) {
            ScannerFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.favoriteToggled(DiscoveredDeviceFixtures.plainSensor.id))
    }

    @Test("a ranged beacon result overrides the RSSI-heuristic proximity for matching devices")
    func rangedBeaconOverridesProximity() async {
        var state = ScannerFeature.State()
        state.devices = [DiscoveredDeviceFixtures.iBeaconDevice]
        Self.recomputeFilteredSortedDevices(state: &state)
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
        await store.receive(\.filteredSortedDevicesComputed) {
            $0.filteredSortedDevices[id: DiscoveredDeviceFixtures.iBeaconDevice.id]?.beacon?.rangedProximity = .immediate
        }
    }
}
