import BLEKitCore
import BLEKitTestSupport
import ComposableArchitecture
import DependenciesTestSupport
import Testing
@testable import BLEFeatures

@MainActor
@Suite("AppFeature", .dependencies)
struct AppFeatureTests {
    @Test("sidebarSelectionChanged updates the selected destination and closes the drawer")
    func sidebarSelectionChangedUpdatesSelection() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        #expect(store.state.sidebarSelection == .scanner)

        await store.send(.sidebarOpened) {
            $0.isSidebarOpen = true
        }
        await store.send(.sidebarSelectionChanged(.filter)) {
            $0.sidebarSelection = .filter
            $0.isSidebarOpen = false
        }
        await store.send(.sidebarOpened) {
            $0.isSidebarOpen = true
        }
        await store.send(.sidebarSelectionChanged(.settings)) {
            $0.sidebarSelection = .settings
            $0.isSidebarOpen = false
        }
    }

    @Test("sidebarOpened and sidebarClosed toggle the drawer")
    func sidebarOpenedAndClosedToggleDrawer() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
        }

        #expect(store.state.isSidebarOpen == false)

        await store.send(.sidebarOpened) {
            $0.isSidebarOpen = true
        }
        await store.send(.sidebarClosed) {
            $0.isSidebarOpen = false
        }
    }

    @Test("enabling enhanced ranging in Settings tells Scanner to start ranging")
    func enablingRangingTellsScannerToStart() async {
        let fakeRanging = FakeBeaconRangingClient()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.beaconRanging = fakeRanging.client
        }

        await store.send(.settings(.enhancedRangingToggled(true))) {
            $0.settings.$settings.withLock { $0.isEnhancedRangingEnabled = true }
        }
        await store.receive(\.scanner.startRangingIfNeeded)
    }

    @Test("disabling enhanced ranging in Settings tells Scanner to stop ranging")
    func disablingRangingTellsScannerToStop() async {
        let fakeRanging = FakeBeaconRangingClient()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.defaultAppStorage = .inMemory
            $0.beaconRanging = fakeRanging.client
        }

        await store.send(.settings(.enhancedRangingToggled(false))) {
            $0.settings.$settings.withLock { $0.isEnhancedRangingEnabled = false }
        }
        await store.receive(\.scanner.stopRanging)
    }
}
