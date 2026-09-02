import BLEKitHardware
import CoreBluetooth
import Foundation
import Testing

@Suite("CoreBluetoothErrorDescription")
struct CoreBluetoothErrorDescriptionTests {
    private func cbError(_ code: CBError.Code, _ message: String) -> NSError {
        NSError(
            domain: CBErrorDomain,
            code: code.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    @Test("a nil error maps to nil")
    func nilError() {
        #expect(CoreBluetoothErrorDescription.string(for: nil) == nil)
    }

    @Test("a CBError keeps its numeric code and gains a symbolic name")
    func peripheralDisconnected() {
        let error = cbError(.peripheralDisconnected, "The specified device has disconnected from us.")
        #expect(
            CoreBluetoothErrorDescription.string(for: error)
                == "The specified device has disconnected from us. [CBError 7: peripheralDisconnected]"
        )
    }

    @Test("connectionTimeout (6) is distinguishable from peripheralDisconnected (7)")
    func connectionTimeout() {
        let error = cbError(.connectionTimeout, "The connection has timed out unexpectedly.")
        #expect(
            CoreBluetoothErrorDescription.string(for: error)
                == "The connection has timed out unexpectedly. [CBError 6: connectionTimeout]"
        )
    }

    @Test("an unmapped CBError code still carries its number")
    func unmappedCode() {
        let error = NSError(domain: CBErrorDomain, code: 999, userInfo: [NSLocalizedDescriptionKey: "Weird."])
        #expect(CoreBluetoothErrorDescription.string(for: error) == "Weird. [CBError 999]")
    }

    @Test("a non-CoreBluetooth error still reports its domain and code")
    func otherDomain() {
        let error = NSError(domain: "MyDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Nope."])
        #expect(CoreBluetoothErrorDescription.string(for: error) == "Nope. [MyDomain 42]")
    }
}
