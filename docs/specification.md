# BLEScanner — Product Specification

## 1. Product summary

BLEScanner is a native iOS and iPadOS app for discovering, inspecting, and interacting with nearby Bluetooth Low Energy (BLE) devices, including iBeacons. It is a central-role (client) app: it scans, connects, and reads/writes GATT data — it does not advertise or act as a peripheral.

The app is loosely modeled on the UX of an existing Android app ("BLE Scanner" by Bluepixel Technologies), whose reference screenshots are kept in `android_images/` at the repository root, adapted to iOS platform capabilities and idioms (see §11 for deliberate deviations).

## 2. Platform and device support

- Native iOS and iPadOS app.
- Minimum OS: iOS 18.
- Supports iPhone (compact width) and iPad (regular width) with a single adaptive UI.
- Uses CoreBluetooth for scanning, connecting, and GATT interaction.
- Uses CoreLocation, opt-in only, for enhanced iBeacon ranging.
- Uses SwiftData for on-device persistence of scan history.

## 3. Product principles / non-goals

- The app is a BLE **client** only. Advertising as a peripheral, Eddystone frame configuration, and hosting a custom GATT server are explicitly **out of scope for v1**.
- No "bonded"/pairing status is shown — iOS does not expose a queryable BLE bond state to apps.
- History and Favorites are simplified relative to the Android reference: v1 has a single persisted "History" of previously seen devices (no separate Favorites feature).
- Filtering and Settings are reachable as first-class sidebar destinations, not buried in a hamburger menu with unrelated app-info links (About, FAQ, social links, etc. from the reference app are omitted).

## 4. Main experience — Scanner

The Scanner is the app's default/home screen, reachable from the sidebar (see §10).

It has two tabs, presented as a segmented control:

- **Near By** (default): the live, currently-scanning view. Devices appear as CoreBluetooth discovers their advertisements and disappear if not re-advertised within a timeout window. Two display modes, toggled from the toolbar:
  - **List**: devices sorted by signal power (RSSI, strongest first). Each row shows a color-coded RSSI badge, device name (or "Unknown"), a short identifier, and an iBeacon badge when applicable.
  - **Radar**: devices are plotted into concentric proximity rings — Immediate / Near / Far / Unknown — based on estimated distance (see §5).
- **History**: a SwiftData-backed list of every device ever scanned by this app installation, independent of whether it is currently in range. Shows name, identifier, last-seen RSSI, and last-seen timestamp. Populated incrementally as new devices are discovered during live scanning; does not require an active scan to browse.

Tapping any device row (in either tab) opens the Device Detail screen (§6).

## 5. Proximity and iBeacon detection

Two complementary mechanisms, combined:

1. **Always-on advertisement parsing.** Every CoreBluetooth advertisement is inspected for Apple's iBeacon manufacturer-data format (company ID `0x004C`, type `0x02`, length `0x15`). When present, the app extracts the beacon's UUID, Major, Minor, and calibrated Tx power, and estimates distance from the current RSSI and Tx power using a standard log-distance path-loss model. This requires no permission beyond Bluetooth and applies to every discovered iBeacon.
2. **Enhanced ranging (opt-in).** From Settings, the user may enable "Enhanced Beacon Ranging." When on, the app requests CoreLocation "When In Use" authorization and uses `CLBeaconRegion`/`CLBeaconIdentityCondition` ranging for beacon UUIDs the user has explicitly registered as "Known Beacons" (§9). This yields Apple's standard Immediate/Near/Far accuracy classification, which supersedes the RSSI-heuristic bucket for just those matched devices in the Radar view. It is off by default and never blocks the core scanning experience — unregistered or non-enabled beacons continue to use the RSSI heuristic.

## 6. Device connection and GATT explorer

Selecting a device opens its detail screen:

