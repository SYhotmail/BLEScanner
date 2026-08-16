import BLEFeatures
import ComposableArchitecture
import SwiftUI

struct ScannerListView: View {
    let store: StoreOf<ScannerFeature>

    var body: some View {
        List {
            ForEach(store.filteredSortedDevices) { device in
                Button {
                    store.send(.rowTapped(device.id))
                } label: {
                    DeviceRowView(device: device)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("device.row.\(device.id)")
                .contextMenu {
                    if let beacon = device.beacon {
                        Button {
                            store.send(.trackBeaconTapped(beacon))
                        } label: {
                            Label("Track This Beacon", systemImage: "location.magnifyingglass")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if store.filteredSortedDevices.isEmpty {
                ContentUnavailableView(
                    store.isScanning ? "Scanning…" : "No Devices Found",
                    systemImage: "dot.radiowaves.left.and.right"
                )
            }
        }
    }
}
