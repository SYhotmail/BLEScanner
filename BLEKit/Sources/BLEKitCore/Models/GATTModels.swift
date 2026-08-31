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

/// The value CoreBluetooth hands back for a descriptor read. `CBDescriptor.value` is `Any?`,
/// but per the well-known descriptor UUIDs it is only ever an `NSNumber`, `NSString`, or
/// `NSData`; `BLEKitHardware` normalises it into this closed, `Sendable` form at its boundary.
public enum GATTDescriptorValue: Equatable, Sendable {
    case uint(UInt64)
    case string(String)
    case data(Data)

    /// A neutral rendering of the raw value, independent of any per-descriptor interpretation:
    /// hex for numbers and data, the text itself (quoted) for strings.
    public var rawDescription: String {
        switch self {
        case let .uint(value): "0x" + String(value, radix: 16, uppercase: true)
        case let .string(text): "\"\(text)\""
        case let .data(data): data.isEmpty ? "(empty)" : "0x" + CharacteristicValueCodec.hexString(from: data)
        }
    }
}

/// A GATT descriptor attached to a characteristic — discovered via
/// `discoverDescriptors(for:)`, its value optionally read on demand.
public struct GATTDescriptor: Identifiable, Equatable, Sendable {
    public var id: GATTIdentifier { identifier }
    public let identifier: GATTIdentifier
    /// The last value read for this descriptor, or `nil` if it has not been read yet.
    public var value: GATTDescriptorValue?

    public init(identifier: GATTIdentifier, value: GATTDescriptorValue? = nil) {
        self.identifier = identifier
        self.value = value
    }

    /// Label for display: the Bluetooth SIG assigned descriptor name for this UUID
    /// (e.g. `"Client Characteristic Configuration"`), else the raw UUID string.
    public var displayName: String {
        GATTAssignedNumbers.descriptorName(for: identifier) ?? identifier.rawValue
    }

    /// A human-readable interpretation of `value` for the well-known descriptor types
    /// (CCCD subscription state, User Description text, Presentation Format, …), or `nil` when
    /// the value is absent or this descriptor has no special decoding.
    public var interpretedValue: String? {
        value.flatMap { GATTDescriptorInterpreter.interpretation(of: $0, for: identifier) }
    }
}

public struct GATTCharacteristic: Identifiable, Equatable, Sendable {
    public var id: GATTIdentifier { identifier }
    public let identifier: GATTIdentifier
    public var name: String?
    public var properties: GATTCharacteristicProperties
    public var latestValue: Data?
    public var isNotifying: Bool
    /// Descriptors discovered for this characteristic (CCCD, User Description, Presentation
    /// Format, …). Empty until descriptor discovery completes.
    public var descriptors: [GATTDescriptor]

    public init(
        identifier: GATTIdentifier,
        name: String? = nil,
        properties: GATTCharacteristicProperties,
        latestValue: Data? = nil,
        isNotifying: Bool = false,
        descriptors: [GATTDescriptor] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.properties = properties
        self.latestValue = latestValue
        self.isNotifying = isNotifying
        self.descriptors = descriptors
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
    /// GATT "included services" — other services this one references, discovered via
    /// `discoverIncludedServices`. Nested a single level: an included service's own
    /// `includedServices` is always empty.
    public var includedServices: [GATTService]

    public init(
        identifier: GATTIdentifier,
        name: String? = nil,
        characteristics: [GATTCharacteristic] = [],
        includedServices: [GATTService] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.characteristics = characteristics
        self.includedServices = includedServices
    }

    /// Label for display: an explicitly discovered `name`, else the Bluetooth SIG assigned
    /// service name for this UUID, else the raw UUID string.
    public var displayName: String {
        name ?? GATTAssignedNumbers.serviceName(for: identifier) ?? identifier.rawValue
    }
}
