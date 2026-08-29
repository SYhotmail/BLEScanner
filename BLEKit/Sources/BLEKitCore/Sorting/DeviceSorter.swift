import Foundation

public enum DeviceSorter {
    /// Orders `devices` for display on the Scanner list. `.appearance` breaks ties on
    /// `firstSeenDate` with the identifier so the order is deterministic (devices discovered in
    /// the same run can share a timestamp); `.rssi` deliberately leaves equal-signal devices in
    /// their existing relative order.
    public static func sorted(
        _ devices: some Sequence<DiscoveredDevice>,
        by order: ScanSortOrder
    ) -> [DiscoveredDevice] {
        switch order {
        case .rssi:
            return devices.sorted { $0.rssi > $1.rssi }
        case .appearance:
            return devices.sorted { lhs, rhs in
                lhs.firstSeenDate == rhs.firstSeenDate
                    ? lhs.identifier.uuidString < rhs.identifier.uuidString
                    : lhs.firstSeenDate < rhs.firstSeenDate
            }
        }
    }
}
