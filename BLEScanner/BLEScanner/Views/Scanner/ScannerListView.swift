import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct ScannerListView: View {
    let store: StoreOf<ScannerFeature>

    var body: some View {
        let devices = store.filteredSortedDevices
        List {
            ForEach(devices) { device in
                ScannerDeviceRow(store: store, device: device)
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
        .overlay {
            if let device = store.rawAdvertisementDataDevice {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            store.send(.rawAdvertisementDataDismissed)
                        }
                    RawAdvertisementDataView(device: device) {
                        store.send(.rawAdvertisementDataDismissed)
                    } onCopy: {
                        store.send(.rawAdvertisementDataCopyTapped($0.id))
                    }
                    .padding(32)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: store.rawAdvertisementDataDevice)
        .toast(isPresented: store.copyFeedbackDeviceID != nil, message: "Copied to Clipboard")
    }
}

/// A single scanner row plus its long-press behavior. Long-pressing performs whichever of
/// "Track This Beacon" / "Raw Advertisement Data" applies directly — no intermediate menu tap —
/// falling back to a picker only when both apply to the same row (e.g. a non-connectable
/// beacon that also carries other advertisement data), and a haptic when neither does.
private struct ScannerDeviceRow: View {
    let store: StoreOf<ScannerFeature>
    let device: DiscoveredDevice

    @State private var isActionChoicePresented = false
    @State private var nothingToShowFeedbackTrigger = false

    private var deviceId: DiscoveredDevice.ID { device.id }

    private var hasRawAdvertisementData: Bool {
        !device.isConnectable && !RawAdvertisementDataBuilder.structures(for: device).isEmpty
    }

    var tapGesture: some Gesture {
        TapGesture().onEnded {
            store.send(.rawAdvertisementDataCopyTapped(deviceId))
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.send(.rowTapped(deviceId))
            } label: {
                DeviceRowView(device: device)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("device.row.\(deviceId)")
            .disabled(!device.isConnectable)

            if device.isConnectable {
                Button("Connect") {
                    store.send(.connectTapped(deviceId))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("device.row.connectButton.\(deviceId)")
            } else {
                VStack(alignment: .trailing, spacing: 20) {
                    Text("Not Connectable")
                        .font(.caption2)
                    
                }.foregroundStyle(.red)
            }
        }
        .overlay(alignment: .topTrailing) {
            if hasRawAdvertisementData {
                Image(systemName: "doc.on.clipboard")
                    .font(.caption)
                     .padding()
                     .padding(.bottom.union(.trailing), 10) //extra space on Non Connectable text.
                .accessibilityLabel("Raw advertisement data available. Long press to view.")
                .accessibilityIdentifier("device.row.rawDataIndicator.\(deviceId)")
            }
        }
        .simultaneousGesture(tapGesture, isEnabled: hasRawAdvertisementData)
        .onLongPressGesture {
            handleLongPress()
        }
        .sensoryFeedback(.warning, trigger: nothingToShowFeedbackTrigger)
        .confirmationDialog(
            "Choose an Action",
            isPresented: $isActionChoicePresented,
            titleVisibility: .visible
        ) {
            if let beacon = device.beacon {
                Button("Track This Beacon") {
                    store.send(.trackBeaconTapped(beacon))
                }
            }
            if hasRawAdvertisementData {
                Button("Raw Advertisement Data") {
                    store.send(.rawAdvertisementDataTapped(deviceId))
                }
            }
        }
    }

    private func handleLongPress() {
        switch (device.beacon, hasRawAdvertisementData) {
        case let (.some(beacon), false):
            store.send(.trackBeaconTapped(beacon))
        case (.none, true):
            store.send(.rawAdvertisementDataTapped(deviceId))
        case (.some, true):
            isActionChoicePresented = true
        case (.none, false):
            guard !device.isConnectable else { return }
            nothingToShowFeedbackTrigger.toggle()
        }
    }
}
