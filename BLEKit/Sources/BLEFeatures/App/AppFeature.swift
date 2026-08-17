import BLEKitCore
import ComposableArchitecture

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var sidebarSelection: SidebarDestination = .scanner
        public var isSidebarOpen = false
        public var scanner = ScannerFeature.State()
        public var filter = FilterFeature.State()
        public var settings = SettingsFeature.State()

        public init() {}
    }

    public enum Action: Equatable {
        case sidebarSelectionChanged(SidebarDestination)
        case sidebarOpened
        case sidebarClosed
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
                // Selecting a destination closes the drawer in the same state mutation, rather
                // than relying on the view to separately dismiss it, so there's no window where
                // the two could be observed (or dropped) out of sync.
                state.sidebarSelection = destination
                state.isSidebarOpen = false
                return .none

            case .sidebarOpened:
                state.isSidebarOpen = true
                return .none

            case .sidebarClosed:
                state.isSidebarOpen = false
                return .none

            case .settings(.enhancedRangingToggled(true)):
                return .send(.scanner(.startRangingIfNeeded))

            case .settings(.enhancedRangingToggled(false)):
                return .send(.scanner(.stopRanging))

            case .filter:
                return .send(.scanner(.recomputeFilteredDevices))

            case .scanner, .settings:
                return .none
            }
        }
    }
}
