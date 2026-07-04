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

        dashboard.verifyLoaded()

        self.captureScreenshot(
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

        self.captureScreenshot(
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

        self.captureScreenshot(
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

        self.captureScreenshot(
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

        dashboard.openSettings()

        settings.verifyLoaded()

        self.captureScreenshot(
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

        login.verifyLoaded()

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
