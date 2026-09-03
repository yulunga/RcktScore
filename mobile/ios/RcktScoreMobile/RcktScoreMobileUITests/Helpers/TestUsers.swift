import Foundation

struct TestUser {
    let usernameEnvironmentKey: String
    let passwordEnvironmentKey: String
    let tier: String

    var username: String {
        requiredEnvironmentValue(for: usernameEnvironmentKey)
    }

    var password: String {
        requiredEnvironmentValue(for: passwordEnvironmentKey)
    }

    private func requiredEnvironmentValue(for key: String) -> String {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            fatalError("Missing required UI-test environment variable: \(key)")
        }
        return value
    }
}

let testUsers: [TestUser] = [
    TestUser(
        usernameEnvironmentKey: "RCKTSCORE_UI_TEST_CLUB_USERNAME",
        passwordEnvironmentKey: "RCKTSCORE_UI_TEST_CLUB_PASSWORD",
        tier: "Club Essentials"
    ),
    TestUser(
        usernameEnvironmentKey: "RCKTSCORE_UI_TEST_PERSONAL_USERNAME",
        passwordEnvironmentKey: "RCKTSCORE_UI_TEST_PERSONAL_PASSWORD",
        tier: "Personal"
    ),
    TestUser(
        usernameEnvironmentKey: "RCKTSCORE_UI_TEST_PERSONAL_PLUS_USERNAME",
        passwordEnvironmentKey: "RCKTSCORE_UI_TEST_PERSONAL_PLUS_PASSWORD",
        tier: "Personal+"
    )
]
