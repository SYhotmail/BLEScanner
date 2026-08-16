import BLEKitCore
import BLEKitDependencies
import ComposableArchitecture

@Reducer
public struct FilterFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.filterCriteria) public var criteria: FilterCriteria = .default

        public init() {}
    }

    public enum Action: Equatable {
        case nameFilterToggled(Bool)
        case nameQueryChanged(String)
        case identifierFilterToggled(Bool)
        case identifierQueryChanged(String)
        case rssiFilterToggled(Bool)
        case minimumRSSIChanged(Int)
        case resetTapped
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameFilterToggled(isOn):
                state.$criteria.withLock { $0.isNameFilterEnabled = isOn }
            case let .nameQueryChanged(query):
                state.$criteria.withLock { $0.nameQuery = query }
            case let .identifierFilterToggled(isOn):
                state.$criteria.withLock { $0.isIdentifierFilterEnabled = isOn }
            case let .identifierQueryChanged(query):
                state.$criteria.withLock { $0.identifierQuery = query }
            case let .rssiFilterToggled(isOn):
                state.$criteria.withLock { $0.isRSSIFilterEnabled = isOn }
            case let .minimumRSSIChanged(value):
                state.$criteria.withLock { $0.minimumRSSI = value }
            case .resetTapped:
                state.$criteria.withLock { $0 = .default }
            }
            return .none
        }
    }
}
