import Foundation

/// Decodes a raw characteristic value into a human-readable string for the well-known
/// Bluetooth SIG characteristic types this app understands. Today that is the time / date-time
/// family (Current Time Service and the standalone date-time characteristics); every other
/// UUID returns `nil` and the UI falls back to the hex / UTF-8 rendering.
///
/// All structures follow the SIG GATT Specification Supplement: multi-byte integers are
/// little-endian, "Date Time" is the shared 7-byte building block, and a zero in a
/// year/month/day field means "unknown".
///
/// This type is `BLEKitCore`-pure: Foundation only, no CoreBluetooth.
public enum GATTCharacteristicValueInterpreter {
    public static func interpretation(of data: Data, for identifier: GATTIdentifier) -> String? {
        switch GATTAssignedNumbers.assignedNumber(for: identifier) {
        case 0x2A08: return dateTimeString(data)                       // Date Time
        case 0x2A0A: return dayDateTimeString(data)                    // Day Date Time
        case 0x2A0C: return exactTime256String(data)                   // Exact Time 256
        case 0x2A0D: return dstOffsetString(byte(data, 0))             // DST Offset
        case 0x2A0E: return timeZoneString(byte(data, 0))             // Time Zone
        case 0x2A0F: return localTimeInformationString(data)           // Local Time Information
        case 0x2A14: return referenceTimeInformationString(data)       // Reference Time Information
        case 0x2A2B: return currentTimeString(data)                    // Current Time
        default: return nil
        }
    }

    // MARK: - Composite characteristics

    /// Current Time (0x2A2B): Exact Time 256 (9 bytes) + Adjust Reason (1 byte).
    private static func currentTimeString(_ data: Data) -> String? {
        guard data.count >= 10 else { return nil }
        guard let base = exactTime256String(data) else { return nil }
        let reasons = adjustReasons(byte(data, 9) ?? 0)
        return reasons.isEmpty ? base : "\(base) — \(reasons.joined(separator: ", "))"
    }

    /// Exact Time 256 (0x2A0C): Day Date Time (8 bytes) + Fractions256 (1 byte).
    private static func exactTime256String(_ data: Data) -> String? {
        guard data.count >= 9 else { return nil }
        guard let dayDateTime = dayDateTimeComponents(data) else { return nil }
        let fractions = Int(byte(data, 8) ?? 0)
        let millis = Int((Double(fractions) / 256.0 * 1000).rounded())
        return format(dayDateTime, milliseconds: millis)
    }

    /// Day Date Time (0x2A0A): Date Time (7 bytes) + Day of Week (1 byte).
    private static func dayDateTimeString(_ data: Data) -> String? {
        guard data.count >= 8, let components = dayDateTimeComponents(data) else { return nil }
        return format(components, milliseconds: nil)
    }

    /// Date Time (0x2A08): year (u16), month, day, hours, minutes, seconds.
    private static func dateTimeString(_ data: Data) -> String? {
        guard let components = dateTimeComponents(data) else { return nil }
        return format(DayDateTime(dateTime: components, dayOfWeek: nil), milliseconds: nil)
    }

    /// Local Time Information (0x2A0F): Time Zone (s8) + DST Offset (u8).
    private static func localTimeInformationString(_ data: Data) -> String? {
        guard data.count >= 2 else { return nil }
        let zone = timeZoneString(byte(data, 0)) ?? "Unknown time zone"
        let dst = dstOffsetString(byte(data, 1)) ?? "Unknown DST offset"
        return "\(zone), \(dst)"
    }

    /// Reference Time Information (0x2A14): Source, Accuracy, Days Since Update, Hours Since Update.
    private static func referenceTimeInformationString(_ data: Data) -> String? {
        guard data.count >= 4 else { return nil }
        let source = timeSourceName(byte(data, 0) ?? 0)
        let accuracy = accuracyString(byte(data, 1) ?? 255)
        let days = Int(byte(data, 2) ?? 255)
        let hours = Int(byte(data, 3) ?? 255)
        let since = days >= 255 ? "≥255 days ago" : (days == 0 && hours < 255 ? "\(hours)h ago" : "\(days)d \(hours)h ago")
        return "\(source), accuracy \(accuracy), updated \(since)"
    }

