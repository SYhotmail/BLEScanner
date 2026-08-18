import Foundation

/// One reconstructed BLE advertisement AD structure (length/type/value), formatted the way
/// raw-packet BLE scanners (e.g. the Android reference app) present them.
///
/// CoreBluetooth never exposes the literal over-the-air advertisement bytes to apps — only a
/// pre-parsed `advertisementData` dictionary — so these entries are *reconstructed* from
/// `DiscoveredDevice`'s already-parsed fields rather than being the packet's actual bytes.
/// Some AD types iOS never surfaces at all (e.g. Flags) are simply absent here.
public struct AdvertisementDataStructure: Identifiable, Equatable, Sendable {
    public let id: Int
    public let length: Int
    public let type: UInt8
    public let typeName: String
    public let valueHex: String

    public init(id: Int, length: Int, type: UInt8, typeName: String, valueHex: String) {
        self.id = id
        self.length = length
        self.type = type
        self.typeName = typeName
        self.valueHex = valueHex
    }
}

public enum RawAdvertisementDataBuilder {
    private static let completeLocalNameType: UInt8 = 0x09
    private static let manufacturerSpecificDataType: UInt8 = 0xFF
    private static let txPowerLevelType: UInt8 = 0x0A
    private static let complete16BitServiceUUIDsType: UInt8 = 0x03
    private static let complete128BitServiceUUIDsType: UInt8 = 0x07

    public static func structures(for device: DiscoveredDevice) -> [AdvertisementDataStructure] {
        var entries: [(type: UInt8, typeName: String, valueBytes: [UInt8])] = []

        if let nameBytes = device.name.flatMap({ [UInt8]($0.utf8) }), !nameBytes.isEmpty {
            entries.append((completeLocalNameType, "Complete Local Name", nameBytes))
        }

        if let manufacturerData = device.manufacturerData, !manufacturerData.isEmpty {
            entries.append((manufacturerSpecificDataType, "Manufacturer Specific Data", [UInt8](manufacturerData)))
        }

        if let txPowerLevel = device.txPowerLevel {
            let byte = UInt8(bitPattern: Int8(clamping: txPowerLevel))
            entries.append((txPowerLevelType, "Tx Power Level", [byte]))
        }

        let shortUUIDValues: [UInt16] = device.advertisedServiceIdentifiers
            .filter { $0.rawValue.count == 4 }
            .compactMap { (identifier: GATTIdentifier) -> UInt16? in UInt16(identifier.rawValue, radix: 16) }
        var shortUUIDBytes: [UInt8] = []
        for value in shortUUIDValues {
            shortUUIDBytes.append(UInt8(value & 0xFF))
            shortUUIDBytes.append(UInt8(value >> 8))
        }
        if !shortUUIDBytes.isEmpty {
            entries.append((complete16BitServiceUUIDsType, "Complete List of 16-bit Service UUIDs", shortUUIDBytes))
        }

        let longUUIDByteGroups: [[UInt8]] = device.advertisedServiceIdentifiers
            .filter { $0.rawValue.count != 4 }
            .compactMap { (identifier: GATTIdentifier) -> [UInt8]? in littleEndianBytes(fromUUIDString: identifier.rawValue) }
        let longUUIDBytes = longUUIDByteGroups.flatMap { $0 }
        if !longUUIDBytes.isEmpty {
            entries.append((complete128BitServiceUUIDsType, "Complete List of 128-bit Service UUIDs", longUUIDBytes))
        }

        return entries.enumerated().map { index, entry in
            AdvertisementDataStructure(
                id: index,
                length: entry.valueBytes.count + 1,
                type: entry.type,
                typeName: entry.typeName,
                valueHex: CharacteristicValueCodec.hexString(from: Data(entry.valueBytes))
            )
        }
    }

    /// Plain-text rendering of `structures(for:)`, one AD structure per paragraph — suitable
    /// for a native `Alert`'s message, which only accepts `Text`, not arbitrary views.
    public static func plainTextDescription(for device: DiscoveredDevice) -> String {
        let entries = structures(for: device)
        guard !entries.isEmpty else {
            return "No reconstructable advertisement data available."
        }
        return entries
            .map { entry in
                let type = String(format: "0x%02X", entry.type)
                return "\(entry.typeName)\nLEN: \(entry.length)  TYPE: \(type)\nVALUE: 0x\(entry.valueHex)"
            }
            .joined(separator: "\n\n")
    }

    /// BLE transmits multi-byte fields (including 128-bit UUIDs) least-significant-byte first,
    /// the reverse of a UUID string's big-endian textual byte order.
    private static func littleEndianBytes(fromUUIDString rawValue: String) -> [UInt8]? {
        let hex = rawValue.replacingOccurrences(of: "-", with: "")
        guard hex.count == 32 else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return bytes.reversed()
    }
}
