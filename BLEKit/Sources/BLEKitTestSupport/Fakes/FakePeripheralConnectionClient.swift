import BLEKitCore
import BLEKitDependencies
import BLEKitHardware
import Foundation

public final class FakePeripheralConnectionClient: @unchecked Sendable {
    public let identifier: UUID
    private let channel = TestEventChannel<PeripheralConnectionEvent>()

    public init(identifier: UUID = UUID()) {
        self.identifier = identifier
    }

    public func send(_ event: PeripheralConnectionEvent) {
        channel.send(event)
    }

    public func finish() {
        channel.finish()
    }

    public var client: PeripheralConnectionClient {
        PeripheralConnectionClient(
            identifier: identifier,
            events: { [channel] in channel.stream() },
            connect: {},
            disconnect: {},
            discoverServices: {},
            readValue: { _, _ in },
            writeValue: { _, _, _, _ in },
            setNotify: { _, _, _ in }
        )
    }
}
