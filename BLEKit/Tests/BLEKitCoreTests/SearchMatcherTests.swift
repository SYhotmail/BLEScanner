import Foundation
import Testing
@testable import BLEKitCore

@Suite("SearchMatcher")
struct SearchMatcherTests {
    @Test("an empty query matches everything")
    func emptyQueryMatchesEverything() {
        #expect(SearchMatcher.matches(name: nil, identifier: "AAA", query: ""))
        #expect(SearchMatcher.matches(name: "Sensor", identifier: "AAA", query: ""))
    }

    @Test("matches a case-insensitive substring of the name")
    func matchesNameSubstring() {
        #expect(SearchMatcher.matches(name: "Living Room Sensor", identifier: "AAA", query: "room"))
        #expect(!SearchMatcher.matches(name: "Living Room Sensor", identifier: "AAA", query: "kitchen"))
    }

    @Test("matches a case-insensitive substring of the identifier")
    func matchesIdentifierSubstring() {
        #expect(SearchMatcher.matches(name: nil, identifier: "12345678-ABCD-4EF0-9012-345678ABCDEF", query: "abcd"))
        #expect(!SearchMatcher.matches(name: nil, identifier: "12345678-ABCD-4EF0-9012-345678ABCDEF", query: "ffffff"))
    }

    @Test("a nil name doesn't crash and just falls through to the identifier check")
    func nilNameFallsThroughToIdentifier() {
        #expect(!SearchMatcher.matches(name: nil, identifier: "AAA", query: "anything"))
        #expect(SearchMatcher.matches(name: nil, identifier: "AAA", query: "aaa"))
    }

    @Test("matches a DiscoveredDevice by name or identifier")
    func matchesDiscoveredDevice() {
        let identifier = UUID(uuidString: "12345678-ABCD-4EF0-9012-345678ABCDEF")!
        let device = DiscoveredDevice(identifier: identifier, name: "Garage Sensor", rssi: -60)
        #expect(SearchMatcher.matches(device, query: "garage"))
        #expect(SearchMatcher.matches(device, query: "abcd"))
        #expect(!SearchMatcher.matches(device, query: "kitchen"))
    }

    @Test("matches a HistoryRecordDTO by name or identifier")
    func matchesHistoryRecord() {
        let record = HistoryRecordDTO(identifier: "12345678-ABCD-4EF0-9012-345678ABCDEF", name: "Garage Sensor", lastRSSI: -60, lastSeenDate: .now)
        #expect(SearchMatcher.matches(record, query: "garage"))
        #expect(SearchMatcher.matches(record, query: "abcd"))
        #expect(!SearchMatcher.matches(record, query: "kitchen"))
    }
}
