import Foundation
import Testing
@testable import BLEKitCore

@Suite("HistoryCSVExporter")
struct HistoryCSVExporterTests {
    @Test("empty input produces only the header row")
    func emptyInputProducesHeaderOnly() {
        let csv = HistoryCSVExporter.csv(for: [])
        #expect(csv == "Identifier,Name,Last RSSI (dBm),First Seen,Last Seen")
    }

    @Test("a record renders as a comma-separated row with ISO 8601 dates")
    func recordRendersAsRow() {
        let record = HistoryRecordDTO(
            identifier: "AAA",
            name: "Sensor",
            lastRSSI: -55,
            lastSeenDate: Date(timeIntervalSince1970: 1_700_000_100),
            firstSeenDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let csv = HistoryCSVExporter.csv(for: [record])
        let rows = csv.components(separatedBy: "\r\n")
        #expect(rows.count == 2)
        #expect(rows[1] == "AAA,Sensor,-55,2023-11-14T22:13:20Z,2023-11-14T22:15:00Z")
    }

    @Test("a missing name renders as an empty field")
    func missingNameRendersEmpty() {
        let record = HistoryRecordDTO(identifier: "AAA", lastRSSI: -55, lastSeenDate: .now)
        let csv = HistoryCSVExporter.csv(for: [record])
        let rows = csv.components(separatedBy: "\r\n")
        #expect(rows[1].hasPrefix("AAA,,-55,"))
    }

    @Test("a name containing a comma or quote is quoted and escaped")
    func nameWithCommaOrQuoteIsQuoted() {
        let record = HistoryRecordDTO(identifier: "AAA", name: "Living Room, \"Main\"", lastRSSI: -55, lastSeenDate: .now)
        let csv = HistoryCSVExporter.csv(for: [record])
        let rows = csv.components(separatedBy: "\r\n")
        #expect(rows[1].hasPrefix("AAA,\"Living Room, \"\"Main\"\"\","))
    }
}
