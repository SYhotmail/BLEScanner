import BLEFeatures
import BLEKitCore
import ComposableArchitecture
import SwiftUI

struct CharacteristicDetailView: View {
    @Bindable var store: StoreOf<DeviceDetailFeature>
    let serviceIdentifier: GATTIdentifier
    let characteristic: GATTCharacteristic

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if characteristic.properties.contains(.read) {
                readSection
            }
            if characteristic.properties.supportsSubscription {
                notifySection
            }
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writeSection
            }
            if !characteristic.descriptors.isEmpty {
                descriptorsSection
            }
        }
        .padding(.vertical, 4)
    }

    /// Every descriptor already has a value — one read pass has covered them all.
    private var allDescriptorsRead: Bool {
        characteristic.descriptors.allSatisfy { $0.value != nil }
    }

    private var descriptorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Descriptors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Read") {
                    store.send(.readDescriptorsTapped(
                        service: serviceIdentifier,
                        characteristic: characteristic.identifier
                    ))
                }
                .font(.caption)
                .disabled(allDescriptorsRead)
                .accessibilityIdentifier("characteristic.\(characteristic.identifier.rawValue).descriptorsReadButton")
            }
            ForEach(characteristic.descriptors) { descriptor in
                descriptorRow(descriptor)
            }
        }
    }

    private func descriptorRow(_ descriptor: GATTDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            VStack(alignment: .leading, spacing: 1) {
                Text(descriptor.displayName)
                    .font(.caption)
                if descriptor.displayName != descriptor.identifier.rawValue {
                    Text(descriptor.identifier.rawValue)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            if let value = descriptor.value {
                if let interpreted = descriptor.interpretedValue {
                    Text(interpreted)
                        .font(.caption.monospaced())
                }
                Text(value.rawDescription)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Text("No value read yet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var readSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Value").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Read") {
                    store.send(.readTapped(service: serviceIdentifier, characteristic: characteristic.identifier))
                }
                .font(.caption)
                .accessibilityIdentifier("characteristic.\(characteristic.identifier.rawValue).readButton")
            }
            if let value = characteristic.latestValue {
                if let decoded = characteristic.interpretedValue {
                    Text("Decoded: \(decoded)")
                        .font(.caption.monospaced())
                }
                Text("Hex: \(CharacteristicValueCodec.hexString(from: value))")
                    .font(.caption.monospaced())
                if let text = CharacteristicValueCodec.utf8String(from: value) {
                    Text("Text: \(text)")
                        .font(.caption.monospaced())
                }
            } else {
                Text("No value read yet").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var notifySection: some View {
        Toggle("Notify", isOn: notifyBinding)
            .font(.caption)
    }

    private var notifyBinding: Binding<Bool> {
        Binding(
            get: { characteristic.isNotifying },
            set: { enabled in
                store.send(.notifyToggled(service: serviceIdentifier, characteristic: characteristic.identifier, enabled: enabled))
            }
        )
    }

    private var writeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Format", selection: formatBinding) {
                Text("Text").tag(WriteFormat.text)
                Text("Hex").tag(WriteFormat.hex)
            }
            .pickerStyle(.segmented)

            TextField(
                store.writeFormatsByCharacteristic[characteristic.identifier] == .hex ? "Hex e.g. 0A1F" : "Text",
                text: writeInputBinding
            )
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if let error = store.writeErrorsByCharacteristic[characteristic.identifier] {
                Text(error).font(.caption2).foregroundStyle(.red)
            }

            Button("Write") {
                store.send(.writeTapped(service: serviceIdentifier, characteristic: characteristic.identifier))
            }
            .font(.caption)
        }
    }

    private var formatBinding: Binding<WriteFormat> {
        Binding(
            get: { store.writeFormatsByCharacteristic[characteristic.identifier] ?? .text },
            set: { store.send(.writeFormatChanged(characteristic: characteristic.identifier, format: $0)) }
        )
    }

    private var writeInputBinding: Binding<String> {
        Binding(
            get: { store.writeInputsByCharacteristic[characteristic.identifier] ?? "" },
            set: { store.send(.writeInputChanged(characteristic: characteristic.identifier, text: $0)) }
        )
    }
}
