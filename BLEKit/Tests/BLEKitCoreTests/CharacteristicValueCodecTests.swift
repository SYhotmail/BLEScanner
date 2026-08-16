import Foundation
import Testing
@testable import BLEKitCore

@Suite("CharacteristicValueCodec")
struct CharacteristicValueCodecTests {
    @Test("round-trips ASCII text")
    func roundTripsASCIIText() throws {
        let data = try CharacteristicValueCodec.encode("hello", as: .text)
        #expect(CharacteristicValueCodec.utf8String(from: data) == "hello")
    }

    @Test("round-trips non-ASCII UTF-8 text")
    func roundTripsNonASCIIText() throws {
        let data = try CharacteristicValueCodec.encode("caf\u{e9} \u{1f680}", as: .text)
        #expect(CharacteristicValueCodec.utf8String(from: data) == "caf\u{e9} \u{1f680}")
    }

    @Test("rejects empty text input")
    func rejectsEmptyText() {
        #expect(throws: CharacteristicValueCodecError.emptyInput) {
            try CharacteristicValueCodec.encode("", as: .text)
        }
    }

    @Test("decodes a plain hex string")
    func decodesPlainHex() throws {
        let data = try CharacteristicValueCodec.encode("0A1F3C", as: .hex)
        #expect(data == Data([0x0A, 0x1F, 0x3C]))
    }

    @Test("decodes hex tolerating whitespace and an 0x prefix")
    func decodesHexToleratingWhitespaceAndPrefix() throws {
        let data = try CharacteristicValueCodec.encode("0x0A 1F 3C", as: .hex)
        #expect(data == Data([0x0A, 0x1F, 0x3C]))
    }

    @Test("rejects odd-length hex")
    func rejectsOddLengthHex() {
        #expect(throws: CharacteristicValueCodecError.invalidHexLength) {
            try CharacteristicValueCodec.encode("0A1", as: .hex)
        }
    }

    @Test("rejects non-hex characters")
    func rejectsNonHexCharacters() {
        #expect(throws: CharacteristicValueCodecError.invalidHexCharacter) {
            try CharacteristicValueCodec.encode("ZZ11", as: .hex)
        }
    }

    @Test("rejects empty hex input")
    func rejectsEmptyHex() {
        #expect(throws: CharacteristicValueCodecError.emptyInput) {
            try CharacteristicValueCodec.encode("", as: .hex)
        }
    }

    @Test("hexString(from:) round-trips through decodeHex")
    func hexStringRoundTrips() throws {
        let original = Data([0x00, 0xFF, 0x7A])
        let hex = CharacteristicValueCodec.hexString(from: original)
        #expect(try CharacteristicValueCodec.decodeHex(hex) == original)
    }

    @Test("utf8String(from:) returns nil for invalid UTF-8")
    func utf8StringReturnsNilForInvalidData() {
        let invalid = Data([0xFF, 0xFE, 0xFD])
        #expect(CharacteristicValueCodec.utf8String(from: invalid) == nil)
    }
}
