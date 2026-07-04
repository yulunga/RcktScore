import XCTest

enum OrientationHelper {

    static func portrait(_ app: XCUIApplication) {

        XCUIDevice.shared.orientation = .portrait

    }

    static func landscapeLeft(_ app: XCUIApplication) {

        XCUIDevice.shared.orientation = .landscapeLeft

    }

    static func landscapeRight(_ app: XCUIApplication) {

        XCUIDevice.shared.orientation = .landscapeRight

    }

}