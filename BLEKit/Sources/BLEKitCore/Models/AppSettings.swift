import Foundation

public enum ScanDisplayMode: String, CaseIterable, Equatable, Sendable, Codable {
    case list
    case radar
}

public enum ScanTab: String, CaseIterable, Equatable, Sendable, Codable {
    case nearby
    case history
    case favorites
}

/// Whether scanning restarts periodically while the Scanner screen is open, or waits for the
/// user to start/stop it explicitly.
public enum ScanMode: String, CaseIterable, Equatable, Sendable, Codable {
    case periodic
    case manual
}

/// How the Scanner screen's Nearby (and Favorites) list is ordered.
public enum ScanSortOrder: String, CaseIterable, Equatable, Sendable, Codable {
    /// Strongest signal first.
    case rssi
    /// The order devices were first discovered in, earliest first — a stable list that doesn't
    /// reshuffle as signal strengths fluctuate.
    case appearance
}

public struct AppSettings: Equatable, Sendable, Codable {
    /// Selectable restart intervals for `.manual` scan mode. `.periodic` mode restarts on a
    /// fixed, non-configurable throttle instead (see `ScannerFeature.continuousScanRestartThrottle`).
    public static let availableScanPeriods: [TimeInterval] = [1, 2, 3, 5, 10]

    public var isEnhancedRangingEnabled: Bool
    public var defaultDisplayMode: ScanDisplayMode
    public var scanMode: ScanMode
    public var scanPeriod: TimeInterval
    public var sortOrder: ScanSortOrder

    public init(
        isEnhancedRangingEnabled: Bool = false,
        defaultDisplayMode: ScanDisplayMode = .list,
        scanMode: ScanMode = .periodic,
        scanPeriod: TimeInterval = 2,
        sortOrder: ScanSortOrder = .rssi
    ) {
        self.isEnhancedRangingEnabled = isEnhancedRangingEnabled
        self.defaultDisplayMode = defaultDisplayMode
        self.scanMode = scanMode
        self.scanPeriod = scanPeriod
        self.sortOrder = sortOrder
    }

    /// Decodes each field independently, falling back to the default when a key is absent, so
    /// that adding a new setting doesn't wipe a user's persisted `@Shared(.appStorage)` blob
    /// (which was written before the new key existed) back to `.default`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default
        isEnhancedRangingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnhancedRangingEnabled)
            ?? defaults.isEnhancedRangingEnabled
        defaultDisplayMode = try container.decodeIfPresent(ScanDisplayMode.self, forKey: .defaultDisplayMode)
            ?? defaults.defaultDisplayMode
        scanMode = try container.decodeIfPresent(ScanMode.self, forKey: .scanMode)
            ?? defaults.scanMode
        scanPeriod = try container.decodeIfPresent(TimeInterval.self, forKey: .scanPeriod)
            ?? defaults.scanPeriod
        sortOrder = try container.decodeIfPresent(ScanSortOrder.self, forKey: .sortOrder)
            ?? defaults.sortOrder
    }

    public static let `default` = AppSettings()
}
