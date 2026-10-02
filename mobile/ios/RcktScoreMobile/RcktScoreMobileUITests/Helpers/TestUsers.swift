import Foundation

struct TestUser {
    let username: String
    let password: String
    let tier: String
}

enum TestCredentialsError: LocalizedError {
    case missingEnvironmentVariables([String])

    var errorDescription: String? {
        switch self {
        case .missingEnvironmentVariables(let names):
            return "Missing UI-test credentials: \(names.joined(separator: ", ")). See RcktScoreMobileUITests/README.md."
        }
    }
}

extension TestUser {
    static func personalPlusFromEnvironment(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> TestUser {
        try load(
            usernameVariable: "HITNSCORE_UI_TEST_PERSONAL_PLUS_USERNAME",
            passwordVariable: "HITNSCORE_UI_TEST_PERSONAL_PLUS_PASSWORD",
            tier: "Personal+",
            environment: environment
        )
    }

    static func loadFromEnvironment(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> [TestUser] {
        let definitions = [
            (
                username: "HITNSCORE_UI_TEST_CLUB_ESSENTIALS_USERNAME",
                password: "HITNSCORE_UI_TEST_CLUB_ESSENTIALS_PASSWORD",
                tier: "Club Essentials"
            ),
            (
                username: "HITNSCORE_UI_TEST_PERSONAL_USERNAME",
                password: "HITNSCORE_UI_TEST_PERSONAL_PASSWORD",
                tier: "Personal"
            ),
            (
                username: "HITNSCORE_UI_TEST_PERSONAL_PLUS_USERNAME",
                password: "HITNSCORE_UI_TEST_PERSONAL_PLUS_PASSWORD",
                tier: "Personal+"
            )
        ]

        return try definitions.map {
            try load(
                usernameVariable: $0.username,
                passwordVariable: $0.password,
                tier: $0.tier,
                environment: environment
            )
        }
    }

    private static func load(
        usernameVariable: String,
        passwordVariable: String,
        tier: String,
        environment: [String: String]
    ) throws -> TestUser {
        let username = value(for: usernameVariable, environment: environment)
        let password = value(for: passwordVariable, environment: environment)
        let missingNames = [
            username == nil ? usernameVariable : nil,
            password == nil ? passwordVariable : nil,
        ].compactMap { $0 }

        guard let username, let password, missingNames.isEmpty else {
            throw TestCredentialsError.missingEnvironmentVariables(missingNames)
        }

        return TestUser(username: username, password: password, tier: tier)
    }

    private static func value(
        for name: String,
        environment: [String: String]
    ) -> String? {
        let directValue = environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if directValue?.isEmpty == false {
            return directValue
        }

        let runnerValue = environment["TEST_RUNNER_\(name)"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return runnerValue?.isEmpty == false ? runnerValue : nil
    }
}
