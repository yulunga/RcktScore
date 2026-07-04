import XCTest

enum ScreenshotHelper {

    static func capture(

        app: XCUIApplication,

        name: String,

        testCase: XCTestCase

    ) {

        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(

            screenshot: screenshot

        )

        attachment.name = name

        attachment.lifetime = .keepAlways

        testCase.add(attachment)

    }

}