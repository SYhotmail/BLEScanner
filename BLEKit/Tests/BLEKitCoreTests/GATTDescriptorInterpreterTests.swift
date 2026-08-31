import Foundation
import Testing
@testable import BLEKitCore

@Suite("GATTDescriptorInterpreter")
struct GATTDescriptorInterpreterTests {
    private func interpret(_ uuid: String, _ value: GATTDescriptorValue) -> String? {
        GATTDescriptorInterpreter.interpretation(of: value, for: GATTIdentifier(rawValue: uuid))
    }

    @Test("Client Characteristic Configuration decodes the notify/indicate bits")
    func cccd() {
        #expect(interpret("2902", .uint(0x0000)) == "Disabled")
        #expect(interpret("2902", .uint(0x0001)) == "Notifications enabled")
        #expect(interpret("2902", .uint(0x0002)) == "Indications enabled")
        #expect(interpret("2902", .uint(0x0003)) == "Notifications + Indications enabled")
        // CoreBluetooth can also surface it as raw little-endian bytes.
        #expect(interpret("2902", .data(Data([0x01, 0x00]))) == "Notifications enabled")
    }

    @Test("Server Characteristic Configuration decodes the broadcast bit")
    func sccd() {
        #expect(interpret("2903", .uint(0x0000)) == "Broadcasts disabled")
        #expect(interpret("2903", .uint(0x0001)) == "Broadcasts enabled")
    }

    @Test("Characteristic Extended Properties decodes its flags")
    func extendedProperties() {
        #expect(interpret("2900", .uint(0x0000)) == "None")
        #expect(interpret("2900", .uint(0x0001)) == "Reliable Write")
        #expect(interpret("2900", .uint(0x0003)) == "Reliable Write, Writable Auxiliaries")
    }

    @Test("Characteristic User Description returns the text")
    func userDescription() {
        #expect(interpret("2901", .string("Left wheel speed")) == "Left wheel speed")
        #expect(interpret("2901", .data(Data("Bytes label".utf8))) == "Bytes label")
    }

    @Test("Characteristic Presentation Format decodes format, exponent, and unit")
    func presentationFormat() {
        // format=uint8(0x04), exponent=-2, unit=0x272F (degree Celsius), ns=1, desc=0x0000
        let value = GATTDescriptorValue.data(Data([0x04, 0xFE, 0x2F, 0x27, 0x01, 0x00, 0x00]))
        #expect(interpret("2904", value) == "uint8, ×10^-2, unit 0x272F")

        // format=utf8s, no exponent, no unit
        let plain = GATTDescriptorValue.data(Data([0x19, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00]))
        #expect(interpret("2904", plain) == "utf8s")

        // Too short to be a valid presentation format → no interpretation.
        #expect(interpret("2904", .data(Data([0x04, 0x00]))) == nil)
    }

    @Test("Report Reference decodes the report id and type")
    func reportReference() {
        #expect(interpret("2908", .data(Data([0x02, 0x01]))) == "Report ID 2, Input")
        #expect(interpret("2908", .data(Data([0x05, 0x02]))) == "Report ID 5, Output")
    }

    @Test("Number of Digitals decodes the count")
    func numberOfDigitals() {
        #expect(interpret("2909", .data(Data([0x01]))) == "1 digital")
        #expect(interpret("2909", .data(Data([0x04]))) == "4 digitals")
        #expect(interpret("2909", .uint(3)) == "3 digitals")
    }

    @Test("a vendor descriptor UUID has no interpretation")
    func vendorDescriptor() {
        #expect(interpret("6E400005-B5A3-F393-E0A9-E50E24DCCA9E", .data(Data([0x01]))) == nil)
    }

    @Test("rawDescription renders each value kind neutrally")
    func rawDescription() {
        #expect(GATTDescriptorValue.uint(0x0003).rawDescription == "0x3")
        #expect(GATTDescriptorValue.string("hi").rawDescription == "\"hi\"")
        #expect(GATTDescriptorValue.data(Data([0x0A, 0x1F])).rawDescription == "0x0A1F")
        #expect(GATTDescriptorValue.data(Data()).rawDescription == "(empty)")
    }
}
