import Foundation

public struct GATTCharacteristicProperties: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let read = GATTCharacteristicProperties(rawValue: 1 << 0)
    public static let write = GATTCharacteristicProperties(rawValue: 1 << 1)
    public static let writeWithoutResponse = GATTCharacteristicProperties(rawValue: 1 << 2)
    public static let notify = GATTCharacteristicProperties(rawValue: 1 << 3)
    public static let indicate = GATTCharacteristicProperties(rawValue: 1 << 4)

    /// Notify and Indicate are exposed as a single "subscribe" affordance in the UI.
    public var supportsSubscription: Bool { contains(.notify) || contains(.indicate) }
}

public struct GATTCharacteristic: Identifiable, Equatable, Sendable {
    public var id: GATTIdentifier { identifier }
    public let identifier: GATTIdentifier
    public var name: String?
    public var properties: GATTCharacteristicProperties
    public var latestValue: Data?
    public var isNotifying: Bool

    public init(
        identifier: GATTIdentifier,
        name: String? = nil,
        properties: GATTCharacteristicProperties,
        latestValue: Data? = nil,
        isNotifying: Bool = false
    ) {
        self.identifier = identifier
        self.name = name
        self.properties = properties
        self.latestValue = latestValue
        self.isNotifying = isNotifying
    }

    /// Label for display: an explicitly discovered `name`, else the Bluetooth SIG assigned
    /// characteristic name for this UUID, else the raw UUID string.
    public var displayName: String {
        name ?? GATTAssignedNumbers.characteristicName(for: identifier) ?? identifier.rawValue
    }
}

public struct GATTService: Identifiable, Equatable, Sendable {
    public var id: GATTIdentifier { identifier }
    public let identifier: GATTIdentifier
    public var name: String?
    public var characteristics: [GATTCharacteristic]

    public init(identifier: GATTIdentifier, name: String? = nil, characteristics: [GATTCharacteristic] = []) {
        self.identifier = identifier
        self.name = name
        self.characteristics = characteristics
    }

    /// Label for display: an explicitly discovered `name`, else the Bluetooth SIG assigned
    /// service name for this UUID, else the raw UUID string.
    public var displayName: String {
        name ?? GATTAssignedNumbers.serviceName(for: identifier) ?? identifier.rawValue
    }
}
