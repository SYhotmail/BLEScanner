import BLEFeatures
import ComposableArchitecture
import SwiftUI

struct FilterView: View {
    @Bindable var store: StoreOf<FilterFeature>

    var body: some View {
        Form {
            Section("By Name") {
                Toggle("Enabled", isOn: Binding(
                    get: { store.criteria.isNameFilterEnabled },
                    set: { store.send(.nameFilterToggled($0)) }
                ))
                .accessibilityIdentifier("filter.name.toggle")
                TextField("Name contains", text: Binding(
                    get: { store.criteria.nameQuery },
                    set: { store.send(.nameQueryChanged($0)) }
                ))
                .disabled(!store.criteria.isNameFilterEnabled)
                .accessibilityIdentifier("filter.name.field")
            }

            Section {
                Toggle("Enabled", isOn: Binding(
                    get: { store.criteria.isIdentifierFilterEnabled },
                    set: { store.send(.identifierFilterToggled($0)) }
                ))
                TextField("Identifier contains", text: Binding(
                    get: { store.criteria.identifierQuery },
                    set: { store.send(.identifierQueryChanged($0)) }
                ))
                .disabled(!store.criteria.isIdentifierFilterEnabled)
            } header: {
                Text("By Identifier")
            } footer: {
                Text("iOS doesn't expose a device's real hardware MAC address, so this filters on CoreBluetooth's per-app device identifier instead.")
            }

            Section("By Minimum RSSI") {
                Toggle("Enabled", isOn: Binding(
                    get: { store.criteria.isRSSIFilterEnabled },
                    set: { store.send(.rssiFilterToggled($0)) }
                ))
                Slider(
                    value: Binding(
                        get: { Double(store.criteria.minimumRSSI) },
                        set: { store.send(.minimumRSSIChanged(Int($0))) }
                    ),
                    in: -100...(-30),
                    step: 1
                ) {
                    Text("Minimum RSSI")
                } minimumValueLabel: {
                    Text("-100")
                } maximumValueLabel: {
                    Text("-30")
                }
                .disabled(!store.criteria.isRSSIFilterEnabled)
                Text("\(store.criteria.minimumRSSI) dBm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset Filters", role: .destructive) {
                    store.send(.resetTapped)
                }
            }
        }
        .navigationTitle("Filter")
    }
}
