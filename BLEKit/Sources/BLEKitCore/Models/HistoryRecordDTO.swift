import Foundation

/// A `Sendable`/`Codable` mirror of the SwiftData `HistoryRecord` model, used to cross
/// the `@ModelActor` boundary and to flow through TCA state.
public struct HistoryRecordDTO: Identifiable, Equatable, Sendable, Codable {
    public var id: String { identifier }
    public let identifier: String
    public var name: String?
    public var lastRSSI: Int
    public var lastSeenDate: Date
    public var firstSeenDate: Date

    public init(
        identifier: String,
        name: String? = nil,
        lastRSSI: Int,
        lastSeenDate: Date,
        firstSeenDate: Date? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.lastRSSI = lastRSSI
        self.lastSeenDate = lastSeenDate
        self.firstSeenDate = firstSeenDate ?? lastSeenDate
    }
}
