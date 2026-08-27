import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct ScannerListView: View {
    let store: StoreOf<ScannerFeature>
    @Binding var searchText: String
    @Binding var isSearchPresented: Bool

    var body: some View {
        SearchableList(
            items: store.filteredSortedDevices,
            matches: SearchMatcher.matches,
            searchText: $searchText,
            isSearchPresented: $isSearchPresented
        ) { device in
            ScannerDeviceRow(store: store, device: device)
        } emptyContent: {
            ContentUnavailableView(
                store.isScanning ? "Scanning…" : "No Devices Found",
                systemImage: "dot.radiowaves.left.and.right"
            )
        }
        .refreshable {
            await store.send(.rescanTapped).finish()
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
            } else if let device = store.rssiChartDevice {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            store.send(.rssiChartDismissed)
                        }
                    RSSIChartView(
                        device: device,
                        samples: store.rssiHistoryByDevice[device.id] ?? []
                    ) {
                        store.send(.rssiChartDismissed)
                    }
                    .padding(32)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: store.rawAdvertisementDataDevice)
        .animation(.easeOut(duration: 0.15), value: store.rssiChartDevice)
        .toast(isPresented: store.copyFeedbackDeviceID != nil, message: "Copied to Clipboard")
    }
}

/// A single scanner row plus its long-press behavior. Connectable devices toggle a favorite
/// star on long press. Non-connectable devices instead long-press into whichever of "Track
/// This Beacon" / "Raw Advertisement Data" applies directly — no intermediate menu tap —
/// falling back to a picker only when both apply to the same row (e.g. a non-connectable
/// beacon that also carries other advertisement data), and a haptic when neither does.
struct ScannerDeviceRow: View {
    let store: StoreOf<ScannerFeature>
    let device: DiscoveredDevice

    @State private var isActionChoicePresented = false
    @State private var nothingToShowFeedbackTrigger = false

    private var deviceId: DiscoveredDevice.ID { device.id }

    private var isFavorite: Bool {
        store.favoriteDeviceIdentifiers.contains(deviceId)
    }

    private var hasRawAdvertisementData: Bool {
        !RawAdvertisementDataBuilder.structures(for: device).isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.send(.rowTapped(deviceId))
            } label: {
                DeviceRowView(device: device) {
                    store.send(.favoriteToggled(deviceId))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("device.row.\(deviceId)")
            .disabled(!device.isConnectable)
            Spacer()
            VStack(spacing: 6) {
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
                if hasRawAdvertisementData {
                    Button {
                        sendRawAdvertisementDataTapped()
                    } label: {
                        Text("Raw Data".uppercased())
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .accessibilityIdentifier("device.row.rawDataIndicator.\(deviceId)")
                }
                Button {
                    store.send(.rssiChartTapped(deviceId))
                } label: {
                    Text("Chart".uppercased())
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .accessibilityIdentifier("device.row.chartButton.\(deviceId)")
            }
        }
        .overlay(alignment: .topLeading) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite. Long press to remove from Favorites.")
                    .accessibilityIdentifier("device.row.favoriteIndicator.\(deviceId)")
            }
        }
        
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in
                handleLongPress()
            },
            isEnabled: !device.isConnectable
        )
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
                    sendRawAdvertisementDataTapped()
                }
            }
        }
    }
    
    private func sendRawAdvertisementDataTapped() {
        store.send(.rawAdvertisementDataTapped(deviceId))
    }

    private func handleLongPress() {
        switch (device.beacon, hasRawAdvertisementData) {
        case let (.some(beacon), false):
            store.send(.trackBeaconTapped(beacon))
        case (.none, true):
            sendNeedCopy()
        case (.some, true):
            isActionChoicePresented = true
        case (.none, false):
            nothingToShowFeedbackTrigger.toggle()
        }
    }
    
    private func sendNeedCopy() {
        sendNeedCopy(for: deviceId)
    }
    
    private func sendNeedCopy(for deviceId: DiscoveredDevice.ID) {
        store.send(.rawAdvertisementDataCopyTapped(deviceId))
    }
}
