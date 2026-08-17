import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct ScannerRadarView: View {
    let store: StoreOf<ScannerFeature>

    private let rings: [Proximity] = [.immediate, .near, .far, .unknown]

    var body: some View {
        let devices = store.filteredSortedDevices

        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height) * 0.9

            ZStack {
                ringsOverlay(size: size)

                ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                    deviceMarker(device: device, index: index, total: devices.count, size: size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding()
        .overlay {
            if devices.isEmpty {
                ContentUnavailableView(
                    store.isScanning ? "Scanning…" : "No Devices Found",
                    systemImage: "dot.radiowaves.left.and.right"
                )
            }
        }
    }

    @ViewBuilder
    private func ringsOverlay(size: CGFloat) -> some View {
        ForEach(Array(rings.enumerated()), id: \.offset) { index, proximity in
            let ringRadius = size / 2 * CGFloat(index + 1) / CGFloat(rings.count)
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                .frame(width: ringRadius * 2, height: ringRadius * 2)
            Text(proximity.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .offset(y: -ringRadius + 10)
        }
    }

    private func deviceMarker(device: DiscoveredDevice, index: Int, total: Int, size: CGFloat) -> some View {
        let ringIndex = rings.firstIndex(of: device.proximity) ?? rings.count - 1
        let radius = size / 2 * CGFloat(ringIndex + 1) / CGFloat(rings.count)
        let angle = CGFloat(index) / CGFloat(max(total, 1)) * 2 * .pi
        let x = size / 2 + radius * 0.75 * cos(angle)
        let y = size / 2 + radius * 0.75 * sin(angle)

        return Button {
            store.send(.rowTapped(device.id))
        } label: {
            VStack(spacing: 2) {
                Circle()
                    .fill(Color.rssiColor(for: device.rssi))
                    .frame(width: 14, height: 14)
                Text(device.name ?? "n/a")
                    .font(.caption2)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .position(x: x, y: y)
    }
}
