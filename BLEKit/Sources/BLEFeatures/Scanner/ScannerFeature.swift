import BLEKitCore
import BLEKitDependencies
import BLEKitHardware
import ComposableArchitecture
import Foundation

@Reducer
public struct ScannerFeature {
    @ObservableState
    public struct State: Equatable {
        public var tab: ScanTab = .nearby
        public var displayMode: ScanDisplayMode = .list
        public var devices: IdentifiedArrayOf<DiscoveredDevice> = []
        public var isScanning = false
        public var bluetoothState: BluetoothState = .unknown
        public var history = HistoryFeature.State()
        @Presents public var destination: DeviceDetailFeature.State?

        @Shared(.filterCriteria) public var filterCriteria: FilterCriteria = .default
        @Shared(.appSettings) public var settings: AppSettings = .default
        @Shared(.knownBeacons) public var knownBeacons: [KnownBeacon] = []

        /// Cached result of filtering/sorting `devices` by `filterCriteria`. Recomputed
        /// explicitly (via `recomputeFilteredSortedDevices()`) whenever either input changes,
        /// rather than on every read — `devices` can update many times a second while scanning,
        /// and this is read from SwiftUI view bodies, sometimes more than once per body
        /// evaluation.
        public internal(set) var filteredSortedDevices: IdentifiedArrayOf<DiscoveredDevice> = []

        public init() {}

        mutating func recomputeFilteredSortedDevices() {
            let filtered = devices.filter { DeviceFilter.matches($0, criteria: filterCriteria) }
            filteredSortedDevices = IdentifiedArray(uniqueElements: filtered.sorted { $0.rssi > $1.rssi })
        }
    }

    public enum Action: Equatable {
        case onAppear
        case onDisappear
        case scanToggleTapped
        case tabChanged(ScanTab)
        case displayModeToggled
        case scanEvent(BLEScanEvent)
        case beaconRangingEvent(BeaconRangingEvent)
        case rowTapped(DiscoveredDevice.ID)
        case connectTapped(DiscoveredDevice.ID)
        case trackBeaconTapped(BeaconReading)
        case startRangingIfNeeded
        case stopRanging
        case history(HistoryFeature.Action)
        case destination(PresentationAction<DeviceDetailFeature.Action>)
        case recomputeFilteredDevices
        case rescanTapped
    }

    private enum CancelID: Hashable {
        case scan
        case ranging
        case periodicRestart
        case recomputeDebounce
    }

    /// How long the scan stream must be quiet before the filtered/sorted list is rebuilt from
    /// a burst of advertisements. Keeps rapid-fire RSSI updates for several devices from
    /// re-sorting the list on every single one.
    private static let recomputeDebounceInterval: Duration = .milliseconds(300)

    @Dependency(\.bluetoothScanner) var bluetoothScanner
    @Dependency(\.beaconRanging) var beaconRanging
    @Dependency(\.history) var historyClient
    @Dependency(\.date.now) var now
    @Dependency(\.continuousClock) var clock

    public init() {}
    
