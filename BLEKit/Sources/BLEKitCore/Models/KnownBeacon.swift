import Foundation

/// A beacon UUID the user has registered for CoreLocation-enhanced ranging. `id` derives from
/// `uuid` rather than being independently generated, since only one registration per beacon
/// UUID is ever allowed (enforced at the call sites that append to the shared list).
public struct KnownBeacon: Identifiable, Equatable, Sendable, Codable {
    public var uuid: UUID
    public var label: String
    public var dateAdded: Date

    public var id: UUID { uuid }

    public init(uuid: UUID, label: String, dateAdded: Date) {
        self.uuid = uuid
        self.label = label
        self.dateAdded = dateAdded
    }
}
