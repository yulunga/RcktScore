import Foundation

enum AppConfig {
    private static let fallbackAPIBaseURL = "https://st3nn5zsm6.execute-api.eu-west-2.amazonaws.com/prod"
    private static let fallbackEnvironment = "development"
    private static let fallbackBuildID = "dev-local"

    static var apiBaseURL: URL {
        let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
        return URL(string: value ?? fallbackAPIBaseURL) ?? URL(string: fallbackAPIBaseURL)!
    }

    static var environmentName: String {
        (Bundle.main.object(forInfoDictionaryKey: "EnvironmentName") as? String) ?? fallbackEnvironment
    }

    static var buildID: String {
        (Bundle.main.object(forInfoDictionaryKey: "BuildID") as? String) ?? fallbackBuildID
    }
}
