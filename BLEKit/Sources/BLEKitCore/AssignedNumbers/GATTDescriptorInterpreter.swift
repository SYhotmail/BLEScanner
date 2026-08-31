import Foundation

/// Decodes a `GATTDescriptorValue` into a human-readable string for the well-known GATT
/// descriptors defined by the Bluetooth SIG. Vendor descriptors, and well-known ones with an
/// unexpected payload shape, return `nil` (the UI falls back to `GATTDescriptorValue.rawDescription`).
///
/// This type is `BLEKitCore`-pure: Foundation only, no CoreBluetooth.
public enum GATTDescriptorInterpreter {
    public static func interpretation(of value: GATTDescriptorValue, for identifier: GATTIdentifier) -> String? {
        switch GATTAssignedNumbers.assignedNumber(for: identifier) {
        case 0x2900: return extendedProperties(value)
        case 0x2901: return userDescription(value)
        case 0x2902: return clientCharacteristicConfiguration(value)
        case 0x2903: return serverCharacteristicConfiguration(value)
        case 0x2904: return presentationFormat(value)
        case 0x2908: return reportReference(value)
        case 0x2909: return numberOfDigitals(value)
        default: return nil
        }
    }

    // MARK: - 0x2900 Characteristic Extended Properties

    private static func extendedProperties(_ value: GATTDescriptorValue) -> String? {
        guard let bits = uint16(value) else { return nil }
        var flags: [String] = []
        if bits & 0x0001 != 0 { flags.append("Reliable Write") }
        if bits & 0x0002 != 0 { flags.append("Writable Auxiliaries") }
        return flags.isEmpty ? "None" : flags.joined(separator: ", ")
    }

    // MARK: - 0x2901 Characteristic User Description

    private static func userDescription(_ value: GATTDescriptorValue) -> String? {
        switch value {
        case let .string(text): return text
        case let .data(data): return CharacteristicValueCodec.utf8String(from: data)
        case .uint: return nil
        }
    }

    // MARK: - 0x2902 Client Characteristic Configuration

    private static func clientCharacteristicConfiguration(_ value: GATTDescriptorValue) -> String? {
        guard let bits = uint16(value) else { return nil }
        var enabled: [String] = []
        if bits & 0x0001 != 0 { enabled.append("Notifications") }
        if bits & 0x0002 != 0 { enabled.append("Indications") }
        return enabled.isEmpty ? "Disabled" : enabled.joined(separator: " + ") + " enabled"
    }

    // MARK: - 0x2903 Server Characteristic Configuration

    private static func serverCharacteristicConfiguration(_ value: GATTDescriptorValue) -> String? {
        guard let bits = uint16(value) else { return nil }
        return bits & 0x0001 != 0 ? "Broadcasts enabled" : "Broadcasts disabled"
    }

    // MARK: - 0x2904 Characteristic Presentation Format

    /// 7 bytes: format (u8), exponent (s8), unit (u16 LE), namespace (u8), description (u16 LE).
    private static func presentationFormat(_ value: GATTDescriptorValue) -> String? {
        guard case let .data(data) = value, data.count >= 7 else { return nil }
        let bytes = [UInt8](data)
        let format = formatTypeName(bytes[0])
        let exponent = Int8(bitPattern: bytes[1])
        let unit = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        let description = UInt16(bytes[5]) | (UInt16(bytes[6]) << 8)

        var parts = [format]
        if exponent != 0 { parts.append("×10^\(exponent)") }
        if unit != 0 { parts.append("unit 0x" + String(format: "%04X", unit)) }
        if description != 0 { parts.append("description 0x" + String(format: "%04X", description)) }
        return parts.joined(separator: ", ")
    }

    private static func formatTypeName(_ raw: UInt8) -> String {
        switch raw {
        case 0x01: "boolean"
        case 0x02: "2-bit"
        case 0x03: "nibble"
        case 0x04: "uint8"
        case 0x05: "uint12"
        case 0x06: "uint16"
        case 0x07: "uint24"
        case 0x08: "uint32"
        case 0x09: "uint48"
        case 0x0A: "uint64"
        case 0x0B: "uint128"
        case 0x0C: "sint8"
        case 0x0D: "sint12"
        case 0x0E: "sint16"
        case 0x0F: "sint24"
        case 0x10: "sint32"
        case 0x11: "sint48"
        case 0x12: "sint64"
        case 0x13: "sint128"
        case 0x14: "float32"
        case 0x15: "float64"
        case 0x16: "SFLOAT"
        case 0x17: "FLOAT"
        case 0x18: "duint16"
        case 0x19: "utf8s"
        case 0x1A: "utf16s"
        case 0x1B: "struct"
        default: "format 0x" + String(format: "%02X", raw)
        }
    }

    // MARK: - 0x2908 Report Reference

    private static func reportReference(_ value: GATTDescriptorValue) -> String? {
        guard case let .data(data) = value, data.count >= 2 else { return nil }
        let bytes = [UInt8](data)
        let type: String
        switch bytes[1] {
        case 1: type = "Input"
        case 2: type = "Output"
        case 3: type = "Feature"
        default: type = "type 0x" + String(format: "%02X", bytes[1])
        }
        return "Report ID \(bytes[0]), \(type)"
    }

    // MARK: - 0x2909 Number of Digitals

    private static func numberOfDigitals(_ value: GATTDescriptorValue) -> String? {
        let count: UInt64
        switch value {
        case let .uint(raw): count = raw
        case let .data(data) where !data.isEmpty: count = UInt64(data[data.startIndex])
        default: return nil
        }
        return "\(count) digital\(count == 1 ? "" : "s")"
    }

    // MARK: - Helpers

    /// A 16-bit configuration value, whether CoreBluetooth surfaced it as a number or as raw bytes.
    private static func uint16(_ value: GATTDescriptorValue) -> UInt16? {
        switch value {
        case let .uint(raw):
            return UInt16(truncatingIfNeeded: raw)
        case let .data(data) where !data.isEmpty:
            let bytes = [UInt8](data)
            return bytes.count >= 2 ? UInt16(bytes[0]) | (UInt16(bytes[1]) << 8) : UInt16(bytes[0])
        default:
            return nil
        }
    }
}
