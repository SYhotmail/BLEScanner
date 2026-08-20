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
                Picker("Scanning", selection: Binding(
                    get: { store.settings.scanMode },
                    set: { store.send(.scanModeChanged($0)) }
                )) {
                    Text("Periodic Scan").tag(ScanMode.periodic)
                    Text("Manual Scan").tag(ScanMode.manual)
                }
                .accessibilityIdentifier("settings.scanMode.picker")

                if store.settings.scanMode == .manual {
                    Button {
                        store.send(.scanPeriodPickerTapped)
                    } label: {
                        HStack {
                            Text("Scan Period")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(scanPeriodDescription)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings.scanPeriod.button")
                }
            } footer: {
                Text("Periodic Scan starts scanning as soon as you open the Scanner screen, automatically restarting it every 5 seconds to force a fresh reading from devices that only report once per scan. Manual Scan waits for you to start and stop scanning yourself from the Scanner screen's toolbar, restarting at the interval you choose below while it's running.")
            }

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
        .sheet(isPresented: Binding(
            get: { store.isScanPeriodPickerPresented },
            set: { isPresented in
                if !isPresented { store.send(.scanPeriodPickerDismissed) }
            }
        )) {
            ScanPeriodSheet(store: store)
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

    private var scanPeriodDescription: String {
        "\(Int(store.settings.scanPeriod))s"
    }
}
