import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct ScanPeriodSheet: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                Picker("Scan Period", selection: Binding(
                    get: { store.settings.scanPeriod },
                    set: { store.send(.scanPeriodChanged($0)) }
                )) {
                    ForEach(AppSettings.availableScanPeriods, id: \.self) { period in
                        Text("\(Int(period))s").tag(period)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("settings.scanPeriod.picker")
            }
            .navigationTitle("Scan Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.send(.scanPeriodPickerDismissed) }
                }
            }
        }
    }
}
