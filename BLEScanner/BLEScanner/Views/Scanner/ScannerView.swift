import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct ScannerView: View {
    @Bindable var store: StoreOf<ScannerFeature>

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: tabBinding) {
                Text("Near By").tag(ScanTab.nearby)
                Text("History").tag(ScanTab.history)
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityIdentifier("scanner.tabPicker")

            switch store.tab {
            case .nearby:
                nearByContent
            case .history:
                HistoryView(store: store.scope(state: \.history, action: \.history))
            }
        }
        .navigationTitle("Scanner")
        .toolbar {
            if store.tab == .nearby {
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
                ScannerListView(store: store)
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
