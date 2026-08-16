import XCTest

/// Runs against the `-UITesting` launch configuration, which seeds fake dependencies with
/// canned devices/history/GATT data (see `BLEScannerApp` and `UITestSupport/`) since the
/// Simulator has no real Bluetooth radio.
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

    /// The sidebar starts collapsed behind a toolbar button even on iPad-sized simulators, so
    /// every test that navigates via the sidebar opens it first.
    private func openSidebar(_ app: XCUIApplication) {
        if !sidebarItem(app, "sidebar.scanner").exists {
            app.buttons["ToggleSidebar"].tap()
        }
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

    func testSidebarNavigationAcrossDestinations() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        openSidebar(app)

        sidebarItem(app, "sidebar.filter").tap()
        XCTAssertTrue(app.navigationBars["Filter"].waitForExistence(timeout: 5))

        sidebarItem(app, "sidebar.settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

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
        XCTAssertTrue(app.staticTexts["BY IDENTIFIER"].exists)
        XCTAssertTrue(app.staticTexts["BY MINIMUM RSSI"].exists)
        XCTAssertTrue(app.buttons["Reset Filters"].exists)
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

    func testDeviceDetailConnectAndReadCharacteristic() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Scanner"].waitForExistence(timeout: 5))
        let row = app.buttons["device.row.\(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!.uuidString)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let connectButton = app.buttons["deviceDetail.connectButton"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5))
        connectButton.tap()

        XCTAssertTrue(app.staticTexts["Battery Service"].waitForExistence(timeout: 5))
        app.staticTexts["Battery Level"].tap()

        let readButton = app.buttons["characteristic.2A19.readButton"]
        XCTAssertTrue(readButton.waitForExistence(timeout: 5))
        readButton.tap()

        XCTAssertTrue(app.staticTexts["Hex: 55"].waitForExistence(timeout: 5))
    }
}
