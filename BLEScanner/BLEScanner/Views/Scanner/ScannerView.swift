import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct ScannerView: View {
    @Bindable var store: StoreOf<ScannerFeature>

    @State private var searchText = ""
    @State private var isSearchPresented = false
    
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
                    searchText: $searchText,
                    isSearchPresented: $isSearchPresented
                )
            case .favorites:
                FavoritesListView(
                    store: store,
                    searchText: $searchText,
                    isSearchPresented: $isSearchPresented
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
            if store.tab == .nearby || store.tab == .favorites {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort By", selection: Binding(
                            get: { store.settings.sortOrder },
                            set: { store.send(.sortOrderChanged($0)) }
                        )) {
                            Label("Signal Strength", systemImage: "cellularbars").tag(ScanSortOrder.rssi)
                            Label("Discovery Order", systemImage: "clock").tag(ScanSortOrder.appearance)
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityIdentifier("scanner.sortMenu")
                    .accessibilityLabel("Sort Order")
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
                    searchText: $searchText,
                    isSearchPresented: $isSearchPresented
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
