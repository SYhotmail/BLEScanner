import Foundation

public enum SidebarDestination: String, CaseIterable, Equatable, Sendable, Codable, Identifiable {
    case scanner
    case filter
    case settings

    public var id: String { rawValue }

    public var title: String {
        self.rawValue.localizedCapitalized
    }

    public var systemImage: String {
        switch self {
        case .scanner: return "dot.radiowaves.left.and.right"
        case .filter: return "line.3.horizontal.decrease.circle"
        case .settings: return "gearshape"
        }
    }
}
