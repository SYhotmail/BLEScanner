import Foundation

/// A well-known BLE manufacturer, identified by the Bluetooth SIG-assigned company identifier
/// carried in the first two (little-endian) bytes of `CBAdvertisementDataManufacturerDataKey`.
///
/// https://www.bluetooth.com/specifications/assigned-numbers/company-identifiers/
public enum Manufacturer: String, Sendable, Equatable, CaseIterable {
    case apple
    case microsoft
    case google
    case samsung
    case amazon
    case sony

    public var companyIdentifier: UInt16 {
        switch self {
        case .apple: 0x004C
        case .microsoft: 0x0006
        case .google: 0x00E0
        case .samsung: 0x0075
        case .amazon: 0x0171
        case .sony: 0x012D
        }
    }

    public var displayName: String {
        switch self {
        case .apple: "Apple"
        case .microsoft: "Microsoft"
        case .google: "Google"
        case .samsung: "Samsung"
        case .amazon: "Amazon"
        case .sony: "Sony"
        }
    }

    public init?(companyIdentifier: UInt16) {
        guard let match = Self.allCases.first(where: { $0.companyIdentifier == companyIdentifier }) else {
            return nil
        }
        self = match
    }

    /// - Parameter manufacturerData: the raw value of `CBAdvertisementDataManufacturerDataKey`.
    public static func parse(manufacturerData: Data) -> Manufacturer? {
        guard manufacturerData.count >= 2 else { return nil }
        let manufacturerData = manufacturerData.prefix(2)
        let bytes = [UInt8](manufacturerData)
        let companyIdentifier = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        let res = Manufacturer(companyIdentifier: companyIdentifier)
        //assert(res != nil)
        return res
    }
}
