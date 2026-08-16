import Foundation

/// Parses Apple's iBeacon frame directly out of CoreBluetooth advertisement manufacturer
/// data, so beacon detection works for every discovered device with no extra permission.
public enum AppleBeaconParser {
    static let appleCompanyIdentifier: UInt16 = 0x004C
    static let iBeaconType: UInt8 = 0x02
    static let iBeaconDataLength: UInt8 = 0x15
    static let frameByteCount = 25 // 2 (company ID) + 1 (type) + 1 (length) + 16 (UUID) + 2 (major) + 2 (minor) + 1 (power)

    /// - Parameter manufacturerData: the raw value of `CBAdvertisementDataManufacturerDataKey`.
    public static func parse(manufacturerData: Data) -> BeaconReading? {
        guard manufacturerData.count >= frameByteCount else { return nil }
        let bytes = [UInt8](manufacturerData)

        let companyIdentifier = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        guard companyIdentifier == appleCompanyIdentifier else { return nil }
        guard bytes[2] == iBeaconType else { return nil }
        guard bytes[3] == iBeaconDataLength else { return nil }

        guard let uuid = uuid(fromBytes: Array(bytes[4..<20])) else { return nil }

        let major = (UInt16(bytes[20]) << 8) | UInt16(bytes[21])
        let minor = (UInt16(bytes[22]) << 8) | UInt16(bytes[23])
        let measuredPower = Int8(bitPattern: bytes[24])

        return BeaconReading(uuid: uuid, major: major, minor: minor, measuredPower: measuredPower)
    }

    private static func uuid(fromBytes bytes: [UInt8]) -> UUID? {
        guard bytes.count == 16 else { return nil }
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }
}
