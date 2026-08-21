import BLEKitCore
import BLEKitDependencies
import ComposableArchitecture
import Foundation

@Reducer
public struct HistoryFeature {
    @ObservableState
    public struct State: Equatable {
        public var records: IdentifiedArrayOf<HistoryRecordDTO> = []
        public var isLoading = false

        public init(records: IdentifiedArrayOf<HistoryRecordDTO> = [], isLoading: Bool = false) {
            self.records = records
            self.isLoading = isLoading
        }
    }

    public enum Action: Equatable {
        case onAppear
        case recordsLoaded([HistoryRecordDTO])
        case loadFailed(String)
        case recordUpserted(HistoryRecordDTO)
        case deleteButtonTapped(HistoryRecordDTO.ID)
        case recordDeleted(String)
        case deleteFailed(String)
        case eraseAllButtonTapped
        case allRecordsErased
        case eraseAllFailed(String)
    }

    @Dependency(\.history) var history

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                let history = history
                return .run { send in
                    do {
                        let records = try await history.fetchAll()
                        await send(.recordsLoaded(records))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .recordsLoaded(records):
                state.isLoading = false
                state.records = IdentifiedArray(uniqueElements: records)
                return .none

            case .loadFailed:
                state.isLoading = false
                return .none

            case let .recordUpserted(record):
                state.records[id: record.id] = record
                return .none

            case let .deleteButtonTapped(id):
                guard let identifier = state.records[id: id]?.identifier else { return .none }
                let history = history
                return .run { send in
                    do {
                        try await history.delete(identifier)
                        await send(.recordDeleted(identifier))
                    } catch {
                        await send(.deleteFailed(error.localizedDescription))
                    }
                }

            case let .recordDeleted(identifier):
                state.records.remove(id: identifier)
                return .none

            case .deleteFailed:
                return .none

            case .eraseAllButtonTapped:
                let history = history
                return .run { send in
                    do {
                        try await history.deleteAll()
                        await send(.allRecordsErased)
                    } catch {
                        await send(.eraseAllFailed(error.localizedDescription))
                    }
                }

            case .allRecordsErased:
                state.records.removeAll()
                return .none

            case .eraseAllFailed:
                return .none
            }
        }
    }
}
