import Foundation

/// A single timestamped RSSI reading, accumulated per device while scanning to power the
/// Scanner list's RSSI-over-time chart.
public struct RSSISample: Identifiable, Equatable, Sendable {
    public let date: Date
    public let rssi: Int

    public var id: Date { date }

    public init(date: Date, rssi: Int) {
        self.date = date
        self.rssi = rssi
    }
}
