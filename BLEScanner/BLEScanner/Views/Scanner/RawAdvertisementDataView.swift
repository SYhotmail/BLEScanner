import BLEKitCore
import SwiftUI
import UIKit

/// Centered alert-style card reconstructing a device's advertisement as LEN/TYPE/VALUE AD
/// structures, matching the look of the Android reference app's "Raw Data" dialog rather than
/// an iOS bottom sheet. See `AdvertisementDataStructure`'s doc comment: CoreBluetooth never
/// exposes literal packet bytes, so these rows are reconstructed from already-parsed fields.
struct RawAdvertisementDataView: View {
    let device: DiscoveredDevice
    let onDismiss: () -> Void

    @State private var didCopy = false

    private var structures: [AdvertisementDataStructure] {
        RawAdvertisementDataBuilder.structures(for: device)
    }

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
                UIPasteboard.general.string = RawAdvertisementDataBuilder.plainTextDescription(for: device)
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
        .onChange(of: device.id) { didCopy = false }
    }
}
