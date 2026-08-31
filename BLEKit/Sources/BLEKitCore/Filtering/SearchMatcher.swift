import Foundation

/// Matches a free-text search query against a name/identifier pair. Backs the quick search
/// field on the Near By, Favorites, and History lists — a single query matched as an OR
/// against name-or-identifier, independent of (and simpler than) the Filter screen's opt-in,
/// AND-combined `DeviceFilter`/`FilterCriteria` system.
public enum SearchMatcher {
    /// An empty query matches everything. Otherwise matches if `query` is a case-insensitive
    /// substring of either `name` or `identifier`.
    public static func matches(name: String?, identifier: String, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        if let name, name.range(of: query, options: .caseInsensitive) != nil {
            return true
        }
        return identifier.range(of: query, options: .caseInsensitive) != nil
    }

    public static func matches(_ device: DiscoveredDevice, query: String) -> Bool {
        if matches(name: device.name, identifier: device.identifier.uuidString, query: query) {
            return true
        }
        guard !query.isEmpty else { return true }
        return device.advertisedServiceIdentifiers.contains { identifier in
            GATTAssignedNumbers.serviceName(for: identifier)?.range(of: query, options: .caseInsensitive) != nil
        }
    }

    public static func matches(_ record: HistoryRecordDTO, query: String) -> Bool {
        matches(name: record.name, identifier: record.identifier, query: query)
    }
}
