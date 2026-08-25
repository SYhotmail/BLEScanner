import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct ScannerView: View {
    @Bindable var store: StoreOf<ScannerFeature>

    // One (searchText, isSearchPresented) pair per tab, held here rather than in each tab's own
    // view, since `store.tab`/`store.displayMode` switching below tears down and recreates those
    // child views on every change — state owned by them would reset every time. `ScannerView`
    // itself isn't torn down by either switch, so state hoisted here survives.
    @State private var nearbySearchText = ""
    @State private var nearbyIsSearchPresented = false
    @State private var historySearchText = ""
    @State private var historyIsSearchPresented = false
    @State private var favoritesSearchText = ""
    @State private var favoritesIsSearchPresented = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: tabBinding) {
                Text("Near By").tag(ScanTab.nearby)
                Text("History").tag(ScanTab.history)
                Text("Favorites").tag(ScanTab.favorites)
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityIdentifier("scanner.tabPicker")

            switch store.tab {
            case .nearby:
                nearByContent
            case .history:
                HistoryView(
                    store: store.scope(state: \.history, action: \.history),
                    searchText: $historySearchText,
                    isSearchPresented: $historyIsSearchPresented
                )
            case .favorites:
                FavoritesListView(
                    store: store,
                    searchText: $favoritesSearchText,
                    isSearchPresented: $favoritesIsSearchPresented
                )
            }
        }
        .navigationTitle("Scanner")
        .toolbar {
            if store.tab == .nearby {
                if store.settings.scanMode == .manual {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.send(.scanToggleTapped)
                        } label: {
                            Image(systemName: store.isScanning ? "stop.circle" : "play.circle")
                        }
                        .accessibilityIdentifier(store.isScanning ? "scanner.stopScanButton" : "scanner.startScanButton")
                        .accessibilityLabel(store.isScanning ? "Stop Scanning" : "Start Scanning")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.displayModeToggled)
                    } label: {
                        Image(systemName: store.displayMode == .list ? "target" : "list.bullet")
                    }
                    .accessibilityLabel(store.displayMode == .list ? "Show Radar" : "Show List")
                }
            }
        }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { detailStore in
            DeviceDetailView(store: detailStore)
        }
    }

    @ViewBuilder
    private var nearByContent: some View {
        if store.bluetoothState != .poweredOn, store.bluetoothState != .unknown {
            ContentUnavailableView(
                "Bluetooth Unavailable",
                systemImage: "antenna.radiowaves.left.and.right.slash",
                description: Text(bluetoothStateDescription)
            )
        } else {
            switch store.displayMode {
            case .list:
                ScannerListView(
                    store: store,
                    searchText: $nearbySearchText,
                    isSearchPresented: $nearbyIsSearchPresented
                )
            case .radar:
                ScannerRadarView(store: store)
            }
        }
    }

    private var bluetoothStateDescription: String {
        switch store.bluetoothState {
        case .poweredOff: "Turn on Bluetooth to scan for nearby devices."
        case .unauthorized: "Allow Bluetooth access in Settings to scan for nearby devices."
        case .unsupported: "This device doesn't support Bluetooth Low Energy."
        case .resetting: "Bluetooth is resetting."
        case .unknown, .poweredOn: ""
        }
    }

    private var tabBinding: Binding<ScanTab> {
        Binding(get: { store.tab }, set: { store.send(.tabChanged($0)) })
    }
}
