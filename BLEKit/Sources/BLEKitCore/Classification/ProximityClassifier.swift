import Foundation

/// Estimates distance/proximity from RSSI using a standard log-distance path-loss model,
/// and merges in an authoritative CoreLocation ranging result when one is available.
public enum ProximityClassifier {
    public static let pathLossExponent: Double = 2.0

    /// Estimated distance in meters from a beacon's calibrated 1-meter Tx power and the
    /// currently observed RSSI. `nil` for a zero RSSI, which CoreBluetooth uses to mean
    /// "unavailable" rather than a real reading.
    public static func estimatedDistanceMeters(rssi: Int, measuredPower: Int8) -> Double? {
        guard rssi != 0 else { return nil }
        let ratio = Double(Int(measuredPower) - rssi) / (10 * pathLossExponent)
        return pow(10, ratio)
    }

    /// Classifies a beacon reading using its calibrated Tx power for a distance estimate.
    public static func classify(rssi: Int, measuredPower: Int8?) -> Proximity {
        guard let measuredPower, let distance = estimatedDistanceMeters(rssi: rssi, measuredPower: measuredPower) else {
            return .unknown
        }
        switch distance {
        case ..<0.5: return .immediate
        case ..<3.0: return .near
        default: return .far
        }
    }

    /// Classifies a plain (non-beacon) device using RSSI thresholds only, since there's
    /// no calibrated Tx power to compute a real distance from.
    public static func classify(rssiOnly rssi: Int) -> Proximity {
        guard rssi != 0 else { return .unknown }
        switch rssi {
        case (-50)...:
            return .immediate
        case -75 ..< -50:
            return .near
        default:
            return .far
        }
    }

    /// An authoritative CoreLocation ranging result always supersedes the RSSI heuristic.
    public static func merge(heuristic: Proximity, ranged: Proximity?) -> Proximity {
        ranged ?? heuristic
    }
}
