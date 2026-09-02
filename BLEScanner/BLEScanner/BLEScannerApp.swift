import BLEFeatures
import ComposableArchitecture
import SwiftUI

#if DEBUG
import BLEKitTestSupport
#endif

@main
struct BLEScannerApp: App {
    @State
    var store: StoreOf<AppFeature> = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            return withDependencies {
                $0.defaultAppStorage = .inMemory
                let connectionCache = AutopilotConnectionCache()
                let scanner = FakeBluetoothScannerClient(
                    connectionProvider: { identifier in
                        connectionCache.connection(for: identifier)
                    }
                )
                scanner.send(.stateChanged(.poweredOn))
                scanner.send(.discovered(UITestFixtures.sensorAdvertisement))
                scanner.send(.discovered(UITestFixtures.garageAdvertisement))
                $0.bluetoothScanner = scanner.client
                $0.beaconRanging = FakeBeaconRangingClient().client
                $0.history = InMemoryHistoryClient(seed: HistoryRecordFixtures.all).client
                $0.bleLog = .disabled
            } operation: {
                Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            }
        }
        #endif
        return Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
