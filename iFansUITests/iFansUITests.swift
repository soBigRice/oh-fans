import XCTest

final class iFansUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func makeApp(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES", "-ui-test-preview-data"] + additionalArguments
        return app
    }

    @MainActor
    func testCompactPanelShowsCoreSummary() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "panel.compact.window").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "summary.current-mode").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "summary.hottest-temp").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "status.current").firstMatch.waitForExistence(timeout: 5))

        let fanRowsAvailable = app.descendants(matching: .any).matching(identifier: "monitoring.fans.available").firstMatch
        let fanRowsEmpty = app.descendants(matching: .any).matching(identifier: "monitoring.fans.empty").firstMatch
        XCTAssertTrue(
            fanRowsAvailable.waitForExistence(timeout: 2) || fanRowsEmpty.waitForExistence(timeout: 2),
            "Expected fan monitoring rows or an explicit empty placeholder."
        )

        for mode in ["systemAuto", "quiet", "balanced", "performance"] {
            let button = app.descendants(matching: .any).matching(identifier: "mode.\(mode)").firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing mode button: \(mode)")
        }
    }

    @MainActor
    func testReadOnlyPanelKeepsOnlySystemAutoEnabled() throws {
        let app = makeApp(additionalArguments: ["-ui-test-read-only"])
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "panel.compact.window").firstMatch.waitForExistence(timeout: 5))

        let autoButton = app.descendants(matching: .any).matching(identifier: "mode.systemAuto").firstMatch
        let quietButton = app.descendants(matching: .any).matching(identifier: "mode.quiet").firstMatch
        let balancedButton = app.descendants(matching: .any).matching(identifier: "mode.balanced").firstMatch
        let performanceButton = app.descendants(matching: .any).matching(identifier: "mode.performance").firstMatch

        XCTAssertTrue(autoButton.waitForExistence(timeout: 5))
        XCTAssertTrue(quietButton.waitForExistence(timeout: 5))
        XCTAssertTrue(balancedButton.waitForExistence(timeout: 5))
        XCTAssertTrue(performanceButton.waitForExistence(timeout: 5))

        XCTAssertTrue(autoButton.isEnabled)
        XCTAssertFalse(quietButton.isEnabled)
        XCTAssertFalse(balancedButton.isEnabled)
        XCTAssertFalse(performanceButton.isEnabled)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "status.current").firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testMenuBarPanelHasOpenMainWindowAction() throws {
        let app = makeApp(additionalArguments: ["-ui-test-menu-panel"])
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "panel.compact.menu").firstMatch.waitForExistence(timeout: 5))
        let openMainWindow = app.descendants(matching: .any).matching(identifier: "menu.open-main-window").firstMatch
        XCTAssertTrue(openMainWindow.waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsViewShowsAuthorVersionAndQuit() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))

        let settingsButton = app.descendants(matching: .any).matching(identifier: "dashboard.open-settings").firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let authorLink = app.descendants(matching: .any).matching(identifier: "settings.author.link").firstMatch
        let versionValue = app.descendants(matching: .any).matching(identifier: "settings.version").firstMatch
        let quitButton = app.descendants(matching: .any).matching(identifier: "settings.quit").firstMatch

        XCTAssertTrue(authorLink.waitForExistence(timeout: 5))
        XCTAssertTrue(versionValue.waitForExistence(timeout: 5))
        XCTAssertTrue(quitButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testHelperInstallActionAppearsWhenHelperNeedsRepair() throws {
        let app = makeApp(additionalArguments: ["-ui-test-helper-install"])
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "panel.compact.window").firstMatch.waitForExistence(timeout: 5))
        let installButton = app.descendants(matching: .any).matching(identifier: "helper.install.panel").firstMatch
        XCTAssertTrue(installButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "status.current").firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeApp().launch()
        }
    }
}
