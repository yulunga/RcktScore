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

        let requiredNames = definitions.flatMap { [$0.username, $0.password] }
        let missingNames = requiredNames.filter {
            environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        }

        guard missingNames.isEmpty else {
            throw TestCredentialsError.missingEnvironmentVariables(missingNames)
        }

        return definitions.map {
            TestUser(
                username: environment[$0.username]!,
                password: environment[$0.password]!,
                tier: $0.tier
            )
        }
    }
}
