import XCTest

/// Runs against the `-UITesting` launch configuration, which seeds fake dependencies with
/// canned devices/history/GATT data (see `BLEScannerApp` and `UITestSupport/`) since the
/// Simulator has no real Bluetooth radio.
@MainActor
final class BLEScannerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting"]
        app.launch()
        return app
    }

    /// The sidebar starts collapsed on both iPad- and iPhone-sized simulators; a hamburger
    /// button in the leading toolbar position (the same one on every screen) reveals it.
    private func openSidebar(_ app: XCUIApplication) {
        guard !sidebarItem(app, "sidebar.scanner").isHittable else { return }
        app.buttons["sidebar.hamburgerButton"].tap()
        // The reveal is animated; wait for the row to actually be hittable, not just present in
        // the accessibility tree, before any caller tries to tap it.
        let hittablePredicate = NSPredicate(format: "isHittable == true")
        _ = XCTWaiter.wait(
            for: [expectation(for: hittablePredicate, evaluatedWith: sidebarItem(app, "sidebar.scanner"))],
            timeout: 5
        )
    }

    /// The sidebar's `List(selection:)` rows aren't exposed as `.buttons` in the accessibility
    /// tree, and `Label`'s icon + text both carry the identifier, so this matches the first
    /// element with that identifier regardless of type.
    private func sidebarItem(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testScannerShowsSeededDevicesByDefault() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Living Room Sensor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Garage Sensor"].exists)
    }

    func testSearchFiltersNearByListByName() throws {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Garage Sensor"].waitForExistence(timeout: 5))

        let searchField = app.searchFields["Search by name or ID"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("garage")

        XCTAssertTrue(app.staticTexts["Garage Sensor"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Living Room Sensor"].exists)
    }

    /// "Copy Raw Data" is available on connectable rows too, not just non-connectable ones —
    /// both seeded fixtures are connectable and carry a name + manufacturer data, so this
    /// asserts the button now surfaces there. Actually tapping it hits the same class of
    /// Simulator/XCUITest automation limitation documented on the History screen's
    /// swipe-to-delete action above (a valid, on-screen frame that's consistently reported
    /// non-hittable — confirmed here even as a real `Button`, not just a tap-gesture `Image`, so
    /// it's a List-row quirk in this environment rather than something specific to gesture
    /// type): `ScannerFeatureTests."rawAdvertisementDataCopyTapped copies the device's
    /// advertisement text and clears the toast after a delay"` already covers the copy logic
    /// itself via `TestStore`.
    func testCopyRawAdvertisementDataButtonShowsOnConnectableRow() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        let copyButton = app.buttons["device.row.rawDataIndicator.11111111-1111-1111-1111-111111111111"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5))
    }

    func testSidebarNavigationAcrossDestinations() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))

        // The drawer closes after each selection, so it's reopened before every tap.
        openSidebar(app)
        sidebarItem(app, "sidebar.filter").tap()
        XCTAssertTrue(app.navigationBars["Filter"].waitForExistence(timeout: 5))

        openSidebar(app)
        sidebarItem(app, "sidebar.settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        openSidebar(app)
        sidebarItem(app, "sidebar.scanner").tap()
        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
    }

    func testHistoryTabShowsSeededRecords() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        app.segmentedControls["scanner.tabPicker"].buttons["History"].tap()

        XCTAssertTrue(app.staticTexts["Living Room Sensor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Garage Sensor"].exists)
    }

    func testSearchFiltersHistoryListByName() throws {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        app.segmentedControls["scanner.tabPicker"].buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Garage Sensor"].waitForExistence(timeout: 5))

        let searchField = app.searchFields["Search by name or ID"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("garage")

        XCTAssertTrue(app.staticTexts["Garage Sensor"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Living Room Sensor"].exists)
    }

    /// Swiping a row reveals the "Delete" swipe action, but reliably tapping it afterward hits
    /// the same class of Simulator/XCUITest automation limitation documented on the Filter
    /// screen's `Toggle` above: the revealed action button is found in the accessibility tree
    /// but consistently reports a non-hittable frame, not merely a timing flake (confirmed via
    /// several retries at different delays). `HistoryFeatureTests.deleteButtonTappedRemovesRecord`
    /// covers the actual delete logic via `TestStore`; this only asserts the action surfaces.
    func testHistorySwipeRevealsDeleteAction() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        app.segmentedControls["scanner.tabPicker"].buttons["History"].tap()

        let garageRow = app.staticTexts["Garage Sensor"]
        XCTAssertTrue(garageRow.waitForExistence(timeout: 5))
        garageRow.swipeLeft()

        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
    }

    func testHistoryEraseAllClearsEveryRecord() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        app.segmentedControls["scanner.tabPicker"].buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Living Room Sensor"].waitForExistence(timeout: 5))

        app.buttons["history.eraseAllButton"].tap()
        app.buttons["Erase All"].tap()

        XCTAssertTrue(app.staticTexts["No History"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Living Room Sensor"].exists)
    }

    /// Verifies the Filter screen renders its full structure. This does not drive the "By Name"
    /// toggle: on this Simulator/Xcode combination (26.6 / iPadOS 26), `Toggle` controls inside
    /// a `Form` never invoke their `Binding`'s `set` closure when tapped via XCUITest — confirmed
    /// by instrumenting the toggle's own binding and the reducer case directly, neither of which
    /// ever fired despite the tap reporting success and landing on the switch's real coordinates
    /// (verified via screenshot). `FilterFeatureTests` and `DeviceFilterTests` in the `BLEKit`
    /// package already cover this toggle's actual logic exhaustively via `TestStore`; this is a
    /// Simulator automation limitation for this control, not an app bug.
    func testFilterScreenRendersExpectedControls() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        openSidebar(app)

        sidebarItem(app, "sidebar.filter").tap()
        XCTAssertTrue(app.navigationBars["Filter"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.switches["filter.name.toggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["filter.name.field"].exists)
        // Lower sections of the Form may be lazily rendered below the fold depending on device
        // height, so this scrolls before checking for the trailing "Reset Filters" button.
        app.swipeUp()
        XCTAssertTrue(app.buttons["Reset Filters"].waitForExistence(timeout: 5))
    }

    func testSettingsAddAndDeleteKnownBeacon() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        openSidebar(app)
        sidebarItem(app, "sidebar.settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.switches["settings.enhancedRanging.toggle"].tap()

        app.buttons["settings.addKnownBeacon.button"].tap()
        let uuidField = app.textFields["addBeacon.uuidField"]
        XCTAssertTrue(uuidField.waitForExistence(timeout: 5))
        uuidField.tap()
        uuidField.typeText("E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")
        app.buttons["addBeacon.saveButton"].tap()

        let beaconLabel = app.staticTexts.matching(identifier: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0").firstMatch
        XCTAssertTrue(beaconLabel.waitForExistence(timeout: 5))
        beaconLabel.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertFalse(app.staticTexts["E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"].waitForExistence(timeout: 2))
    }

    /// "Chart" sits in the same row `VStack` as "Raw Data" and hits the identical
    /// Simulator/XCUITest limitation documented on
    /// `testCopyRawAdvertisementDataButtonShowsOnConnectableRow` above: a valid, on-screen frame
    /// that's consistently reported non-hittable. `ScannerFeatureTests.
    /// "rssiChartTapped shows the device's chart and rssiChartDismissed clears it"` already
    /// covers the tap/dismiss logic itself via `TestStore`; this only asserts the button surfaces.
    func testChartButtonShowsOnDeviceRow() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        let chartButton = app.buttons["device.row.chartButton.11111111-1111-1111-1111-111111111111"]
        XCTAssertTrue(chartButton.waitForExistence(timeout: 5))
    }

    /// The one UI test that still drives a full interactive flow end to end (row -> connect ->
    /// discover -> expand characteristic -> read -> decoded value). Every `.tap()` here goes
    /// through `tapCenter`: on this Simulator/Xcode combination XCUITest can't compute a hit
    /// point for SwiftUI `List`-row buttons (and buttons in a `List` `Section`), reporting a
    /// valid on-screen frame as `{-1, -1}` "not hittable" — the same limitation documented on
    /// `testChartButtonShowsOnDeviceRow` and the History swipe-action test. A coordinate tap on
    /// the frame's centre performs the real interaction without the hittability precheck.
    func testDeviceDetailConnectAndReadCharacteristic() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        let row = app.buttons["device.row.\(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!.uuidString)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        tapCenter(row)

        let connectButton = app.buttons["deviceDetail.connectButton"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5))
        tapCenter(connectButton)

        XCTAssertTrue(app.staticTexts["Battery Service"].waitForExistence(timeout: 5))
        let batteryLevel = app.staticTexts["Battery Level"]
        XCTAssertTrue(batteryLevel.waitForExistence(timeout: 5))
        tapCenter(batteryLevel)

        let readButton = app.buttons["characteristic.2A19.readButton"]
        XCTAssertTrue(readButton.waitForExistence(timeout: 5))
        tapCenter(readButton)

        XCTAssertTrue(app.staticTexts["Hex: 55"].waitForExistence(timeout: 5))

        // The expanded characteristic also lists its discovered descriptors by SIG name.
        XCTAssertTrue(app.staticTexts["Client Characteristic Configuration"].waitForExistence(timeout: 5))
    }

    /// Taps the geometric centre of an element via `XCUICoordinate`, bypassing XCUITest's
    /// hittability precheck. Needed because SwiftUI `List` rows/sections in this Simulator
    /// environment report otherwise-valid frames as non-hittable (`{-1, -1}` hit point).
    private func tapCenter(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
