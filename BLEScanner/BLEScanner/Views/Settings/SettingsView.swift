import BLEFeatures
import BLEKitCore
import BLEKitHardware
import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        Form {
            Section {
                Toggle("Enhanced Beacon Ranging", isOn: Binding(
                    get: { store.settings.isEnhancedRangingEnabled },
                    set: { store.send(.enhancedRangingToggled($0)) }
                ))
                .accessibilityIdentifier("settings.enhancedRanging.toggle")
                if store.settings.isEnhancedRangingEnabled {
                    HStack {
                        Text("Location Authorization")
                        Spacer()
                        Text(authorizationDescription)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            } footer: {
                Text("Uses CoreLocation ranging for beacons you register below, giving more accurate proximity than signal strength alone.")
            }

            Section("Known Beacons") {
                ForEach(store.knownBeacons) { beacon in
                    VStack(alignment: .leading) {
                        Text(beacon.label)
                        Text(beacon.uuid.uuidString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("settings.knownBeacon.\(beacon.id)")
                }
                .onDelete { store.send(.knownBeaconDeleted($0)) }

                Button {
                    store.send(.addKnownBeaconTapped)
                } label: {
                    Label("Add Known Beacon", systemImage: "plus")
                }
                .accessibilityIdentifier("settings.addKnownBeacon.button")
            }
        }
        .navigationTitle("Settings")
        .onAppear { store.send(.onAppear) }
        .sheet(item: $store.scope(state: \.addBeaconForm, action: \.addBeaconForm)) { formStore in
            AddKnownBeaconSheet(store: formStore)
        }
    }

    private var authorizationDescription: String {
        switch store.locationAuthorizationStatus {
        case .notDetermined: "Not Determined"
        case .restricted: "Restricted"
        case .denied: "Denied"
        case .authorizedWhenInUse: "When In Use"
        case .authorizedAlways: "Always"
        }
    }
}
