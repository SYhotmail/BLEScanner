import Foundation
import Testing
@testable import BLEKitCore

@Suite("AppleBeaconParser")
struct AppleBeaconParserTests {
    // Company ID 0x004C (LE) + type 0x02 + length 0x15 + UUID E2C56DB5-DFFB-48D2-B060-D0F5A71096E0
    // + major 0x0001 + minor 0x0002 + measured power -59 (0xC5).
    static let validFrameBytes: [UInt8] = [
        0x4C, 0x00, 0x02, 0x15,
        0xE2, 0xC5, 0x6D, 0xB5, 0xDF, 0xFB, 0x48, 0xD2, 0xB0, 0x60, 0xD0, 0xF5, 0xA7, 0x10, 0x96, 0xE0,
        0x00, 0x01,
        0x00, 0x02,
        0xC5,
    ]

    @Test("parses a well-formed frame")
    func parsesValidFrame() {
        let reading = AppleBeaconParser.parse(manufacturerData: Data(Self.validFrameBytes))
        #expect(reading != nil)
        #expect(reading?.uuid == UUID(uuidString: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"))
        #expect(reading?.major == 1)
        #expect(reading?.minor == 2)
        #expect(reading?.measuredPower == -59)
    }

    @Test("rejects a non-Apple company identifier")
    func rejectsWrongCompanyID() {
        var bytes = Self.validFrameBytes
        bytes[0] = 0xFF
        bytes[1] = 0xFF
        #expect(AppleBeaconParser.parse(manufacturerData: Data(bytes)) == nil)
    }

    @Test("rejects a non-iBeacon type byte")
    func rejectsWrongType() {
        var bytes = Self.validFrameBytes
        bytes[2] = 0x00
        #expect(AppleBeaconParser.parse(manufacturerData: Data(bytes)) == nil)
    }

    @Test("rejects a mismatched length byte")
    func rejectsWrongLength() {
        var bytes = Self.validFrameBytes
        bytes[3] = 0x10
        #expect(AppleBeaconParser.parse(manufacturerData: Data(bytes)) == nil)
    }

    @Test("rejects data truncated below 25 bytes")
    func rejectsTruncatedData() {
        let bytes = Self.validFrameBytes.dropLast(5)
        #expect(AppleBeaconParser.parse(manufacturerData: Data(bytes)) == nil)
    }

    @Test("rejects empty data")
    func rejectsEmptyData() {
        #expect(AppleBeaconParser.parse(manufacturerData: Data()) == nil)
    }

    @Test("tolerates trailing bytes after the beacon frame")
    func toleratesTrailingBytes() {
        let bytes = Self.validFrameBytes + [0xAA, 0xBB]
        #expect(AppleBeaconParser.parse(manufacturerData: Data(bytes)) != nil)
    }
}
