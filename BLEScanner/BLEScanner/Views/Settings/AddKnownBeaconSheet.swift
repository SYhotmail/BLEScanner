import BLEFeatures
import ComposableArchitecture
import SwiftUI

struct AddKnownBeaconSheet: View {
    @Bindable var store: StoreOf<AddKnownBeaconFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section("Beacon UUID") {
                    TextField("UUID", text: Binding(
                        get: { store.uuidText },
                        set: { store.send(.uuidChanged($0)) }
                    ))
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("addBeacon.uuidField")
                    if let error = store.validationError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                Section("Label") {
                    TextField("Optional label", text: Binding(
                        get: { store.label },
                        set: { store.send(.labelChanged($0)) }
                    ))
                }
            }
            .navigationTitle("Add Known Beacon")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.cancelTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveTapped) }
                        .accessibilityIdentifier("addBeacon.saveButton")
                }
            }
        }
    }
}
