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
                Section(service.name ?? service.identifier.rawValue) {
                    ForEach(service.characteristics) { characteristic in
                        CharacteristicRowView(
                            store: store,
                            serviceIdentifier: service.identifier,
                            characteristic: characteristic
                        )
                    }
                }
            }
        }
        .navigationTitle(store.device.name ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { store.send(.onDisappear) }
    }

    private var isConnectedOrConnecting: Bool {
        switch store.connectionStatus {
        case .connected, .connecting: true
        default: false
        }
    }

    private var statusDescription: String {
        switch store.connectionStatus {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .disconnecting: "Disconnecting…"
        case let .failed(message): "Failed: \(message)"
        }
    }

    private var connectButtonTitle: String {
        isConnectedOrConnecting ? "Disconnect" : "Connect"
    }
}
