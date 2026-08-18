import BLEFeatures
import ComposableArchitecture
import SwiftUI

struct ScannerListView: View {
    let store: StoreOf<ScannerFeature>

    var body: some View {
        let devices = store.filteredSortedDevices
        List {
            ForEach(devices) { device in
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
                    } else {
                        Text("Not Connectable")
                            .font(.caption2)
                            .foregroundStyle(.red)
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
                .disabled(!device.isConnectable)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await store.send(.rescanTapped).finish()
        }
        .overlay {
            if devices.isEmpty {
                ContentUnavailableView(
                    store.isScanning ? "Scanning…" : "No Devices Found",
                    systemImage: "dot.radiowaves.left.and.right"
                )
            }
        }
    }
}
