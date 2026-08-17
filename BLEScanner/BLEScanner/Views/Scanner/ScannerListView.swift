import BLEFeatures
import ComposableArchitecture
import SwiftUI

struct ScannerListView: View {
    let store: StoreOf<ScannerFeature>

    var body: some View {
        List {
            ForEach(store.filteredSortedDevices) { device in
                let deviceId = device.id
                HStack(spacing: 12) {
                    Button {
                        store.send(.rowTapped(deviceId))
                    } label: {
                        DeviceRowView(device: device)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("device.row.\(deviceId)")

                    if device.isConnectable {
                        Button("Connect") {
                            store.send(.connectTapped(deviceId))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("device.row.connectButton.\(deviceId)")
                    }
                }
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
