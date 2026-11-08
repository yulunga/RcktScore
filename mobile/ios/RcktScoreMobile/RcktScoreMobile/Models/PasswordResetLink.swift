import Foundation

struct PasswordResetLink: Identifiable, Equatable {
    let token: String
    let isAccountSetup: Bool

    var id: String { token }

    static func parse(url: URL) -> PasswordResetLink? {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "app.hitnscore.com",
              url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased() == "help",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let values = queryValues(from: components.queryItems)
        return build(mode: values["mode"], token: values["token"])
    }

    static func parse(text: String) -> PasswordResetLink? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return parse(url: url)
        }

        if !trimmed.contains("="),
           !trimmed.contains("?"),
           !trimmed.contains("/"),
           trimmed.count >= 16,
           trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
            return build(mode: nil, token: trimmed)
        }

        let query = trimmed
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .last
            .map(String.init)?
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? trimmed
        var components = URLComponents()
        components.query = query
        let values = queryValues(from: components.queryItems)
        return build(mode: values["mode"], token: values["token"])
    }

    private static func queryValues(from items: [URLQueryItem]?) -> [String: String] {
        var values: [String: String] = [:]
        for item in items ?? [] {
            values[item.name] = item.value ?? ""
        }
        return values
    }

    private static func build(mode: String?, token: String?) -> PasswordResetLink? {
        let cleanMode = mode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanToken = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cleanToken.isEmpty else { return nil }
        guard cleanMode == nil || cleanMode == "reset" || cleanMode == "confirm-email" else {
            return nil
        }
        return PasswordResetLink(
            token: cleanToken,
            isAccountSetup: cleanMode == "confirm-email" || cleanToken.hasPrefix("setup_")
        )
    }
}

enum PasswordRule: CaseIterable {
    case length
    case uppercase
    case number
    case symbol
    case notCommon

    var label: String {
        switch self {
        case .length: "At least 8 characters"
        case .uppercase: "At least one uppercase letter"
        case .number: "At least one number"
        case .symbol: "At least one symbol"
        case .notCommon: "No common or easily guessed word"
        }
    }
}

enum HitnScorePasswordPolicy {
    private static let commonTerms = [
        "password", "passw0rd", "qwerty", "welcome", "letmein", "changeme",
        "admin", "login", "secret", "abc123", "hitnscore"
    ]

    static func unmetRules(for password: String) -> Set<PasswordRule> {
        let normalized = password
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        var unmet = Set<PasswordRule>()
        if password.count < 8 { unmet.insert(.length) }
        if !password.contains(where: { $0.isUppercase }) { unmet.insert(.uppercase) }
        if !password.contains(where: { $0.isNumber }) { unmet.insert(.number) }
        if !password.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }) {
            unmet.insert(.symbol)
        }
        if password.isEmpty || commonTerms.contains(where: normalized.contains) {
            unmet.insert(.notCommon)
        }
        return unmet
    }
}
