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
        /// Seeded from `settings.defaultDisplayMode` once, in `init()` — not re-applied on every
        /// `.onAppear`, since that fires again whenever this screen reappears after a pushed
        /// `DeviceDetailFeature` is popped, which would otherwise stomp a mode the user had
        /// manually toggled to (e.g. Radar) back to the settings default.
        public var displayMode: ScanDisplayMode = .list
        public var devices: IdentifiedArrayOf<DiscoveredDevice> = []
        public var isScanning = false
        public var bluetoothState: BluetoothState = .unknown
        /// Whether Manual mode's launch-time auto-start (see `.onAppear`) has already fired.
        /// Manual mode starts scanning automatically the first time the Scanner screen appears,
        /// same as Periodic mode's "starts as soon as you open the Scanner screen" — but only
        /// once: a later `.onAppear` (the screen reappearing after Settings, or a popped
        /// `DeviceDetailFeature`) must not override the user's own subsequent start/stop control
        /// via `scanToggleTapped`. Irrelevant for Periodic mode, which always (re)starts on
        /// every `.onAppear` regardless.
        public var hasAutoStartedInitialManualScan = false
        public var history = HistoryFeature.State()
        @Presents public var destination: DeviceDetailFeature.State?
        /// Snapshot of the device shown in the "Raw Advertisement Data" sheet, opened from a
        /// non-connectable row's context menu. Not a `@Presents` child feature since the sheet
        /// is a static read-only display with no reducer logic of its own.
        public var rawAdvertisementDataDevice: DiscoveredDevice?
        /// Snapshot of the device shown in the "RSSI Chart" overlay, opened from any row's
        /// Chart button. Not a `@Presents` child feature for the same reason as
        /// `rawAdvertisementDataDevice` above.
        public var rssiChartDevice: DiscoveredDevice?
        /// Timestamped RSSI samples accumulated per device while scanning, powering the RSSI
        /// chart. In-memory/session-only — cleared on relaunch, not persisted — and capped per
        /// device at `ScannerFeature.maxRSSISamplesPerDevice` to bound memory during long scans.
        public var rssiHistoryByDevice: [DiscoveredDevice.ID: [RSSISample]] = [:]
        /// Device whose advertisement text was most recently copied to the pasteboard, kept
        /// around only long enough to drive a "Copied" toast; cleared by `copyFeedbackTimedOut`.
        public var copyFeedbackDeviceID: DiscoveredDevice.ID?

        @Shared(.filterCriteria) public var filterCriteria: FilterCriteria = .default
        @Shared(.appSettings) public var settings: AppSettings = .default
        @Shared(.knownBeacons) public var knownBeacons: [KnownBeacon] = []
        @Shared(.favoriteDeviceIdentifiers) public var favoriteDeviceIdentifiers: Set<UUID> = []

        /// Cached result of filtering/sorting `devices` by `filterCriteria`. Recomputed
        /// explicitly whenever either input changes, rather than on every read — `devices` can
        /// update many times a second while scanning, and this is read from SwiftUI view
        /// bodies, sometimes more than once per body evaluation. The filter/sort work itself
        /// runs off the main actor (see `recomputeFilteredSortedDevicesEffect`); only the
        /// resulting assignment happens on `main`, via `.filteredSortedDevicesComputed`.
        public internal(set) var filteredSortedDevices: IdentifiedArrayOf<DiscoveredDevice> = []

        /// Currently-visible devices the user has starred, sorted by RSSI. Recomputed alongside
        /// `filteredSortedDevices` — a device only appears here while it's also present in
        /// `devices` (i.e. currently in range), the same "kept" semantics as `filteredSortedDevices`.
        /// `favoriteDeviceIdentifiers` itself is what actually persists the starring across scans.
        public internal(set) var favoriteSortedDevices: IdentifiedArrayOf<DiscoveredDevice> = []

        public init() {
            displayMode = settings.defaultDisplayMode
        }

        mutating func recomputeFilteredSortedDevices() {
            let filtered = devices.filter { DeviceFilter.matches($0, criteria: filterCriteria) }
            filteredSortedDevices = IdentifiedArray(uniqueElements: filtered.sorted { $0.rssi > $1.rssi })
            let favorites = devices.filter { favoriteDeviceIdentifiers.contains($0.id) }
            favoriteSortedDevices = IdentifiedArray(uniqueElements: favorites.sorted { $0.rssi > $1.rssi })
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
        case favoriteToggled(DiscoveredDevice.ID)
        case trackBeaconTapped(BeaconReading)
        case rawAdvertisementDataTapped(DiscoveredDevice.ID)
        case rawAdvertisementDataDismissed
        case rawAdvertisementDataCopyTapped(DiscoveredDevice.ID)
        case rssiChartTapped(DiscoveredDevice.ID)
        case rssiChartDismissed
        case copyFeedbackTimedOut(DiscoveredDevice.ID)
        case startRangingIfNeeded
        case stopRanging
        case history(HistoryFeature.Action)
        case destination(PresentationAction<DeviceDetailFeature.Action>)
        case recomputeFilteredDevices
        case filteredSortedDevicesComputed(filtered: IdentifiedArrayOf<DiscoveredDevice>, favorites: IdentifiedArrayOf<DiscoveredDevice>)
        case rescanTapped
    }

    private enum CancelID: Hashable {
        case scan
        case ranging
        case restart
        case recomputeDebounce
        case recompute
        case copyFeedback
    }

    /// How long the "Copied" toast stays up before `copyFeedbackDeviceID` is cleared.
    private static let copyFeedbackDuration: Duration = .seconds(2)

    /// Upper bound on `State.rssiHistoryByDevice` entries per device, so a device left in the
    /// scan list for a long session doesn't grow its RSSI history unboundedly. Oldest samples
    /// are dropped first once the cap is reached.
    private static let maxRSSISamplesPerDevice = 500

    /// Continuous (`.periodic`) scan mode's quiet-restart throttle — fixed, unlike Manual
    /// mode's restart interval, which is the user-configurable `settings.scanPeriod`.
    private static let continuousScanRestartThrottle: TimeInterval = 5

    /// How long the scan stream must be quiet before the filtered/sorted list is rebuilt from
    /// a burst of advertisements. Keeps rapid-fire RSSI updates for several devices from
    /// re-sorting the list on every single one.
    private static let recomputeDebounceInterval: Duration = .milliseconds(300)

    @Dependency(\.bluetoothScanner) var bluetoothScanner
    @Dependency(\.beaconRanging) var beaconRanging
    @Dependency(\.history) var historyClient
    @Dependency(\.pasteboard) var pasteboard
    @Dependency(\.date.now) var now
    @Dependency(\.continuousClock) var clock

    public init() {}
    
    /// Kicks off the filter/sort of `devices` on a background task; the reducer only ever
    /// assigns the result (via `.filteredSortedDevicesComputed`) on the main actor. Cancels any
    /// still-running recompute so an in-flight result from stale `devices`/`filterCriteria`
    /// can't clobber one started after it.
    private func recomputeFilteredSortedDevicesEffect(
        devices: IdentifiedArrayOf<DiscoveredDevice>,
        filterCriteria: FilterCriteria,
        favoriteDeviceIdentifiers: Set<UUID>
    ) -> Effect<Action> {
        .run { send in
            let filtered = devices.filter { DeviceFilter.matches($0, criteria: filterCriteria) }
            let filteredSorted = IdentifiedArray(uniqueElements: filtered.sorted { $0.rssi > $1.rssi })
            let favorites = devices.filter { favoriteDeviceIdentifiers.contains($0.id) }
            let favoritesSorted = IdentifiedArray(uniqueElements: favorites.sorted { $0.rssi > $1.rssi })
            await send(.filteredSortedDevicesComputed(filtered: filteredSorted, favorites: favoritesSorted))
        }
        .cancellable(id: CancelID.recompute, cancelInFlight: true)
    }
    
    private func recomputeFilteredSortedDevicesEffect(state: State) -> Effect<Action> {
        recomputeFilteredSortedDevicesEffect(
            devices: state.devices,
            filterCriteria: state.filterCriteria,
            favoriteDeviceIdentifiers: state.favoriteDeviceIdentifiers
        )
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.history, action: \.history) {
            HistoryFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                let shouldAutoStartManualScan = state.settings.scanMode == .manual && !state.hasAutoStartedInitialManualScan
                if shouldAutoStartManualScan {
                    state.hasAutoStartedInitialManualScan = true
                }
                let shouldStartScanning = state.settings.scanMode == .periodic || shouldAutoStartManualScan
                return .merge(
                    .send(.history(.onAppear)),
                    .send(.startRangingIfNeeded),
                    shouldStartScanning ? startScanning(into: &state) : .none
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
                guard apply(rangedBeacons: rangedBeacons, to: &state) else { return .none }
                return recomputeFilteredSortedDevicesEffect(state: state)
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

            case let .favoriteToggled(id):
                guard let device = state.devices[id: id], device.isConnectable else { return .none }
                if state.favoriteDeviceIdentifiers.contains(id) {
                    state.$favoriteDeviceIdentifiers.withLock { _ = $0.remove(id) }
                } else {
                    state.$favoriteDeviceIdentifiers.withLock { _ = $0.insert(id) }
                }
                return recomputeFilteredSortedDevicesEffect(state: state)
            case let .trackBeaconTapped(beacon):
                if !state.knownBeacons.contains(where: { $0.uuid == beacon.uuid }) {
                    let label = "Beacon \(beacon.uuid.uuidString.prefix(8))"
                    state.$knownBeacons.withLock { $0.append(KnownBeacon(uuid: beacon.uuid, label: label, dateAdded: now)) }
                }
                return .send(.startRangingIfNeeded)

            case let .rawAdvertisementDataTapped(id):
                state.rssiChartDevice = nil
                state.rawAdvertisementDataDevice = state.devices[id: id]
                return .none

            case .rawAdvertisementDataDismissed:
                state.rawAdvertisementDataDevice = nil
                return .none

            case let .rssiChartTapped(id):
                state.rawAdvertisementDataDevice = nil
                state.rssiChartDevice = state.devices[id: id]
                return .none

            case .rssiChartDismissed:
                state.rssiChartDevice = nil
                return .none

            case let .rawAdvertisementDataCopyTapped(id):
                guard let device = state.devices[id: id] else { return .none }
                state.copyFeedbackDeviceID = id
                let pasteboard = pasteboard
                let clock = clock
                let text = RawAdvertisementDataBuilder.plainTextDescription(for: device)
                return .run { send in
                    pasteboard.setString(text)
                    try? await clock.sleep(for: Self.copyFeedbackDuration)
                    await send(.copyFeedbackTimedOut(id))
                }
                .cancellable(id: CancelID.copyFeedback, cancelInFlight: true)

            case let .copyFeedbackTimedOut(id):
                if state.copyFeedbackDeviceID == id {
                    state.copyFeedbackDeviceID = nil
                }
                return .none

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

            // Disconnecting on leaving the detail screen is handled here, in the parent, rather
            // than via the child's own `.onDisappear`: this `Reduce` runs before `.ifLet` nils
            // `state.destination` on dismissal, so `state.destination` is still populated here —
            // whereas a `.send` from the child view's `.onDisappear` races with that nilling
            // (dismissal can be triggered by the system, e.g. a swipe-back or the back button,
            // independent of the view's own teardown timing) and was hitting TCA's "received a
            // presentation action when destination state was absent" runtime warning.
            case .destination(.dismiss):
                guard let identifier = state.destination?.device.identifier else { return .none }
                let bluetoothScanner = bluetoothScanner
                return .run { _ in bluetoothScanner.disconnect(identifier: identifier) }

            case .destination:
                return .none

            case .recomputeFilteredDevices:
                return recomputeFilteredSortedDevicesEffect(state: state)
            case let .filteredSortedDevicesComputed(filtered, favorites):
                state.filteredSortedDevices = filtered
                state.favoriteSortedDevices = favorites
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
        let options = scanOptions(for: state)
        return .merge(
            .run { send in
                for await event in bluetoothScanner.scanEvents() {
                    await send(.scanEvent(event))
                }
            }
            .cancellable(id: CancelID.scan),
            .run { _ in bluetoothScanner.startScanning(allowDuplicates: options.allowDuplicates) },
            restartEffect(options)
        )
    }

    private func stopScanning(into state: inout State) -> Effect<Action> {
        state.isScanning = false
        let bluetoothScanner = bluetoothScanner
        return .merge(
            .run { _ in bluetoothScanner.stopScanning() },
            .cancel(id: CancelID.scan),
            .cancel(id: CancelID.restart),
            .cancel(id: CancelID.recomputeDebounce)
        )
    }

    /// Continuous (`.periodic`) mode scans with `allowDuplicates: true` and restarts on a fixed
    /// `continuousScanRestartThrottle` quiet timer; Manual mode scans with
    /// `allowDuplicates: false` and restarts on the user-configurable `settings.scanPeriod`.
    private func scanOptions(for state: State) -> (allowDuplicates: Bool, restartInterval: TimeInterval) {
        state.settings.scanMode == .periodic
            ? (allowDuplicates: true, restartInterval: Self.continuousScanRestartThrottle)
            : (allowDuplicates: false, restartInterval: state.settings.scanPeriod)
    }

    /// Some peripherals (and BLE stacks on other platforms) only report a connectable device
    /// once per continuous scan session. Restarting the underlying CoreBluetooth scan forces a
    /// fresh advertisement (and RSSI) from those devices — but only once the scan has actually
    /// gone quiet for `options.restartInterval`, rather than on a fixed schedule regardless of
    /// activity. Every call site (the initial seed in `startScanning`, and each advertisement in
    /// `upsert`) uses `cancelInFlight: true`, so a live device continuously advertising keeps
    /// cancelling and re-seeding this wait indefinitely and the restart never actually fires
    /// while it's active.
    private func restartEffect(_ options: (allowDuplicates: Bool, restartInterval: TimeInterval)) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        let clock = clock
        return .run { _ in
            for await _ in clock.timer(interval: .seconds(options.restartInterval)) {
                bluetoothScanner.stopScanning()
                bluetoothScanner.startScanning(allowDuplicates: options.allowDuplicates)
            }
        }
        .cancellable(id: CancelID.restart, cancelInFlight: true)
    }

    /// User-triggered rescan (e.g. pull-to-refresh): immediately stops and restarts the
    /// underlying CoreBluetooth scan, the same action `restartEffect` performs on its own once
    /// quiet, and re-seeds that quiet timer since the scan was just restarted here.
    private func rescanEffect(into state: inout State) -> Effect<Action> {
        let bluetoothScanner = bluetoothScanner
        let options = scanOptions(for: state)
        return .merge(
            .run { _ in
                bluetoothScanner.stopScanning()
                bluetoothScanner.startScanning(allowDuplicates: options.allowDuplicates)
            },
            restartEffect(options)
        )
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
        let manufacturer = advertisement.manufacturerData.flatMap(Manufacturer.parse(manufacturerData:))

        var device = state.devices[id: advertisement.identifier] ?? DiscoveredDevice(
            identifier: advertisement.identifier,
            name: advertisement.name,
            rssi: advertisement.rssi,
            lastSeenDate: advertisement.timestamp,
            isConnectable: advertisement.isConnectable,
            advertisedServiceIdentifiers: advertisement.serviceIdentifiers,
            txPowerLevel: advertisement.txPowerLevel,
            beacon: beacon,
            manufacturer: manufacturer,
            manufacturerData: advertisement.manufacturerData
        )
        device.name = advertisement.name ?? device.name
        device.rssi = advertisement.rssi
        device.lastSeenDate = advertisement.timestamp
        device.isConnectable = advertisement.isConnectable
        device.advertisedServiceIdentifiers = advertisement.serviceIdentifiers
        device.txPowerLevel = advertisement.txPowerLevel ?? device.txPowerLevel
        device.manufacturerData = advertisement.manufacturerData ?? device.manufacturerData
        
        if let beacon {
            device.beacon = beacon
        }
        if let manufacturer {
            device.manufacturer = manufacturer
        }
        state.devices[id: device.id] = device
        if state.rawAdvertisementDataDevice?.id == device.id {
            state.rawAdvertisementDataDevice = device
        }
        if state.rssiChartDevice?.id == device.id {
            state.rssiChartDevice = device
        }

        var samples = state.rssiHistoryByDevice[device.id, default: []]
        samples.append(RSSISample(date: advertisement.timestamp, rssi: advertisement.rssi))
        if samples.count > Self.maxRSSISamplesPerDevice {
            samples.removeFirst(samples.count - Self.maxRSSISamplesPerDevice)
        }
        state.rssiHistoryByDevice[device.id] = samples

        let dto = HistoryRecordDTO(
            identifier: device.identifier.uuidString,
            name: device.name,
            lastRSSI: device.rssi,
            lastSeenDate: device.lastSeenDate,
            firstSeenDate: device.firstSeenDate
        )
        state.history.records[id: dto.id] = dto

        let historyClient = historyClient
        return .merge(
            .send(.history(.recordUpserted(dto))),
            .run { _ in try? await historyClient.upsert(dto) },
            recomputeDebounceEffect(),
            restartEffect(scanOptions(for: state))
        )
    }

    @discardableResult
    private func apply(rangedBeacons: [RangedBeacon], to state: inout State) -> Bool {
        var didUpdateDevices = false
        for ranged in rangedBeacons {
            for var device in state.devices where device.beacon?.uuid == ranged.uuid {
                device.beacon?.rangedProximity = ranged.proximity
                state.devices[id: device.id] = device
                didUpdateDevices = true
            }
        }
        return didUpdateDevices
    }
}
