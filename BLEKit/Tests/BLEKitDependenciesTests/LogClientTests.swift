import BLEKitCore
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
            BLELogEvent.peripheralDisconnected(identifier: identifier, name: nil).message
                == "Disconnected from peripheral E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"
        )
        #expect(
            BLELogEvent.peripheralConnectionFailed(identifier: identifier, name: "", reason: "timed out").message
                == "Failed to connect to peripheral E2C56DB5-DFFB-48D2-B060-D0F5A71096E0: timed out"
        )
    }

    @Test("only connection failures are logged at the error level")
    func failureLevel() {
        #expect(BLELogEvent.peripheralConnectionFailed(identifier: UUID(), name: nil, reason: "x").isFailure)
        #expect(!BLELogEvent.scanningStarted(mode: .manual).isFailure)
        #expect(!BLELogEvent.peripheralConnected(identifier: UUID(), name: nil).isFailure)
    }

    @Test("the disabled client writes to OSLog.disabled and never traps")
    func disabledClientIsSafe() {
        let client = LogClient.disabled
        client.record(.scanningStarted(mode: .periodic))
        client.record(.scanningStopped)
        client.record(.peripheralConnectionFailed(identifier: UUID(), name: "x", reason: "y"))
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