- **Connection lifecycle**: Connect / Disconnect action with visible status (Disconnected, Connecting, Connected, Failed).
- **GATT tree**: once connected, services and their characteristics are discovered and displayed as an expandable tree. Each characteristic shows capability badges — Read, Write, Notify (Notify also covers Indicate; both are exposed as a single "subscribe" affordance, matching CoreBluetooth's unified `setNotifyValue` API).

## 7. Characteristic interaction

For any characteristic with the relevant capability:

- **Read**: triggers a read and displays the latest value both as a hex string and as an attempted UTF-8 decode.
- **Write**: a segmented control lets the user choose the input format — **Text (UTF-8)** or **Hex byte array** (e.g. `0A1F3C`) — with inline validation (rejecting malformed hex before attempting a write).
- **Notify**: a toggle subscribes/unsubscribes to value change notifications; while subscribed, incoming values update live.

## 8. Filtering

Reachable from the sidebar. Applies live (no separate "Apply" step) to both Scanner tabs:

- **By Name**: case-insensitive substring match.
- **By Identifier**: substring match against the device's CoreBluetooth identifier. This replaces the Android reference's "By MAC Address" filter — see §11 for why.
- **By Minimum RSSI**: a slider threshold; devices weaker than the threshold are hidden.

Filters are combined with AND semantics; a filter with its toggle off does not constrain results.

## 9. Settings

Reachable from the sidebar:

- **Enhanced Beacon Ranging** toggle (default off) — see §5.
- **Known Beacons** management: a list of beacon UUIDs (with an optional friendly label) registered for enhanced ranging. Entries can be added here directly, or via a "Track this beacon" action on any discovered iBeacon in the Scanner — both write to the same underlying list. Entries can be removed with swipe-to-delete.

## 10. Navigation and information architecture

The app uses a `NavigationSplitView` with a sidebar containing three destinations: **Scanner** (default), **Filter**, **Settings**.

- On regular-width devices (iPad, and iPhone in some landscape contexts), the sidebar is persistently visible alongside the detail content.
- On compact-width devices (iPhone portrait), the sidebar automatically collapses behind a toolbar button and slides in as an overlay when invoked — standard `NavigationSplitView` behavior, requiring no custom drawer implementation.
- The Device Detail screen is pushed from within the Scanner destination's own navigation stack, not from the sidebar.

## 11. Permissions and platform constraints

| Usage string | When requested |
|---|---|
| `NSBluetoothAlwaysUsageDescription` | Always, from first launch — required for scanning and connecting. |
| `NSLocationWhenInUseUsageDescription` | Only when the user enables "Enhanced Beacon Ranging" in Settings; must be present in Info.plist from the start even though the runtime prompt is deferred. |

Platform constraints and deliberate deviations from the Android reference app:

- **No MAC addresses.** CoreBluetooth on iOS never exposes a device's real hardware MAC address; `CBPeripheral.identifier` is a UUID scoped to this app and device pairing. The Android "By MAC Address" filter is therefore replaced by "By Identifier," filtering on this UUID instead.
- **No bond/pairing status.** There is no iOS-exposed equivalent of Android's "bonded" indicator; it is omitted from device rows.
- **No BLE scanning in the iOS Simulator.** The Simulator has no Bluetooth radio; real scanning, connecting, and GATT interaction can only be verified on a physical device. UI and business-logic testing rely on fixtures/fakes instead (§14.5).
- **No background scanning.** v1 does not request the `bluetooth-central` background mode; scanning and ranging only run while the app is foregrounded/active.

## 12. First-release scope

**In scope:**
- BLE scanning with List and Radar (proximity) views.
- iBeacon detection (always-on parsing + opt-in enhanced ranging).
- Persisted device-sighting History.
- Connect/disconnect, GATT service/characteristic discovery.
- Read, Write (Text/Hex), Notify per characteristic.
- Filtering by Name, Identifier, minimum RSSI.
- Settings: Enhanced Ranging toggle, Known Beacons management.
- Adaptive NavigationSplitView UI for iPhone and iPad.

**Out of scope for v1:**
- Advertising/peripheral mode, Eddystone configuration, custom GATT server hosting.
- Favorites (separate from History).
- Background scanning.
- Device pairing/bonding management.

## 13. Open decisions / assumptions

- Filter and Settings values (including Known Beacons) persist via `UserDefaults` (TCA's `@Shared(.appStorage(...))`); only scan History is persisted via SwiftData, per explicit product decision — lighter-weight storage is preferred wherever querying isn't needed.
- Known Beacon registration is UUID-level only in v1; Major/Minor-specific ranging filters are not exposed.
- No account system, sync, or cloud backend — all data is local to the device.

## 14. Technical architecture

### 14.1 Stack

- SwiftUI, targeting iOS 18.
- Swift 6.3 language mode with full strict concurrency checking.
- [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) for state management, composed via `@Reducer`/`@ObservableState` features.
- `swift-dependencies` for dependency injection of hardware-backed clients.
- CoreBluetooth for BLE central operations; CoreLocation for opt-in beacon ranging.
- SwiftData for History persistence.
- Swift Testing for unit tests; TCA's `TestStore` for reducer/effect tests; XCUITest for UI smoke tests.

This is a deliberate, project-specific choice of TCA over the plain SwiftUI `@Observable` pattern used elsewhere in this developer's other iOS projects.

### 14.2 Package structure

A local Swift package, `BLEKit`, holds all logic and reducers, kept separate from the thin app target:

- `BLEKitCore` — pure models, parsing, classification, filtering, and value-codec logic. No CoreBluetooth/CoreLocation/TCA imports.
- `BLEKitHardware` — CoreBluetooth/CoreLocation delegate-to-`AsyncStream` bridges, behind small protocols (`BLECentralManaging`, `BLEPeripheralConnection`, `BeaconRanging`).
- `BLEKitDependencies` — `swift-dependencies` client wrappers around `BLEKitHardware`, the SwiftData `HistoryClient`/`HistoryModelActor`, and `@Shared` persistence key definitions.
- `BLEFeatures` — the TCA reducers themselves (`AppFeature`, `ScannerFeature`, `HistoryFeature`, `DeviceDetailFeature`, `FilterFeature`, `SettingsFeature`, `AddKnownBeaconFeature`).
- `BLEKitTestSupport` — fixtures and fake dependency clients shared by package tests, SwiftUI Previews, and the app's UI-test launch-argument override path (Debug/UITesting configurations only).

The app target (`BLEScanner.xcodeproj`) is intentionally thin: entry point, root `Store` construction, and SwiftUI views only.

### 14.3 Concurrency and ownership

All CoreBluetooth/CoreLocation delegate callbacks are bridged into `AsyncStream`s at the `BLEKitHardware` boundary, consumed by TCA `.run` effects with explicit cancellation IDs (per-scan, per-connection, per-characteristic-notification, per-ranging-session). SwiftData `@Model` types are not `Sendable`; all History access goes through a `@ModelActor` that returns plain `Sendable`/`Codable` DTOs, keeping the rest of the app clean under strict concurrency.

### 14.4 Data model summary

`DiscoveredDevice`, `GATTService`/`GATTCharacteristic`, `BeaconReading`, `FilterCriteria`, `AppSettings`, `KnownBeacon`, `HistoryRecordDTO` (mirroring the SwiftData `HistoryRecord` model) — see `BLEKitCore/Models/`.

### 14.5 Testing strategy

| Layer | Tool | Coverage |
|---|---|---|
| Pure logic | Swift Testing | iBeacon parsing, proximity classification, filter matching, value codec |
| SwiftData | Swift Testing, in-memory `ModelConfiguration` | History upsert/query correctness |
| TCA reducers/effects | `TestStore` (exhaustive, with fake clients + finite canned streams) | All features' state transitions and effect cancellation |
| UI flows | XCUITest, fake dependencies via launch argument | Navigation, filter, settings, connect/read smoke tests |
| Real hardware | Manual, physical device required | Real scanning, GATT connect/read/write/notify, real iBeacon/ranging behavior, permission prompts |

## 15. First-release implementation plan

1. **Foundation** — `BLEKit` package scaffolding, `BLEKitCore` models and pure logic, unit tests.
2. **Hardware + dependencies** — CoreBluetooth/CoreLocation bridges, `swift-dependencies` clients, SwiftData History.
3. **Features** — TCA reducers for Scanner, History, Device Detail, Filter, Settings.
4. **App shell** — Xcode project, `NavigationSplitView` root, views wired to the reducers.
5. **GATT interaction** — Read/Write/Notify UI and effects.
6. **Testing and polish** — `TestStore` coverage, XCUITest smoke suite, on-device verification against real BLE/iBeacon hardware.