    // MARK: - Field decoders

    private static func timeZoneString(_ raw: UInt8?) -> String? {
        guard let raw else { return nil }
        let value = Int8(bitPattern: raw)
        guard value != -128 else { return "Time zone unknown" }       // 0x80 = unknown
        guard (-48...56).contains(Int(value)) else { return nil }
        let totalMinutes = Int(value) * 15
        let sign = totalMinutes < 0 ? "-" : "+"
        let magnitude = abs(totalMinutes)
        return String(format: "UTC%@%02d:%02d", sign, magnitude / 60, magnitude % 60)
    }

    private static func dstOffsetString(_ raw: UInt8?) -> String? {
        switch raw {
        case 0: "Standard Time"
        case 2: "Half-hour Daylight Time (+0:30)"
        case 4: "Daylight Time (+1:00)"
        case 8: "Double Daylight Time (+2:00)"
        case 255: "DST offset unknown"
        case .some(let other): "DST offset \(other)"
        case nil: nil
        }
    }

    private static func adjustReasons(_ bits: UInt8) -> [String] {
        var reasons: [String] = []
        if bits & 0x01 != 0 { reasons.append("Manual update") }
        if bits & 0x02 != 0 { reasons.append("External reference update") }
        if bits & 0x04 != 0 { reasons.append("Time zone change") }
        if bits & 0x08 != 0 { reasons.append("DST change") }
        return reasons
    }

    private static func timeSourceName(_ raw: UInt8) -> String {
        switch raw {
        case 0: "Unknown source"
        case 1: "NTP"
        case 2: "GPS"
        case 3: "Radio time signal"
        case 4: "Manual"
        case 5: "Atomic clock"
        case 6: "Cellular network"
        default: "Source \(raw)"
        }
    }

    private static func accuracyString(_ raw: UInt8) -> String {
        switch raw {
        case 254: "out of range (>40s)"
        case 255: "unknown"
        default: String(format: "±%.3fs", Double(raw) * 0.125)
        }
    }

    // MARK: - Date Time building blocks

    private struct DateTimeComponents {
        var year: Int
        var month: Int
        var day: Int
        var hours: Int
        var minutes: Int
        var seconds: Int
    }

    private struct DayDateTime {
        var dateTime: DateTimeComponents
        var dayOfWeek: Int?
    }

    private static func dateTimeComponents(_ data: Data) -> DateTimeComponents? {
        guard data.count >= 7 else { return nil }
        let bytes = [UInt8](data)
        return DateTimeComponents(
            year: Int(bytes[0]) | (Int(bytes[1]) << 8),
            month: Int(bytes[2]),
            day: Int(bytes[3]),
            hours: Int(bytes[4]),
            minutes: Int(bytes[5]),
            seconds: Int(bytes[6])
        )
    }

    private static func dayDateTimeComponents(_ data: Data) -> DayDateTime? {
        guard let dateTime = dateTimeComponents(data) else { return nil }
        let rawDay = data.count >= 8 ? Int(byte(data, 7) ?? 0) : 0
        return DayDateTime(dateTime: dateTime, dayOfWeek: (1...7).contains(rawDay) ? rawDay : nil)
    }

    private static let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private static func format(_ value: DayDateTime, milliseconds: Int?) -> String {
        let dt = value.dateTime
        let datePart = dt.year == 0 || dt.month == 0 || dt.day == 0
            ? "unknown date"
            : String(format: "%04d-%02d-%02d", dt.year, dt.month, dt.day)
        var timePart = String(format: "%02d:%02d:%02d", dt.hours, dt.minutes, dt.seconds)
        if let milliseconds, milliseconds > 0 {
            timePart += String(format: ".%03d", milliseconds)
        }
        var result = "\(datePart) \(timePart)"
        if let dayOfWeek = value.dayOfWeek {
            result = "\(weekdayNames[dayOfWeek - 1]) \(result)"
        }
        return result
    }

    private static func byte(_ data: Data, _ offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[data.startIndex + offset]
    }
}
