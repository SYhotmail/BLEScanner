import Foundation

/// Resolves a `GATTIdentifier` to the human-readable name the Bluetooth SIG publishes for its
/// adopted 16-bit (and 32-bit) UUIDs — e.g. `"180D"` → `"Heart Rate"`, `"2A19"` → `"Battery Level"`.
///
/// The lookup tables live in `GATTAssignedNumbers+Generated.swift`, regenerated from the SIG's
/// canonical YAML by `scripts/generate-assigned-numbers.sh`. Vendor (non-SIG) UUIDs resolve to
/// `nil`. This type is `BLEKitCore`-pure: no CoreBluetooth, Foundation only.
///
/// https://bitbucket.org/bluetooth-SIG/public/src/main/assigned_numbers/uuids/
public enum GATTAssignedNumbers {
    /// The SIG-assigned number for `identifier`, or `nil` if it is not a SIG base-UUID value.
    ///
    /// Accepts all three widths CoreBluetooth's `CBUUID.uuidString` can produce: the bare 16-bit
    /// short form (`"180D"`), the 32-bit form (`"0000180D"`), and a full 128-bit string that sits
    /// on the SIG base UUID (`"0000180D-0000-1000-8000-00805F9B34FB"`).
    public static func assignedNumber(for identifier: GATTIdentifier) -> UInt32? {
        let raw = identifier.rawValue // `GATTIdentifier.init` already uppercased this
        switch raw.count {
        case 4, 8:
            return UInt32(raw, radix: 16)
        case 36:
            guard raw.hasSuffix("-0000-1000-8000-00805F9B34FB") else { return nil }
            return UInt32(raw.prefix(8), radix: 16)
        default:
            return nil
        }
    }

    /// The SIG service name for `identifier` (e.g. `"Heart Rate"`), or `nil` for a vendor UUID.
    public static func serviceName(for identifier: GATTIdentifier) -> String? {
        assignedNumber(for: identifier).flatMap { serviceNames[$0] }
    }

    /// The SIG characteristic name for `identifier` (e.g. `"Battery Level"`), or `nil` for a vendor UUID.
    public static func characteristicName(for identifier: GATTIdentifier) -> String? {
        assignedNumber(for: identifier).flatMap { characteristicNames[$0] }
    }

    /// The SIG descriptor name for `identifier` (e.g. `"Client Characteristic Configuration"`),
    /// or `nil` for a vendor UUID.
    public static func descriptorName(for identifier: GATTIdentifier) -> String? {
        assignedNumber(for: identifier).flatMap { descriptorNames[$0] }
    }
}
