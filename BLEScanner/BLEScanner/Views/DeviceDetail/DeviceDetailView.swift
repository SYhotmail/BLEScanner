import BLEFeatures
import BLEKitCore
import BLEKitHardware
import ComposableArchitecture
import SwiftUI

struct DeviceDetailView: View {
    @Bindable var store: StoreOf<DeviceDetailFeature>

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(statusDescription)
                        .foregroundStyle(.secondary)
                }
                Button(connectButtonTitle) {
                    store.send(isConnectedOrConnecting ? .disconnectTapped : .connectTapped)
                }
                .accessibilityIdentifier("deviceDetail.connectButton")
            }

            Section("Signal") {
                HStack {
                    Text("RSSI")
                    Spacer()
                    Text("\(store.device.rssi) dBm")
                        .foregroundStyle(.secondary)
                }
                if let txPowerLevel = store.device.txPowerLevel {
                    HStack {
                        Text("Tx Power")
                        Spacer()
                        Text("\(txPowerLevel) dBm")
                            .foregroundStyle(.secondary)
                    }
                }
                if let manufacturer = store.device.manufacturer {
                    HStack {
                        Text("Manufacturer")
                        Spacer()
                        ManufacturerLogoView(manufacturer: manufacturer)
                        Text(manufacturer.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(store.services) { service in
                Section(service.displayName) {
                    ForEach(service.characteristics) { characteristic in
                        CharacteristicRowView(
                            store: store,
                            serviceIdentifier: service.identifier,
                            characteristic: characteristic
                        )
                    }
                    ForEach(service.includedServices) { includedService in
                        includedServiceRow(includedService)
                    }
                }
            }
        }
        .navigationTitle(store.device.name ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A GATT included service, nested inside its parent service's section as a collapsible
    /// group of that included service's own characteristics.
    private func includedServiceRow(_ includedService: GATTService) -> some View {
        DisclosureGroup {
            ForEach(includedService.characteristics) { characteristic in
                CharacteristicRowView(
                    store: store,
                    serviceIdentifier: includedService.identifier,
                    characteristic: characteristic
                )
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(includedService.displayName)
                    Text("Included service")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "arrow.turn.down.right")
            }
        }
    }

    private var isConnectedOrConnecting: Bool {
        switch store.connectionStatus {
        case .connected, .connecting: true
        default: false
        }
    }

    private var statusDescription: String {
        switch store.connectionStatus {
        case .disconnected:
            if let reason = store.disconnectReason { "Disconnected: \(reason)" } else { "Disconnected" }
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .disconnecting: "Disconnecting…"
        case let .failed(message): "Failed: \(message)"
        }
    }

    private var connectButtonTitle: String {
        if isConnectedOrConnecting { return "Disconnect" }
        // An unexpected drop leaves a reason behind; offer to re-establish the same connection.
        return store.disconnectReason == nil ? "Connect" : "Reconnect"
    }
}
