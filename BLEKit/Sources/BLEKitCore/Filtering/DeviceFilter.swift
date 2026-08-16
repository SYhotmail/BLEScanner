import Foundation

public enum DeviceFilter {
    /// Filters are combined with AND semantics; a disabled filter never constrains results.
    public static func matches(_ device: DiscoveredDevice, criteria: FilterCriteria) -> Bool {
        if criteria.isNameFilterEnabled, !criteria.nameQuery.isEmpty {
            let name = device.name ?? ""
            guard name.range(of: criteria.nameQuery, options: .caseInsensitive) != nil else {
                return false
            }
        }
        if criteria.isIdentifierFilterEnabled, !criteria.identifierQuery.isEmpty {
            let identifier = device.identifier.uuidString
            guard identifier.range(of: criteria.identifierQuery, options: .caseInsensitive) != nil else {
                return false
            }
        }
        if criteria.isRSSIFilterEnabled {
            guard device.rssi >= criteria.minimumRSSI else {
                return false
            }
        }
        return true
    }
}
