import BLEKitCore
import SwiftUI

extension Color {
    /// A per-device identity color: hue is derived deterministically from the device's
    /// identifier (quantized via `DeviceColorClassifier` so different devices land in visually
    /// distinct buckets), saturation is a continuous fraction of `rssi` (stronger signal reads
    /// more vivid), and brightness communicates `proximity`'s coarse ring — so a badge or radar
    /// dot simultaneously answers "which device" and "how close."
    private static func deviceColor(identifier: UUID, rssi: Int, proximity: Proximity) -> Color {
        let hue = DeviceColorClassifier.hueFraction(for: identifier)
        let saturation = Self.saturationFraction(forRSSI: rssi)
        let brightness = proximity.brightness
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    static func colorForDiscoveredDevice( _ device: DiscoveredDevice) -> Self {
        deviceColor(identifier: device.identifier, rssi: device.rssi, proximity: device.proximity)
    }

    /// Linearly interpolates `rssi`, clamped to a practical BLE signal range, into
    /// `[minSaturation, maxSaturation]` — weak signal reads muted, strong signal reads vivid,
    /// as a smooth gradient rather than a handful of fixed levels.
    private static func saturationFraction(forRSSI rssi: Int) -> Double {
        let floorRSSI = -100.0
        let ceilingRSSI = -40.0
        let minSaturation = 0.15
        let maxSaturation = 1 - minSaturation

        let clamped = min(max(Double(rssi), floorRSSI), ceilingRSSI)
        let normalized = (clamped - floorRSSI) / (ceilingRSSI - floorRSSI)
        return minSaturation + normalized * (maxSaturation - minSaturation)
    }
}

private extension Proximity {
    var brightness: Double {
        let unknownValue = 0.55
        let space: CGFloat
        switch self {
        case .immediate:
            space = 0.3
        case .near:
            space = 0.2
        case .far:
            space = 0.1
        case .unknown:
            space = 0
        }
        return unknownValue + space
    }
}
