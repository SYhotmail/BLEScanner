import BLEKitCore
import ComposableArchitecture
import DependenciesTestSupport
import Testing
@testable import BLEFeatures

@MainActor
@Suite("FilterFeature", .dependencies)
struct FilterFeatureTests {
    @Test("toggling and editing each filter field mutates shared criteria")
    func editsEachField() async {
        let store = TestStore(initialState: FilterFeature.State()) {
            FilterFeature()
        }

        await store.send(.nameFilterToggled(true)) {
            $0.$criteria.withLock { $0.isNameFilterEnabled = true }
        }
        await store.send(.nameQueryChanged("kitchen")) {
            $0.$criteria.withLock { $0.nameQuery = "kitchen" }
        }
        await store.send(.identifierFilterToggled(true)) {
            $0.$criteria.withLock { $0.isIdentifierFilterEnabled = true }
        }
        await store.send(.identifierQueryChanged("AB12")) {
            $0.$criteria.withLock { $0.identifierQuery = "AB12" }
        }
        await store.send(.rssiFilterToggled(true)) {
            $0.$criteria.withLock { $0.isRSSIFilterEnabled = true }
        }
        await store.send(.minimumRSSIChanged(-70)) {
            $0.$criteria.withLock { $0.minimumRSSI = -70 }
        }
    }

    @Test("resetTapped restores default criteria")
    func resetRestoresDefault() async {
        let store = TestStore(initialState: FilterFeature.State()) {
            FilterFeature()
        }

        await store.send(.nameFilterToggled(true)) {
            $0.$criteria.withLock { $0.isNameFilterEnabled = true }
        }
        await store.send(.resetTapped) {
            $0.$criteria.withLock { $0 = .default }
        }
    }
}
