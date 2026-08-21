# BLEScanner

A native iOS 18.6+ app for scanning nearby Bluetooth Low Energy (BLE) devices and iBeacons,
connecting to them, and reading/writing GATT characteristics. It's a central-role (client) app
only — no peripheral/advertising mode.

The UX is loosely modeled on the Android app "BLE Scanner" by Bluepixel Technologies (reference
screenshots in [`android_images/`](android_images/)), adapted to iOS platform idioms — see
[`docs/specification.md`](docs/specification.md) for the full product spec, including deliberate
deviations from the Android reference (e.g. no MAC addresses on iOS — filtering uses
`CBPeripheral.identifier` instead, exposed as "By Identifier").

## Features

- **Live scanning** with List (sorted by RSSI) and Radar (proximity rings) display modes
- **iBeacon detection** via advertisement parsing, plus opt-in enhanced ranging (CoreLocation)
  for beacons registered as "Known Beacons"
- **Scan history**, persisted on-device with SwiftData
- **Device detail / GATT explorer**: connect, browse services & characteristics, read/write
  (text or hex), and subscribe to notifications
- **Filtering** by name, identifier, and minimum RSSI
- **Settings** for enhanced beacon ranging and known beacon management

## Requirements

- Xcode 16+ / Swift 6.3 toolchain
- iOS 18.6+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (regenerates the `.xcodeproj` from
  `project.yml`)

## Repository layout

```
BLEKit/                  Local SPM package — ALL logic and TCA reducers live here
  Sources/BLEKitCore/         Pure models/parsing/classification — zero Apple-framework imports beyond Foundation
  Sources/BLEKitHardware/     CoreBluetooth/CoreLocation → AsyncStream bridges
  Sources/BLEKitDependencies/ swift-dependencies DI clients, SwiftData History, @Shared keys
  Sources/BLEFeatures/        TCA reducers (the app's actual business logic)
  Sources/BLEKitTestSupport/  Fixtures + fakes, used by package tests and the app's -UITesting path
  Tests/                      Swift Testing + TCA TestStore + SwiftData integration tests
BLEScanner/               Xcode project — deliberately thin (entry point + SwiftUI views only)
  project.yml                 xcodegen source of truth — DO NOT hand-edit BLEScanner.xcodeproj
  BLEScanner/                 App target sources (Views/, UITestSupport/, Extensions/)
  BLEScannerUITests/          XCUITest smoke suite
docs/specification.md    Full product specification
android_images/          Android reference app screenshots (non-code, for context only)
```

## Architecture

Built with **The Composable Architecture (TCA)** and **Swift 6.3 strict concurrency**. The
reducer tree is rooted at `AppFeature` (a `NavigationSplitView` sidebar) scoping into
`ScannerFeature`, `FilterFeature`, and `SettingsFeature`.

Persistence uses `@Shared(.appStorage(...))` for filter criteria, settings, and known beacons,
and SwiftData for scan history.

See [`CLAUDE.md`](CLAUDE.md) for a detailed architecture writeup, including hardware-layer
concurrency design, TCA gotchas hit in this codebase, and SwiftUI landmines to avoid.

## Building & testing

### BLEKit package (do this first when changing any logic/reducer)

```bash
cd BLEKit
swift build
swift test                                    # full suite
swift test --filter ScannerFeatureTests       # single suite
```

### Xcode app

Regenerate the Xcode project after editing `project.yml` or adding/removing/moving files under
`BLEScanner/BLEScanner/` or `BLEScanner/BLEScannerUITests/`:

```bash
cd BLEScanner
xcodegen generate
```

Build from the CLI (macro trust prompts require these flags for non-interactive builds):

```bash
xcodebuild -project BLEScanner.xcodeproj -scheme BLEScanner \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  -skipMacroValidation -skipPackagePluginValidation build

# UI tests need a concrete simulator id (list with: xcrun simctl list devices available)
xcodebuild -project BLEScanner.xcodeproj -scheme BLEScanner \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -skipMacroValidation -skipPackagePluginValidation \
  test -only-testing:BLEScannerUITests
```

The Simulator has no real Bluetooth radio, so UI tests run against a `-UITesting` launch path
that swaps in fakes (seeded fixture devices/history) from `BLEKitTestSupport` and the app
target's local `UITestSupport/`.

## License

No license file yet — all rights reserved by the author unless/until one is added.
