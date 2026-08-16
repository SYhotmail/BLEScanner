import BLEKitCore
import ComposableArchitecture

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var sidebarSelection: SidebarDestination = .scanner
        public var scanner = ScannerFeature.State()
        public var filter = FilterFeature.State()
        public var settings = SettingsFeature.State()

        public init() {}
    }

    public enum Action: Equatable {
        case sidebarSelectionChanged(SidebarDestination)
        case scanner(ScannerFeature.Action)
        case filter(FilterFeature.Action)
        case settings(SettingsFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.scanner, action: \.scanner) {
            ScannerFeature()
        }
        Scope(state: \.filter, action: \.filter) {
            FilterFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case let .sidebarSelectionChanged(destination):
                state.sidebarSelection = destination
                return .none

            case .settings(.enhancedRangingToggled(true)):
                return .send(.scanner(.startRangingIfNeeded))

            case .settings(.enhancedRangingToggled(false)):
                return .send(.scanner(.stopRanging))

            case .scanner, .filter, .settings:
                return .none
            }
        }
    }
}
