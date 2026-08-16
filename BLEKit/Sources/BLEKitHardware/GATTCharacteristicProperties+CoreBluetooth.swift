import BLEKitCore
import CoreBluetooth

extension GATTCharacteristicProperties {
    init(cbProperties: CBCharacteristicProperties) {
        var properties: GATTCharacteristicProperties = []
        if cbProperties.contains(.read) { properties.insert(.read) }
        if cbProperties.contains(.write) { properties.insert(.write) }
        if cbProperties.contains(.writeWithoutResponse) { properties.insert(.writeWithoutResponse) }
        if cbProperties.contains(.notify) { properties.insert(.notify) }
        if cbProperties.contains(.indicate) { properties.insert(.indicate) }
        self = properties
    }
}
