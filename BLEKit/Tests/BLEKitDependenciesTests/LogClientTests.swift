import BLEKitCore
import BLEKitHardware
import Dependencies
import Foundation
import os
import Testing
@testable import BLEKitDependencies

@Suite("LogClient")
struct LogClientTests {
    @Test("each critical event renders a single-line message")
    func eventMessages() {
        let identifier = UUID(uuidString: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")!

        #expect(BLELogEvent.scanningStarted(mode: .periodic).message == "Scanning started (mode: periodic)")
        #expect(BLELogEvent.scanningStopped.message == "Scanning stopped")
        #expect(
            BLELogEvent.peripheralConnected(identifier: identifier, name: "Sensor").message
                == "Connected to peripheral Sensor (E2C56DB5-DFFB-48D2-B060-D0F5A71096E0)"
        )
        #expect(
            BLELogEvent.peripheralDisconnected(identifier: identifier, name: nil, reason: nil).message
                == "Disconnected from peripheral E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"
        )
        #expect(
            BLELogEvent.peripheralDisconnected(identifier: identifier, name: "Sensor", reason: "out of range").message
                == "Unexpectedly disconnected from peripheral Sensor (E2C56DB5-DFFB-48D2-B060-D0F5A71096E0): out of range"
        )
        #expect(
            BLELogEvent.peripheralConnectionFailed(identifier: identifier, name: "", reason: "timed out").message
                == "Failed to connect to peripheral E2C56DB5-DFFB-48D2-B060-D0F5A71096E0: timed out"
        )
        #expect(
            BLELogEvent.deviceSelected(identifier: identifier, name: "Sensor").message
                == "Selected device Sensor (E2C56DB5-DFFB-48D2-B060-D0F5A71096E0)"
        )
        #expect(
            BLELogEvent.bluetoothStateChanged(.poweredOff).message
                == "Bluetooth state changed to poweredOff"
        )
        #expect(
            BLELogEvent.peripheralOperationFailed(identifier: identifier, name: nil, reason: "characteristicNotFound").message
                == "Operation failed on peripheral E2C56DB5-DFFB-48D2-B060-D0F5A71096E0: characteristicNotFound"
        )
        #expect(
            BLELogEvent.characteristicWriteRejected(characteristic: "2A00", reason: "bad hex").message
                == "Write to characteristic 2A00 rejected: bad hex"
        )
    }

    @Test("failures and unusable Bluetooth states log at .error, everything else at .default")
    func eventLevels() {
        #expect(BLELogEvent.peripheralConnectionFailed(identifier: UUID(), name: nil, reason: "x").level == .error)
        #expect(BLELogEvent.peripheralOperationFailed(identifier: UUID(), name: nil, reason: "x").level == .error)
        #expect(BLELogEvent.characteristicWriteRejected(characteristic: "2A00", reason: "x").level == .error)
        #expect(BLELogEvent.bluetoothStateChanged(.poweredOff).level == .error)
        #expect(BLELogEvent.bluetoothStateChanged(.unauthorized).level == .error)
        #expect(BLELogEvent.peripheralDisconnected(identifier: UUID(), name: nil, reason: "dropped").level == .error)

        #expect(BLELogEvent.bluetoothStateChanged(.poweredOn).level == .default)
        #expect(BLELogEvent.scanningStarted(mode: .manual).level == .default)
        #expect(BLELogEvent.deviceSelected(identifier: UUID(), name: nil).level == .default)
        #expect(BLELogEvent.peripheralConnected(identifier: UUID(), name: nil).level == .default)
        #expect(BLELogEvent.peripheralDisconnected(identifier: UUID(), name: nil, reason: nil).level == .default)
    }

    @Test("the disabled client writes to OSLog.disabled and never traps")
    func disabledClientIsSafe() {
        let client = LogClient.disabled
        client.record(.scanningStarted(mode: .periodic))
        client.record(.scanningStopped)
        client.record(.deviceSelected(identifier: UUID(), name: "x"))
        client.record(.bluetoothStateChanged(.unsupported))
        client.record(.peripheralDisconnected(identifier: UUID(), name: "x", reason: nil))
        client.record(.peripheralDisconnected(identifier: UUID(), name: "x", reason: "y"))
        client.record(.peripheralConnectionFailed(identifier: UUID(), name: "x", reason: "y"))
        client.record(.peripheralOperationFailed(identifier: UUID(), name: "x", reason: "y"))
        client.record(.characteristicWriteRejected(characteristic: "2A00", reason: "y"))
    }

    @Test("the live client is backed by a real subsystem log and doesn't trap")
    func liveClientLogs() {
        LogClient.liveValue.record(.peripheralConnected(identifier: UUID(), name: "Sensor"))
    }

    @Test("a custom client observes exactly the events passed to record")
    func customClientObservesEvents() {
        let recorded = LockIsolated<[BLELogEvent]>([])
        let capturing = LogClient { event in recorded.withValue { $0.append(event) } }

        capturing.record(.scanningStarted(mode: .manual))
        capturing.record(.scanningStopped)

        #expect(recorded.value == [.scanningStarted(mode: .manual), .scanningStopped])
    }
}