    private static func recomputeFilteredSortedDevices(state: inout State) {
        state.recomputeFilteredSortedDevices()
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.history, action: \.history) {
            HistoryFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.displayMode = state.settings.defaultDisplayMode
                return .merge(
                    .send(.history(.onAppear)),
                    .send(.startRangingIfNeeded),
                    state.settings.scanMode == .periodic ? startScanning(into: &state) : .none
                )

            case .onDisappear:
                return .merge(stopScanning(into: &state), .cancel(id: CancelID.ranging))

            case .scanToggleTapped:
                guard state.settings.scanMode == .manual else { return .none }
                return state.isScanning ? stopScanning(into: &state) : startScanning(into: &state)

            case let .tabChanged(tab):
                state.tab = tab
                return .none

            case .displayModeToggled:
                state.displayMode = state.displayMode == .list ? .radar : .list
                return .none

            case let .scanEvent(.stateChanged(bluetoothState)):
                state.bluetoothState = bluetoothState
                return .none

            case let .scanEvent(.discovered(advertisement)):
                return upsert(advertisement: advertisement, into: &state)

            case let .beaconRangingEvent(.authorizationChanged(status)):
                // The authorization prompt/status itself is surfaced via SettingsFeature.
                _ = status
                return .none

            case let .beaconRangingEvent(.rangedBeacons(rangedBeacons)):
                apply(rangedBeacons: rangedBeacons, to: &state)
                return .none

            case let .rowTapped(id):
                guard let device = state.devices[id: id] else { return .none }
                state.destination = DeviceDetailFeature.State(device: device)
                return .none

            case let .connectTapped(id):
                guard let device = state.devices[id: id] else { return .none }
                state.destination = DeviceDetailFeature.State(device: device)
                return .run { send in
                    await send(.destination(.presented(.connectTapped)))
                }

            case let .trackBeaconTapped(beacon):
                if !state.knownBeacons.contains(where: { $0.uuid == beacon.uuid }) {
                    let label = "Beacon \(beacon.uuid.uuidString.prefix(8))"
                    state.$knownBeacons.withLock { $0.append(KnownBeacon(uuid: beacon.uuid, label: label, dateAdded: now)) }
                }
                return .send(.startRangingIfNeeded)

            case .startRangingIfNeeded:
                guard state.settings.isEnhancedRangingEnabled, !state.knownBeacons.isEmpty else {
                    return .none
                }
                let uuids = state.knownBeacons.map(\.uuid)
                let beaconRanging = beaconRanging
                return .run { send in
                    beaconRanging.startRanging(uuids)
                    for await event in beaconRanging.events() {
                        await send(.beaconRangingEvent(event))
                    }
                }
                .cancellable(id: CancelID.ranging, cancelInFlight: true)

            case .stopRanging:
                let beaconRanging = beaconRanging
                return .merge(
                    .run { _ in beaconRanging.stopAllRanging() },
                    .cancel(id: CancelID.ranging)
                )

            case .history:
                return .none

            case .destination:
                return .none

            case .recomputeFilteredDevices:
                Self.recomputeFilteredSortedDevices(state: &state)
                return .none

            case .rescanTapped:
                guard state.isScanning else { return .none }
                return rescanEffect(into: &state)
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            DeviceDetailFeature()
        }
    }

    private func startScanning(into state: inout State) -> Effect<Action> {
        state.isScanning = true
        let bluetoothScanner = bluetoothScanner
        var effects: [Effect<Action>] = [
            .run { send in
                for await event in bluetoothScanner.scanEvents() {
                    await send(.scanEvent(event))
                }
            }
            .cancellable(id: CancelID.scan),
            .run { _ in bluetoothScanner.startScanning() },
        ]
        if state.settings.scanMode == .periodic {
            effects.append(periodicRestartEffect(period: state.settings.scanPeriod))
        }
        return .merge(effects)
    }

    private func stopScanning(into state: inout State) -> Effect<Action> {
        state.isScanning = false
        let bluetoothScanner = bluetoothScanner
        return .merge(
            .run { _ in bluetoothScanner.stopScanning() },
            .cancel(id: CancelID.scan),
            .cancel(id: CancelID.periodicRestart),
            //.cancel(id: CancelID.recomputeDebounce)
        )
    }

    /// Some peripherals (and BLE stacks on other platforms) only report a connectable device
    /// once per continuous scan session. Restarting the underlying CoreBluetooth scan forces a
    /// fresh advertisement (and RSSI) from those devices — but only once the scan has actually
    /// gone quiet for `period`, rather than on a fixed schedule regardless of activity. Every
    /// call site (the initial seed in `startScanning`, and each advertisement in `upsert`) uses
    /// `cancelInFlight: true`, so a live device continuously advertising keeps cancelling and
    /// re-seeding this wait indefinitely and the restart never actually fires while it's active.
    private func periodicRestartEffect(period: TimeInterval) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        let clock = clock
        return .run { _ in
            for await _ in clock.timer(interval: .seconds(period)) {
                bluetoothScanner.stopScanning()
                bluetoothScanner.startScanning()
            }
        }
        .cancellable(id: CancelID.periodicRestart, cancelInFlight: true)
    }

    /// User-triggered rescan (e.g. pull-to-refresh): immediately stops and restarts the
    /// underlying CoreBluetooth scan, the same action `periodicRestartEffect` performs on its
    /// own once quiet. In `.periodic` mode this also re-seeds that quiet timer, since the scan
    /// was just restarted here.
    private func rescanEffect(into state: inout State) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        var effects: [Effect<Action>] = [
            .run { _ in
                bluetoothScanner.stopScanning()
                bluetoothScanner.startScanning()
            }
        ]
        if state.settings.scanMode == .periodic {
            effects.append(periodicRestartEffect(period: state.settings.scanPeriod))
        }
        return .merge(effects)
    }

    /// Rebuilds the filtered/sorted list once the scan stream has been quiet for
    /// `recomputeDebounceInterval`. Cancelled and restarted (`cancelInFlight: true`) by every
    /// call site, so a burst of advertisements collapses into a single recompute after the
    /// burst ends rather than one recompute per advertisement.
    private func recomputeDebounceEffect() -> Effect<Action> {
        let clock = clock
        return .run { send in
            try? await clock.sleep(for: Self.recomputeDebounceInterval)
            await send(.recomputeFilteredDevices)
        }
        .cancellable(id: CancelID.recomputeDebounce, cancelInFlight: true)
    }

    private func upsert(advertisement: BLEAdvertisement, into state: inout State) -> Effect<Action> {
        let beacon = advertisement.manufacturerData.flatMap(AppleBeaconParser.parse(manufacturerData:))

        var device = state.devices[id: advertisement.identifier] ?? DiscoveredDevice(
            identifier: advertisement.identifier,
            name: advertisement.name,
            rssi: advertisement.rssi,
            lastSeenDate: advertisement.timestamp,
            isConnectable: advertisement.isConnectable,
            advertisedServiceIdentifiers: advertisement.serviceIdentifiers,
            txPowerLevel: advertisement.txPowerLevel,
            beacon: beacon
        )
        device.name = advertisement.name ?? device.name
        device.rssi = advertisement.rssi
        device.lastSeenDate = advertisement.timestamp
        device.isConnectable = advertisement.isConnectable
        device.advertisedServiceIdentifiers = advertisement.serviceIdentifiers
        device.txPowerLevel = advertisement.txPowerLevel ?? device.txPowerLevel
        if let beacon {
            device.beacon = beacon
        }
        state.devices[id: device.id] = device

        let dto = HistoryRecordDTO(
            identifier: device.identifier.uuidString,
            name: device.name,
            lastRSSI: device.rssi,
            lastSeenDate: device.lastSeenDate,
            firstSeenDate: device.firstSeenDate
        )
        state.history.records[id: dto.id] = dto

        let historyClient = historyClient
        var effects: [Effect<Action>] = [
            .send(.history(.recordUpserted(dto))),
            .run { _ in try? await historyClient.upsert(dto) },
            recomputeDebounceEffect(),
        ]
        if state.settings.scanMode == .periodic {
            effects.append(periodicRestartEffect(period: state.settings.scanPeriod))
        }
        return .merge(effects)
    }

    private func apply(rangedBeacons: [RangedBeacon], to state: inout State) {
        var didUpdateDevices = false
        for ranged in rangedBeacons {
            for var device in state.devices where device.beacon?.uuid == ranged.uuid {
                device.beacon?.rangedProximity = ranged.proximity
                state.devices[id: device.id] = device
                didUpdateDevices = true
            }
        }
        if didUpdateDevices {
            Self.recomputeFilteredSortedDevices(state: &state)
        }
    }
}
