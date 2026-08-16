import Foundation

/// The two supported ways of entering a characteristic write in the UI.
public enum WriteFormat: String, CaseIterable, Equatable, Sendable {
    case text
    case hex
}

public enum CharacteristicValueCodecError: Error, Equatable, Sendable {
    case emptyInput
    case invalidHexLength
    case invalidHexCharacter
}

public enum CharacteristicValueCodec {
    public static func encode(_ input: String, as format: WriteFormat) throws -> Data {
        switch format {
        case .text:
            guard !input.isEmpty else { throw CharacteristicValueCodecError.emptyInput }
            return Data(input.utf8)
        case .hex:
            return try decodeHex(input)
        }
    }

    public static func decodeHex(_ input: String) throws -> Data {
        let cleaned = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "", options: [.caseInsensitive])
        guard !cleaned.isEmpty else { throw CharacteristicValueCodecError.emptyInput }
        guard cleaned.count.isMultiple(of: 2) else { throw CharacteristicValueCodecError.invalidHexLength }

        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else {
                throw CharacteristicValueCodecError.invalidHexCharacter
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    public static func hexString(from data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined()
    }

    public static func utf8String(from data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }
}
