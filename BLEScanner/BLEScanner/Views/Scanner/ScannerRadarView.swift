import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

/// Mirrors the Android reference app's "Proximity" screen: instead of concentric rings around a
/// center point, proximity buckets are stacked horizontal bands (Immediate at the bottom, nearest
/// the viewer, up through Near/Far/Unknown at the top), each band's top edge a gentle upward arc
/// rather than a straight line. Devices scatter within their band rather than sitting on a fixed
/// ring, matching the reference's loose, non-radial placement.
struct ScannerRadarView: View {
    let store: StoreOf<ScannerFeature>

    /// Top-to-bottom band order.
    private static let bands: [Proximity] = [.unknown, .far, .near, .immediate]

    /// Height-fraction range (0 = top of the radar area, 1 = bottom) each band occupies.
    private static func heightFraction(for band: Proximity) -> ClosedRange<CGFloat> {
        switch band {
        case .unknown: 0.0...0.15
        case .far: 0.15...0.42
        case .near: 0.42...0.70
        case .immediate: 0.70...0.97
        }
    }

    /// Background tint per band, deepening toward `.immediate` — closest devices sit in the
    /// most saturated band, same visual logic as the Android reference's darkest-blue-at-bottom
    /// wave stack.
    private static func bandColor(for band: Proximity) -> Color {
        switch band {
        case .unknown: Color(.systemGray5)
        case .far: Color.accentColor.opacity(0.25)
        case .near: Color.accentColor.opacity(0.45)
        case .immediate: Color.accentColor.opacity(0.7)
        }
    }

    /// How far below the radar area's bottom edge the shared arc center sits, as a multiple of
    /// the area's *width* — not height. Every band boundary is drawn as an arc of a circle
    /// centered here; scaling by width (rather than height, as an earlier version of this did)
    /// keeps the smallest band's radius comfortably above half the frame's width on any aspect
    /// ratio, which guarantees that circle can only ever show as a clipped arc. Scaling by
    /// height instead let the circle shrink below `width / 2` on wider/more-square frames (e.g.
    /// an iPad's detail pane), letting its sides curl back into view as a full closed circle
    /// instead of an arc. Larger values flatten the curve; smaller values (below ~0.5) risk
    /// reintroducing the closed-circle bug.
    private static let arcCenterWidthMargin: CGFloat = 1.6

    var body: some View {
        let devices = store.filteredSortedDevices

        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                bandBackground(width: width, height: height)

                ForEach(Self.bands, id: \.rawValue) { band in
                    bandLabel(band, width: width, height: height)
                }

                ForEach(devices) { device in
                    deviceMarker(device: device, width: width, height: height)
                }
            }
            .frame(width: width, height: height)
            .clipped()
        }
        .overlay {
            if devices.isEmpty {
                ContentUnavailableView(
                    store.isScanning ? "Scanning…" : "No Devices Found",
                    systemImage: "dot.radiowaves.left.and.right"
                )
            }
        }
    }

    /// Layers a full-bleed "unknown" background with successively smaller, more saturated
    /// circles stacked on top — since each is centered on the same point and strictly nested
    /// (their radii shrink from `.far` to `.immediate`), this reproduces stacked bands without
    /// having to hand-build annulus paths.
    @ViewBuilder
    private func bandBackground(width: CGFloat, height: CGFloat) -> some View {
        let center = CGPoint(x: width / 2, y: height + Self.arcCenterWidthMargin * width)
        Rectangle().fill(Self.bandColor(for: .unknown))
        ForEach([Proximity.far, .near, .immediate], id: \.rawValue) { band in
            let topFraction = Self.heightFraction(for: band).lowerBound
            let radius = center.y - topFraction * height
            Circle()
                .fill(Self.bandColor(for: band))
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
        }
    }

    private func bandLabel(_ band: Proximity, width: CGFloat, height: CGFloat) -> some View {
        let y = Self.heightFraction(for: band).lowerBound * height + 16
        return Text(band.rawValue.capitalized)
            .font(.caption2.bold())
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: width, alignment: .leading)
            .padding(.leading, 12)
            .position(x: width / 2, y: y)
    }

    private func deviceMarker(device: DiscoveredDevice, width: CGFloat, height: CGFloat) -> some View {
        let band = Self.heightFraction(for: device.proximity)
        let yFraction = band.lowerBound + Self.scatterFraction(seed: device.identifier, salt: 1) * (band.upperBound - band.lowerBound)
        let xFraction = 0.12 + Self.scatterFraction(seed: device.identifier, salt: 2) * 0.76

        return Button {
            store.send(.rowTapped(device.id))
        } label: {
            VStack(spacing: 2) {
                Text("\(device.rssi)")
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.colorForDiscoveredDevice(device), in: Circle())
                Text(device.name ?? "n/a")
                    .font(.caption2)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .position(x: xFraction * width, y: yFraction * height)
    }

    /// A `[0, 1)` value derived deterministically from `seed`, so a device's scatter position
    /// within its band stays put across recomputes instead of jumping on every RSSI update.
    /// `salt` decorrelates the x/y draws for the same device. Cosmetic placement only — no need
    /// for `Hasher` (which is randomized per process and would move markers between launches).
    private static func scatterFraction(seed: UUID, salt: Int) -> CGFloat {
        let bytes = withUnsafeBytes(of: seed.uuid) { Array($0) }
        let sum = bytes.enumerated().reduce(0) { $0 + Int($1.element) * ($1.offset + salt * 7 + 1) }
        return CGFloat(sum % 1000) / 1000
    }
}
