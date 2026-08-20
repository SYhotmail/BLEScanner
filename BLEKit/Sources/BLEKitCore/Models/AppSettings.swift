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

public struct AppSettings: Equatable, Sendable, Codable {
    /// Selectable restart intervals for `.manual` scan mode. `.periodic` mode restarts on a
    /// fixed, non-configurable throttle instead (see `ScannerFeature.continuousScanRestartThrottle`).
    public static let availableScanPeriods: [TimeInterval] = [1, 2, 3, 5, 10]

    public var isEnhancedRangingEnabled: Bool
    public var defaultDisplayMode: ScanDisplayMode
    public var scanMode: ScanMode
    public var scanPeriod: TimeInterval

    public init(
        isEnhancedRangingEnabled: Bool = false,
        defaultDisplayMode: ScanDisplayMode = .list,
        scanMode: ScanMode = .periodic,
        scanPeriod: TimeInterval = 2
    ) {
        self.isEnhancedRangingEnabled = isEnhancedRangingEnabled
        self.defaultDisplayMode = defaultDisplayMode
        self.scanMode = scanMode
        self.scanPeriod = scanPeriod
    }

    public static let `default` = AppSettings()
}
