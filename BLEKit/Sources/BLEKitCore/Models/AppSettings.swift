import Foundation

public enum ScanDisplayMode: String, CaseIterable, Equatable, Sendable, Codable {
    case list
    case radar
}

public enum ScanTab: String, CaseIterable, Equatable, Sendable, Codable {
    case nearby
    case history
}

public struct AppSettings: Equatable, Sendable, Codable {
    public var isEnhancedRangingEnabled: Bool
    public var defaultDisplayMode: ScanDisplayMode

    public init(isEnhancedRangingEnabled: Bool = false, defaultDisplayMode: ScanDisplayMode = .list) {
        self.isEnhancedRangingEnabled = isEnhancedRangingEnabled
        self.defaultDisplayMode = defaultDisplayMode
    }

    public static let `default` = AppSettings()
}
