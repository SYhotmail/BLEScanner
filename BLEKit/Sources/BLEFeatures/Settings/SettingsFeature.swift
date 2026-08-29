import BLEKitCore
import BLEKitDependencies
import BLEKitHardware
import ComposableArchitecture
import Foundation

@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.appSettings) public var settings: AppSettings = .default
        @Shared(.knownBeacons) public var knownBeacons: [KnownBeacon] = []
        public var locationAuthorizationStatus: LocationAuthorizationState = .notDetermined
        public var isScanPeriodPickerPresented = false
        @Presents public var addBeaconForm: AddKnownBeaconFeature.State?

        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case enhancedRangingToggled(Bool)
        case scanModeChanged(ScanMode)
        case scanPeriodChanged(TimeInterval)
        case sortOrderChanged(ScanSortOrder)
        case scanPeriodPickerTapped
        case scanPeriodPickerDismissed
        case authorizationEvent(BeaconRangingEvent)
        case addKnownBeaconTapped
        case addBeaconForm(PresentationAction<AddKnownBeaconFeature.Action>)
        case knownBeaconDeleted(IndexSet)
    }

    private enum CancelID: Hashable {
        case authorization
    }

    @Dependency(\.beaconRanging) var beaconRanging

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let beaconRanging = beaconRanging
                return .run { send in
                    for await event in beaconRanging.events() {
                        await send(.authorizationEvent(event))
                    }
                }
                .cancellable(id: CancelID.authorization)

            case let .enhancedRangingToggled(isOn):
                state.$settings.withLock { $0.isEnhancedRangingEnabled = isOn }
                guard isOn else { return .none }
                let beaconRanging = beaconRanging
                return .run { _ in beaconRanging.requestWhenInUseAuthorization() }

            case let .scanModeChanged(mode):
                state.$settings.withLock { $0.scanMode = mode }
                return .none

            case let .scanPeriodChanged(period):
                state.$settings.withLock { $0.scanPeriod = period }
                return .none

            case let .sortOrderChanged(order):
                state.$settings.withLock { $0.sortOrder = order }
                return .none

            case .scanPeriodPickerTapped:
                state.isScanPeriodPickerPresented = true
                return .none

            case .scanPeriodPickerDismissed:
                state.isScanPeriodPickerPresented = false
                return .none

            case let .authorizationEvent(.authorizationChanged(status)):
                state.locationAuthorizationStatus = status
                return .none

            case .authorizationEvent(.rangedBeacons):
                // Ranged results are consumed by ScannerFeature, which owns the active ranging effect.
                return .none

            case .addKnownBeaconTapped:
                state.addBeaconForm = AddKnownBeaconFeature.State()
                return .none

            case let .addBeaconForm(.presented(.delegate(.saved(beacon)))):
                if !state.knownBeacons.contains(where: { $0.uuid == beacon.uuid }) {
                    state.$knownBeacons.withLock { $0.append(beacon) }
                }
                state.addBeaconForm = nil
                return .none

            case .addBeaconForm(.presented(.delegate(.cancelled))):
                state.addBeaconForm = nil
                return .none

            case .addBeaconForm:
                return .none

            case let .knownBeaconDeleted(indexSet):
                state.$knownBeacons.withLock { $0.remove(atOffsets: indexSet) }
                return .none
            }
        }
        .ifLet(\.$addBeaconForm, action: \.addBeaconForm) {
            AddKnownBeaconFeature()
        }
    }
}
