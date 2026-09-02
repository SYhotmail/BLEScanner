import CoreBluetooth
import Foundation

/// Formats a CoreBluetooth `Error` into a one-line diagnostic string that keeps the numeric
/// domain code — so a log reader can tell `CBError.peripheralDisconnected` (6, the peer closed
/// the link) apart from `.connectionTimeout` (7), `.connectionFailed` (10), or
/// `.encryptionTimedOut` (5), which all otherwise read as similar prose.
public enum CoreBluetoothErrorDescription {
    /// `nil` when `error` is `nil`. Otherwise `"<localizedDescription> [<domain> <code>]"`, with
    /// a symbolic name appended for the `CBError` codes worth recognising at a glance.
    public static func string(for error: Error?) -> String? {
        guard let error else { return nil }
        let nsError = error as NSError
        let description = nsError.localizedDescription

        switch nsError.domain {
        case CBErrorDomain:
            if let name = CBError.Code(rawValue: nsError.code).flatMap(symbolicName(for:)) {
                return "\(description) [CBError \(nsError.code): \(name)]"
            }
            return "\(description) [CBError \(nsError.code)]"
        case CBATTErrorDomain:
            return "\(description) [CBATTError \(nsError.code)]"
        default:
            return "\(description) [\(nsError.domain) \(nsError.code)]"
        }
    }

    /// Symbolic names for the connection-lifecycle `CBError` codes. `nil` for anything else —
    /// the caller still prints the raw number, so newer/rarer codes stay legible without this
    /// switch having to track the SDK.
    private static func symbolicName(for code: CBError.Code) -> String? {
        switch code {
        case .unknown: return "unknown"
        case .operationCancelled: return "operationCancelled"
        case .connectionTimeout: return "connectionTimeout"
        case .peripheralDisconnected: return "peripheralDisconnected"
        case .connectionFailed: return "connectionFailed"
        case .connectionLimitReached: return "connectionLimitReached"
        case .notConnected: return "notConnected"
        default: return nil
        }
    }
}
