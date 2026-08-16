import Foundation
import SwiftData

@Model
public final class HistoryRecord {
    @Attribute(.unique) public var identifier: String
    public var name: String?
    public var lastRSSI: Int
    public var lastSeenDate: Date
    public var firstSeenDate: Date

    public init(identifier: String, name: String?, lastRSSI: Int, lastSeenDate: Date, firstSeenDate: Date) {
        self.identifier = identifier
        self.name = name
        self.lastRSSI = lastRSSI
        self.lastSeenDate = lastSeenDate
        self.firstSeenDate = firstSeenDate
    }
}
