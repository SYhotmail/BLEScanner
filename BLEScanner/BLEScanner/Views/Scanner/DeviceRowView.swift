import BLEKitCore
import SwiftUI

struct DeviceRowView: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("\(device.rssi)\ndBm")
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.rssiColor(for: device.rssi), in: Circle())
                    .layoutPriority(1)

                if let manufacturer = device.manufacturer {
                    ManufacturerLogoView(manufacturer: manufacturer, maxLogoHeight: 20)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name ?? "n/a")
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(device.identifier.uuidString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    if device.beacon != nil {
                        Label("iBeacon", systemImage: "location.fill")
                            .foregroundStyle(.blue)
                    }
                    if let estimatedDistanceMeters = device.estimatedDistanceMeters {
                        Text(Self.formattedDistance(estimatedDistanceMeters))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(device.lastSeenDate, style: .timer)
                    
                    /*LastSeenText(lastSeenDate: device.lastSeenDate)
                        .foregroundStyle(.secondary) */
                }
                .font(.caption2)
                .lineLimit(1)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// Formats a rough distance estimate; `estimatedDistanceMeters` is order-of-magnitude
    /// only (see its doc comment), so this deliberately keeps precision low and marks it "~".
    private static func formattedDistance(_ meters: Double) -> String {
        meters < 100 ? String(format: "~%.1f m", meters) : String(format: "~%.0f m", meters)
    }
}

/// Live-updating "Xs ago" label, driven by the advertisement's `advDataTimestamp`-derived
/// `lastSeenDate` rather than the queue-processing time of the discovery callback.
private struct LastSeenText: View {
    let lastSeenDate: Date

    var body: some View {
        TimelineView(.periodic(from: lastSeenDate, by: 1)) { context in
            Text("\(max(0, Int(context.date.timeIntervalSince(lastSeenDate))))s ago")
        }
    }
}
