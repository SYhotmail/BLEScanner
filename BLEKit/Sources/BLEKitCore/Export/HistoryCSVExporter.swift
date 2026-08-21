import Foundation

/// Formats scan `HistoryRecordDTO` values as CSV text for the History screen's export action.
public enum HistoryCSVExporter {
    private static let header = "Identifier,Name,Last RSSI (dBm),First Seen,Last Seen"

    public static func csv(for records: [HistoryRecordDTO]) -> String {
        let rows = records.map(row(for:))
        return ([header] + rows).joined(separator: "\r\n")
    }

    private static func row(for record: HistoryRecordDTO) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        return [
            field(record.identifier),
            field(record.name ?? ""),
            field(String(record.lastRSSI)),
            field(dateFormatter.string(from: record.firstSeenDate)),
            field(dateFormatter.string(from: record.lastSeenDate))
        ]
        .joined(separator: ",")
    }

    /// Quotes a field and escapes embedded quotes if it contains a comma, quote, or newline —
    /// the minimal escaping RFC 4180 requires.
    private static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
