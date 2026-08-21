import Foundation

/// Derives a stable per-device hue bucket from a device's identifier, so the same device
/// renders with the same color every time it's seen. Deliberately hashes the raw UUID bytes
/// with FNV-1a rather than using `UUID.hashValue` — Swift randomizes `Hashable.hashValue` per
/// process launch, which would make a device's color change every app relaunch.
public enum DeviceColorClassifier {
    /// Number of discrete hues devices are quantized into (360° / 20 = 18° apart), chosen to
    /// keep adjacent hues perceptually distinct while keeping bucket collisions unlikely for a
    /// typical scan of a few dozen nearby devices.
    public static let hueBucketCount = 20

    /// A stable `[0, hueBucketCount)` bucket index for `identifier`.
    public static func hueBucketIndex(for identifier: UUID) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        withUnsafeBytes(of: identifier.uuid) { bytes in
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* 0x100_0000_01b3
            }
        }
        return Int(hash % UInt64(hueBucketCount))
    }

    /// The `[0, 1)` hue fraction for `identifier`, suitable for `Color(hue:saturation:brightness:)`.
    public static func hueFraction(for identifier: UUID) -> Double {
        Double(hueBucketIndex(for: identifier)) / Double(hueBucketCount)
    }
}
