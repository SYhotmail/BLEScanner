import BLEKitCore
import BLEKitTestSupport
import ComposableArchitecture
import Testing
@testable import BLEFeatures

@MainActor
@Suite("HistoryFeature")
struct HistoryFeatureTests {
    @Test("onAppear loads records from the history client")
    func onAppearLoadsRecords() async {
        let inMemory = InMemoryHistoryClient(seed: HistoryRecordFixtures.all)
        let store = TestStore(initialState: HistoryFeature.State()) {
            HistoryFeature()
        } withDependencies: {
            $0.history = inMemory.client
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.recordsLoaded) {
            $0.isLoading = false
            $0.records = IdentifiedArray(uniqueElements: HistoryRecordFixtures.all)
        }
    }

    @Test("a load failure clears the loading flag without populating records")
    func loadFailureClearsLoadingFlag() async {
        struct LoadError: Error {}
        let store = TestStore(initialState: HistoryFeature.State()) {
            HistoryFeature()
        } withDependencies: {
            $0.history.fetchAll = { throw LoadError() }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.loadFailed) {
            $0.isLoading = false
        }
    }

    @Test("recordUpserted inserts or updates a record in place")
    func recordUpsertedUpdatesInPlace() async {
        let store = TestStore(initialState: HistoryFeature.State(records: [HistoryRecordFixtures.older])) {
            HistoryFeature()
        }

        var updated = HistoryRecordFixtures.older
        updated.lastRSSI = -30
        await store.send(.recordUpserted(updated)) {
            $0.records[id: updated.id] = updated
        }
    }
}
