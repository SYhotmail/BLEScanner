import Foundation
import Testing
@testable import BLEKitCore

@Suite("RSSISampleCSVExporter")
struct RSSISampleCSVExporterTests {
    @Test("empty input produces only the header row")
    func emptyInputProducesHeaderOnly() {
        let csv = RSSISampleCSVExporter.csv(for: [])
        #expect(csv == "Timestamp,RSSI (dBm)")
    }

    @Test("a sample renders as a comma-separated row with an ISO 8601 timestamp")
    func sampleRendersAsRow() {
        let sample = RSSISample(date: Date(timeIntervalSince1970: 1_700_000_100), rssi: -55)
        let csv = RSSISampleCSVExporter.csv(for: [sample])
        let rows = csv.components(separatedBy: "\r\n")
        #expect(rows.count == 2)
        #expect(rows[1] == "2023-11-14T22:15:00Z,-55")
    }

    @Test("multiple samples render in order, one row each")
    func multipleSamplesRenderInOrder() {
        let samples = [
            RSSISample(date: Date(timeIntervalSince1970: 1_700_000_000), rssi: -60),
            RSSISample(date: Date(timeIntervalSince1970: 1_700_000_060), rssi: -58)
        ]
        let csv = RSSISampleCSVExporter.csv(for: samples)
        let rows = csv.components(separatedBy: "\r\n")
        #expect(rows.count == 3)
        #expect(rows[1] == "2023-11-14T22:13:20Z,-60")
        #expect(rows[2] == "2023-11-14T22:14:20Z,-58")
    }
}
