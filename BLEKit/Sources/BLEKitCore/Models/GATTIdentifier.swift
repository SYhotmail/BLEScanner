import Foundation

/// A platform-agnostic stand-in for `CBUUID`, kept as a plain string so `BLEKitCore`
/// never has to import CoreBluetooth. `BLEKitHardware` converts to/from `CBUUID`.
public struct GATTIdentifier: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.uppercased()
    }

    public var description: String { rawValue }
}
