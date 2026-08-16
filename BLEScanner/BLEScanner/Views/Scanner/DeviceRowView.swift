import BLEKitCore
import SwiftUI

struct DeviceRowView: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack(spacing: 12) {
            Text("\(device.rssi)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.rssiColor(for: device.rssi), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name ?? "Unknown Device")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(device.identifier.uuidString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if device.beacon != nil {
                    Label("iBeacon", systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Text(device.proximity.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
