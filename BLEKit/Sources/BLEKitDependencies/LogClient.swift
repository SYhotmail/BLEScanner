import BLEKitCore
import BLEKitHardware
import Dependencies
import DependenciesMacros
import Foundation
import os

/// A critical BLE lifecycle event worth recording to the unified logging system (visible in
/// Console.app and `log stream`). Kept as a closed enum rather than free-form strings so call
/// sites stay terse and the exact set of "critical" events is reviewable in one place.
public enum BLELogEvent: Equatable, Sendable {
    // MARK: Lifecycle
    case scanningStarted(mode: ScanMode)
    case scanningStopped
    case deviceSelected(identifier: UUID, name: String?)
    case peripheralConnected(identifier: UUID, name: String?)
    case peripheralDisconnected(identifier: UUID, name: String?)

    // MARK: Errors
    case bluetoothStateChanged(BluetoothState)
    case peripheralConnectionFailed(identifier: UUID, name: String?, reason: String)
    case peripheralOperationFailed(identifier: UUID, name: String?, reason: String)
    case characteristicWriteRejected(characteristic: String, reason: String)

    /// The single-line message written to the log.
    public var message: String {
        switch self {
        case let .scanningStarted(mode):
            return "Scanning started (mode: \(mode.rawValue))"
        case .scanningStopped:
            return "Scanning stopped"
        case let .deviceSelected(identifier, name):
            return "Selected device \(Self.describe(identifier, name))"
        case let .peripheralConnected(identifier, name):
            return "Connected to peripheral \(Self.describe(identifier, name))"
        case let .peripheralDisconnected(identifier, name):
            return "Disconnected from peripheral \(Self.describe(identifier, name))"
        case let .bluetoothStateChanged(state):
            return "Bluetooth state changed to \(String(describing: state))"
        case let .peripheralConnectionFailed(identifier, name, reason):
            return "Failed to connect to peripheral \(Self.describe(identifier, name)): \(reason)"
        case let .peripheralOperationFailed(identifier, name, reason):
            return "Operation failed on peripheral \(Self.describe(identifier, name)): \(reason)"
        case let .characteristicWriteRejected(characteristic, reason):
            return "Write to characteristic \(characteristic) rejected: \(reason)"
        }
    }

    /// The `OSLog` level this event is written at — `.error` for failures and unusable
    /// Bluetooth states, `.default` for everything else.
    var level: OSLogType {
        switch self {
        case .peripheralConnectionFailed, .peripheralOperationFailed, .characteristicWriteRejected:
            return .error
        case let .bluetoothStateChanged(state):
            switch state {
            case .poweredOn, .unknown, .resetting:
                return .default
            case .unsupported, .unauthorized, .poweredOff:
                return .error
            }
        case .scanningStarted, .scanningStopped, .deviceSelected,
             .peripheralConnected, .peripheralDisconnected:
            return .default
        }
    }

    private static func describe(_ identifier: UUID, _ name: String?) -> String {
        guard let name, !name.isEmpty else { return identifier.uuidString }
        return "\(name) (\(identifier.uuidString))"
    }
}

/// Records critical BLE lifecycle events to `OSLog`.
///
/// The `OSLog` instance is injected rather than hard-coded so tests (and previews) can pass
/// `OSLog.disabled` — an empty log that drops every message. Reducers therefore still exercise
/// the logging code path under test, but nothing is written and there are no assertions to make.
@DependencyClient
public struct LogClient: Sendable {
    public var record: @Sendable (_ event: BLELogEvent) -> Void
}

extension LogClient {
    /// Builds a client backed by the given `OSLog`. `liveValue` passes a real subsystem log;
    /// tests and previews pass `OSLog.disabled`.
    public static func osLog(_ log: OSLog) -> LogClient {
        let logger = Logger(log)
        return LogClient { event in
            logger.log(level: event.level, "\(event.message, privacy: .public)")
        }
    }

    /// A client wired to `OSLog.disabled` — every `record` call is a no-op. Used by tests, by
    /// SwiftUI previews, and by the app's `-UITesting` launch path.
    public static let disabled = LogClient.osLog(.disabled)

    /// Subsystem for the live log. Falls back to a fixed string when there's no app bundle
    /// (`swift test`, previews).
    private static let liveSubsystem = Bundle.main.bundleIdentifier ?? "com.siarheiy.BLEScanner"
}

extension LogClient: DependencyKey {
    public static let liveValue = LogClient.osLog(
        OSLog(subsystem: LogClient.liveSubsystem, category: "CriticalEvents")
    )

    public static let testValue = LogClient.disabled
    public static let previewValue = LogClient.disabled
}

extension DependencyValues {
    /// Records critical BLE events — scan start/stop, device selection, peripheral
    /// connect/disconnect, and errors (connection/operation failures, Bluetooth going
    /// unavailable) — to `OSLog`. See ``LogClient``.
    public var bleLog: LogClient {
        get { self[LogClient.self] }
        set { self[LogClient.self] = newValue }
    }
}
