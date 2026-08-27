import Foundation

/// Formats a device's accumulated `RSSISample` history as CSV text for the Scanner list's
/// RSSI chart export action.
public enum RSSISampleCSVExporter {
    private static let header = "Timestamp,RSSI (dBm)"

    public static func csv(for samples: [RSSISample]) -> String {
        let rows = samples.map(row(for:))
        return ([header] + rows).joined(separator: "\r\n")
    }

    private static func row(for sample: RSSISample) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        return "\(dateFormatter.string(from: sample.date)),\(sample.rssi)"
    }
}
