import Foundation
import Testing
@testable import BLEKitCore

@Suite("GATTCharacteristicValueInterpreter")
struct GATTCharacteristicValueInterpreterTests {
    private func interpret(_ uuid: String, _ bytes: [UInt8]) -> String? {
        GATTCharacteristicValueInterpreter.interpretation(of: Data(bytes), for: GATTIdentifier(rawValue: uuid))
    }

    /// 2026-08-31 14:05:09, year 2026 = 0x07EA little-endian.
    private let dateTimeBytes: [UInt8] = [0xEA, 0x07, 0x08, 0x1F, 0x0E, 0x05, 0x09]

    @Test("Date Time decodes the 7-byte structure")
    func dateTime() {
        #expect(interpret("2A08", dateTimeBytes) == "2026-08-31 14:05:09")
    }

    @Test("Date Time with an unknown (zero) date reports it")
    func dateTimeUnknownDate() {
        #expect(interpret("2A08", [0, 0, 0, 0, 0x0E, 0x05, 0x09]) == "unknown date 14:05:09")
    }

    @Test("Day Date Time prefixes the weekday")
    func dayDateTime() {
        #expect(interpret("2A0A", dateTimeBytes + [0x01]) == "Mon 2026-08-31 14:05:09")
    }

    @Test("Exact Time 256 adds fractional seconds")
    func exactTime256() {
        #expect(interpret("2A0C", dateTimeBytes + [0x01, 0x80]) == "Mon 2026-08-31 14:05:09.500")
    }

    @Test("Current Time appends the adjust-reason flags when set")
    func currentTime() {
        #expect(interpret("2A2B", dateTimeBytes + [0x01, 0x80, 0x00]) == "Mon 2026-08-31 14:05:09.500")
        #expect(interpret("2A2B", dateTimeBytes + [0x01, 0x80, 0x01]) == "Mon 2026-08-31 14:05:09.500 — Manual update")
        #expect(
            interpret("2A2B", dateTimeBytes + [0x01, 0x80, 0x0C])
                == "Mon 2026-08-31 14:05:09.500 — Time zone change, DST change"
        )
    }

    @Test("Current Time that is too short has no interpretation")
    func currentTimeTooShort() {
        #expect(interpret("2A2B", dateTimeBytes) == nil)
    }

    @Test("Time Zone decodes the signed 15-minute offset")
    func timeZone() {
        #expect(interpret("2A0E", [0x08]) == "UTC+02:00")            // +8 * 15 min
        #expect(interpret("2A0E", [0xEC]) == "UTC-05:00")            // -20 * 15 min
        #expect(interpret("2A0E", [0x80]) == "Time zone unknown")
    }

    @Test("DST Offset decodes the enumeration")
    func dstOffset() {
        #expect(interpret("2A0D", [0x00]) == "Standard Time")
        #expect(interpret("2A0D", [0x04]) == "Daylight Time (+1:00)")
        #expect(interpret("2A0D", [0xFF]) == "DST offset unknown")
    }

    @Test("Local Time Information combines time zone and DST offset")
    func localTimeInformation() {
        #expect(interpret("2A0F", [0x08, 0x04]) == "UTC+02:00, Daylight Time (+1:00)")
        #expect(interpret("2A0F", [0x08]) == nil)                    // needs both bytes
    }

    @Test("Reference Time Information decodes source, accuracy, and staleness")
    func referenceTimeInformation() {
        #expect(interpret("2A14", [0x01, 0x08, 0x00, 0x02]) == "NTP, accuracy ±1.000s, updated 2h ago")
        #expect(interpret("2A14", [0x02, 0xFF, 0x03, 0x04]) == "GPS, accuracy unknown, updated 3d 4h ago")
    }

    @Test("a non-time characteristic UUID has no interpretation")
    func nonTimeCharacteristic() {
        #expect(interpret("2A19", [0x64]) == nil)                    // Battery Level
    }

    @Test("GATTCharacteristic.interpretedValue surfaces the decoding")
    func characteristicComputedProperty() {
        let currentTime = GATTCharacteristic(
            identifier: GATTIdentifier(rawValue: "2A2B"),
            properties: .read,
            latestValue: Data(dateTimeBytes + [0x01, 0x00, 0x00])
        )
        #expect(currentTime.interpretedValue == "Mon 2026-08-31 14:05:09")

        let noValue = GATTCharacteristic(identifier: GATTIdentifier(rawValue: "2A2B"), properties: .read)
        #expect(noValue.interpretedValue == nil)
    }
}
