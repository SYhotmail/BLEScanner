import Foundation

/// A coarse distance bucket, shared by the RSSI-heuristic classifier and CoreLocation's
/// `CLProximity` ranging results so both mechanisms feed the same radar view.
public enum Proximity: String, CaseIterable, Equatable, Sendable, Codable {
    case immediate
    case near
    case far
    case unknown
}
