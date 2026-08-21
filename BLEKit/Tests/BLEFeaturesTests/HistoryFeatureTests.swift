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

    @Test("deleteButtonTapped removes the record via the history client")
    func deleteButtonTappedRemovesRecord() async {
        let inMemory = InMemoryHistoryClient(seed: HistoryRecordFixtures.all)
        let store = TestStore(initialState: HistoryFeature.State(records: IdentifiedArray(uniqueElements: HistoryRecordFixtures.all))) {
            HistoryFeature()
        } withDependencies: {
            $0.history = inMemory.client
        }

        await store.send(.deleteButtonTapped(HistoryRecordFixtures.older.id))
        await store.receive(\.recordDeleted) {
            $0.records.remove(id: HistoryRecordFixtures.older.id)
        }

        let remaining = await inMemory.fetchAll()
        #expect(remaining.map(\.id) == [HistoryRecordFixtures.recent.id])
    }

    @Test("a delete failure leaves the record in state")
    func deleteFailureLeavesRecordInState() async {
        struct DeleteError: Error {}
        let store = TestStore(initialState: HistoryFeature.State(records: [HistoryRecordFixtures.older])) {
            HistoryFeature()
        } withDependencies: {
            $0.history.delete = { _ in throw DeleteError() }
        }

        await store.send(.deleteButtonTapped(HistoryRecordFixtures.older.id))
        await store.receive(\.deleteFailed)
    }

    @Test("eraseAllButtonTapped clears every record via the history client")
    func eraseAllButtonTappedClearsRecords() async {
        let inMemory = InMemoryHistoryClient(seed: HistoryRecordFixtures.all)
        let store = TestStore(initialState: HistoryFeature.State(records: IdentifiedArray(uniqueElements: HistoryRecordFixtures.all))) {
            HistoryFeature()
        } withDependencies: {
            $0.history = inMemory.client
        }

        await store.send(.eraseAllButtonTapped)
        await store.receive(\.allRecordsErased) {
            $0.records = []
        }

        let remaining = await inMemory.fetchAll()
        #expect(remaining.isEmpty)
    }

    @Test("an erase-all failure leaves existing records in state")
    func eraseAllFailureLeavesRecordsInState() async {
        struct EraseError: Error {}
        let store = TestStore(initialState: HistoryFeature.State(records: [HistoryRecordFixtures.older])) {
            HistoryFeature()
        } withDependencies: {
            $0.history.deleteAll = { throw EraseError() }
        }

        await store.send(.eraseAllButtonTapped)
        await store.receive(\.eraseAllFailed)
    }
}
