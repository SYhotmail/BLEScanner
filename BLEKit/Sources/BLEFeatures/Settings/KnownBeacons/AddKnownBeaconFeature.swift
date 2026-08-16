import BLEKitCore
import ComposableArchitecture
import Foundation

@Reducer
public struct AddKnownBeaconFeature {
    @ObservableState
    public struct State: Equatable {
        public var uuidText: String
        public var label: String
        public var validationError: String?

        public init(uuidText: String = "", label: String = "") {
            self.uuidText = uuidText
            self.label = label
        }
    }

    public enum Action: Equatable {
        case uuidChanged(String)
        case labelChanged(String)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case saved(KnownBeacon)
            case cancelled
        }
    }

    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .uuidChanged(text):
                state.uuidText = text
                state.validationError = nil
                return .none

            case let .labelChanged(text):
                state.label = text
                return .none

            case .saveTapped:
                guard let uuid = UUID(uuidString: state.uuidText) else {
                    state.validationError = "Enter a valid UUID."
                    return .none
                }
                let label = state.label.isEmpty ? uuid.uuidString : state.label
                let beacon = KnownBeacon(uuid: uuid, label: label, dateAdded: now)
                return .run { send in
                    await send(.delegate(.saved(beacon)))
                }

            case .cancelTapped:
                return .run { send in
                    await send(.delegate(.cancelled))
                }

            case .delegate:
                return .none
            }
        }
    }
}
