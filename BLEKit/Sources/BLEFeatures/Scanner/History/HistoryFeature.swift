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
            }
        }
    }
}
