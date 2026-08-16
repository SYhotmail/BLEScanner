import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct CharacteristicRowView: View {
    @Bindable var store: StoreOf<DeviceDetailFeature>
    let serviceIdentifier: GATTIdentifier
    let characteristic: GATTCharacteristic

    var body: some View {
        DisclosureGroup {
            CharacteristicDetailView(store: store, serviceIdentifier: serviceIdentifier, characteristic: characteristic)
        } label: {
            HStack {
                Text(characteristic.name ?? characteristic.identifier.rawValue)
                Spacer()
                capabilityBadges
            }
        }
    }

    @ViewBuilder
    private var capabilityBadges: some View {
        HStack(spacing: 4) {
            if characteristic.properties.contains(.read) {
                badge("R")
            }
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                badge("W")
            }
            if characteristic.properties.supportsSubscription {
                badge("N")
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .frame(width: 18, height: 18)
            .background(.secondary.opacity(0.2), in: Circle())
    }
}
