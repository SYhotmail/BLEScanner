import BLEKitCore
import ComposableArchitecture
import Foundation
import Testing
@testable import BLEFeatures

@MainActor
@Suite("AddKnownBeaconFeature")
struct AddKnownBeaconFeatureTests {
    @Test("saving with a valid UUID sends a delegate action")
    func savingValidUUIDSendsDelegate() async {
        let uuid = UUID(uuidString: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")!
        let store = TestStore(initialState: AddKnownBeaconFeature.State()) {
            AddKnownBeaconFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
        }

        await store.send(.uuidChanged(uuid.uuidString)) {
            $0.uuidText = uuid.uuidString
        }
        await store.send(.labelChanged("Kitchen Beacon")) {
            $0.label = "Kitchen Beacon"
        }
        await store.send(.saveTapped)
        await store.receive(\.delegate.saved)
    }

    @Test("saving with an invalid UUID sets a validation error instead of saving")
    func savingInvalidUUIDSetsValidationError() async {
        let store = TestStore(initialState: AddKnownBeaconFeature.State(uuidText: "not-a-uuid")) {
            AddKnownBeaconFeature()
        }

        await store.send(.saveTapped) {
            $0.validationError = "Enter a valid UUID."
        }
    }

    @Test("editing the UUID field clears any prior validation error")
    func editingUUIDClearsValidationError() async {
        let store = TestStore(initialState: AddKnownBeaconFeature.State(uuidText: "bad")) {
            AddKnownBeaconFeature()
        }

        await store.send(.saveTapped) {
            $0.validationError = "Enter a valid UUID."
        }
        await store.send(.uuidChanged("E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")) {
            $0.uuidText = "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"
            $0.validationError = nil
        }
    }

    @Test("cancelTapped sends a cancelled delegate action")
    func cancelSendsDelegate() async {
        let store = TestStore(initialState: AddKnownBeaconFeature.State()) {
            AddKnownBeaconFeature()
        }

        await store.send(.cancelTapped)
        await store.receive(\.delegate.cancelled)
    }
}
