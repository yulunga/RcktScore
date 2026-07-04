import XCTest

final class LoginSmokeTests: HitnScoreBaseUITest {

    func testLoginSmokeTest_AllSubscriptionLevels() throws {

        for user in testUsers {

            runSmokeTest(
                user: user,
                lightMode: true
            )

            runSmokeTest(
                user: user,
                lightMode: false
            )

        }

    }

}


private extension LoginSmokeTests {

    func runSmokeTest(
        user: TestUser,
        lightMode: Bool
    ) {

        //
        // Launch
        //

        launchApp(lightMode: lightMode)

        //
        // Screens
        //

        let login = LoginScreen(app: app)
        let dashboard = DashboardScreen(app: app)
        let settings = SettingsScreen(app: app)

        //
        // Login
        //

        login.login(user: user)

        //
        // Verify Dashboard
        //

        waitFor(dashboard.dashboardTitle)

        captureScreenshot(
            screenshotName(
                user: user,
                mode: lightMode,
                orientation: "Portrait",
                screen: "Dashboard"
            )
        )

        //
        // Landscape Left
        //

        rotateLandscapeLeft()

        captureScreenshot(
            screenshotName(
                user: user,
                mode: lightMode,
                orientation: "LandscapeLeft",
                screen: "Dashboard"
            )
        )

        //
        // Landscape Right
        //

        rotateLandscapeRight()

        captureScreenshot(
            screenshotName(
                user: user,
                mode: lightMode,
                orientation: "LandscapeRight",
                screen: "Dashboard"
            )
        )

        //
        // Portrait
        //

        rotatePortrait()

        captureScreenshot(
            screenshotName(
                user: user,
                mode: lightMode,
                orientation: "Portrait",
                screen: "Dashboard"
            )
        )

        //
        // Settings
        //

        dashboard.settingsButton.tap()

        waitFor(settings.signOutButton)

        captureScreenshot(
            screenshotName(
                user: user,
                mode: lightMode,
                orientation: "Portrait",
                screen: "Settings"
            )
        )

        //
        // Logout
        //

        settings.logout()

        waitFor(login.loginButton)

    }

}


private extension LoginSmokeTests {

    func screenshotName(
        user: TestUser,
        mode: Bool,
        orientation: String,
        screen: String
    ) -> String {

        let appearance = mode ? "Light" : "Dark"

        return "\(user.tier)-\(appearance)-\(orientation)-\(screen)"

    }

}