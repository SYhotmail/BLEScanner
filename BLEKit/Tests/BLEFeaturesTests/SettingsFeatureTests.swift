import BLEKitCore
import BLEKitHardware
import BLEKitTestSupport
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing
@testable import BLEFeatures

@MainActor
@Suite("SettingsFeature", .dependencies)
struct SettingsFeatureTests {
    @Test("enabling ranging updates settings and requests authorization")
    func enablingRangingRequestsAuthorization() async {
        let fakeRanging = FakeBeaconRangingClient()
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.beaconRanging = fakeRanging.client
        }

        await store.send(.enhancedRangingToggled(true)) {
            $0.$settings.withLock { $0.isEnhancedRangingEnabled = true }
        }
    }

    @Test("disabling ranging updates settings without requesting authorization")
    func disablingRangingSkipsAuthorization() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.enhancedRangingToggled(false)) {
            $0.$settings.withLock { $0.isEnhancedRangingEnabled = false }
        }
    }

    @Test("changing scan mode updates shared settings")
    func changingScanModeUpdatesSettings() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.scanModeChanged(.manual)) {
            $0.$settings.withLock { $0.scanMode = .manual }
        }
    }

    @Test("changing the scan period updates shared settings")
    func changingScanPeriodUpdatesSettings() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.scanPeriodChanged(5)) {
            $0.$settings.withLock { $0.scanPeriod = 5 }
        }
    }

    @Test("changing the sort order updates shared settings")
    func changingSortOrderUpdatesSettings() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.sortOrderChanged(.appearance)) {
            $0.$settings.withLock { $0.sortOrder = .appearance }
        }
    }

    @Test("tapping and dismissing the scan period picker toggles its presentation")
    func scanPeriodPickerPresentationToggles() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        await store.send(.scanPeriodPickerTapped) {
            $0.isScanPeriodPickerPresented = true
        }
        await store.send(.scanPeriodPickerDismissed) {
            $0.isScanPeriodPickerPresented = false
        }
    }

    @Test("onAppear surfaces authorization changes from the ranging client")
    func onAppearSurfacesAuthorizationChanges() async {
        let fakeRanging = FakeBeaconRangingClient()
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.beaconRanging = fakeRanging.client
        }

        await store.send(.onAppear)
        fakeRanging.send(.authorizationChanged(.authorizedWhenInUse))
        await store.receive(\.authorizationEvent) {
            $0.locationAuthorizationStatus = .authorizedWhenInUse
        }

        fakeRanging.finish()
        await store.finish()
    }

    @Test("adding a known beacon via the sheet appends it and dismisses the sheet")
    func addingKnownBeaconAppendsAndDismisses() async {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.date = .constant(fixedDate)
        }

        await store.send(.addKnownBeaconTapped) {
            $0.addBeaconForm = AddKnownBeaconFeature.State()
        }

        let uuid = UUID(uuidString: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")!
        await store.send(.addBeaconForm(.presented(.uuidChanged(uuid.uuidString)))) {
            $0.addBeaconForm?.uuidText = uuid.uuidString
        }
        await store.send(.addBeaconForm(.presented(.saveTapped)))
        await store.receive(\.addBeaconForm.presented.delegate.saved) {
            $0.$knownBeacons.withLock {
                $0.append(KnownBeacon(uuid: uuid, label: uuid.uuidString, dateAdded: fixedDate))
            }
            $0.addBeaconForm = nil
        }
    }

    @Test("deleting a known beacon removes it from shared storage")
    func deletingKnownBeaconRemovesIt() async {
        let beacon = KnownBeacon(uuid: UUID(), label: "Kitchen", dateAdded: .now)
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }
        store.state.$knownBeacons.withLock { $0 = [beacon] }

        await store.send(.knownBeaconDeleted(IndexSet(integer: 0))) {
            $0.$knownBeacons.withLock { $0.remove(atOffsets: IndexSet(integer: 0)) }
        }
    }
}
