import BLEKitCore
import SwiftUI

/// Centered alert-style card reconstructing a device's advertisement as LEN/TYPE/VALUE AD
/// structures, matching the look of the Android reference app's "Raw Data" dialog rather than
/// an iOS bottom sheet. See `AdvertisementDataStructure`'s doc comment: CoreBluetooth never
/// exposes literal packet bytes, so these rows are reconstructed from already-parsed fields.
struct RawAdvertisementDataView: View {
    let structures: [AdvertisementDataStructure]
    let onDismiss: () -> Void
    let onCopy: () -> Void
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Raw Advertisement Data")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("rawAdvertisementData.dismiss")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if structures.isEmpty {
                        Text("No reconstructable advertisement data available.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(structures) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.typeName)
                                    .font(.subheadline.bold())
                                LabeledContent("LEN", value: "\(entry.length)")
                                LabeledContent("TYPE", value: String(format: "0x%02X", entry.type))
                                LabeledContent("VALUE", value: "0x\(entry.valueHex)")
                            }
                            .font(.caption)
                        }
                    }
                }
                .textSelection(.enabled)
            }
            .frame(maxHeight: 320)

            Divider()

            Button {
                onCopy()
                didCopy = true
            } label: {
                Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .disabled(structures.isEmpty)
            .accessibilityIdentifier("rawAdvertisementData.copy")
        }
        .padding()
        .frame(maxWidth: 340)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 20)
    }
}

extension RawAdvertisementDataView {
    init(device: DiscoveredDevice,
         onDismiss: @escaping () -> Void,
         onCopy: @escaping  () -> Void) {
        self.init(structures: RawAdvertisementDataBuilder.structures(for: device), onDismiss: onDismiss,
                  onCopy: onCopy)
    }
}

#Preview {
    let device = DiscoveredDevice(
        identifier: UUID(),
        name: "Test Beacon",
        rssi: -65,
        isConnectable: true,
        advertisedServiceIdentifiers: [GATTIdentifier(rawValue: "FEAA")],
        txPowerLevel: -12,
        manufacturerData: Data([0x4C, 0x00, 0x02, 0x15, 0x00])
    )
    RawAdvertisementDataView(
        device: device,
        onDismiss: {},
        onCopy: {}
    )
}

#Preview("Empty") {
    RawAdvertisementDataView(structures: [], onDismiss: {}, onCopy: {})
}
