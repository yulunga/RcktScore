import Foundation

struct TestUser {
    let username: String
    let password: String
    let tier: String
}

let testUsers: [TestUser] = [
    TestUser(
        username: "testclubess@hitnscore.com",
        password: "P4ssw0rd901!!",
        tier: "Club Essentials"
    ),
    TestUser(
        username: "testpersonal@hitnscore.com",
        password: "TestPassword123",
        tier: "Personal"
    ),
    TestUser(
        username: "testpersonalplus@hitnscore.com",
        password: "TestPassword123",
        tier: "Personal+"
    )
]
