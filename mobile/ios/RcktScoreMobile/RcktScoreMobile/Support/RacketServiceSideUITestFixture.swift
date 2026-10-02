import Foundation

enum RacketServiceSideUITestFixture {
    static let matchID = "ui-test-racket-service-side"

    static func make() -> (session: UserSession, match: MatchDetail) {
        let session = UserSession(
            id: 99_001,
            username: "ui-test@hitnscore.invalid",
            role: "admin",
            sessionToken: "ui-test-session",
            sessionExpiresAt: "2099-12-31T23:59:59Z",
            organizationID: 50_099,
            organizationName: "UI Test Personal Account",
            organizationType: "personal",
            plan: "personal_plus",
            enabledSports: ["squash"],
            firstName: "UI",
            surname: "Tester",
            fullName: "UI Tester",
            email: "ui-test@hitnscore.invalid",
            country: "United Kingdom",
            telephone: nil,
            availableMemberships: nil
        )

        let openingServer = MatchEvent(
            id: "fixture-server-player1",
            eventType: "server",
            payload: MatchEventPayload(
                currentServerSide: "player1",
                serviceSide: "Right",
                gameNumber: 1
            ),
            createdAt: "2026-10-02T09:59:00Z",
            summary: "Martin selected to serve"
        )
        let serviceTransferAtTwo = MatchEvent(
            id: "fixture-point-player2-two",
            eventType: "score_point",
            payload: MatchEventPayload(
                scorer: "player2",
                currentServerSide: "player2",
                serviceSide: "Right",
                player1Score: 0,
                player2Score: 2,
                gameNumber: 1
            ),
            createdAt: "2026-10-02T10:00:00Z",
            summary: "Paul scored"
        )

        let state = MatchState(
            player1Score: 0,
            player2Score: 2,
            player1GamesWon: 0,
            player2GamesWon: 0,
            player1SetGames: 0,
            player2SetGames: 0,
            currentGameNumber: 1,
            bestOf: 1,
            scoreType: 11,
            currentServer: "Paul",
            currentServerSide: "player2",
            serviceSide: "Right",
            player1ShirtColor: "navy",
            player2ShirtColor: "white",
            scoreDisplayMode: "racket",
            player1ScoreLabel: "0",
            player2ScoreLabel: "2",
            isTieBreak: false,
            teamFormat: "singles",
            tennisTeams: nil,
            currentServerParticipantID: nil,
            currentReceiver: nil,
            currentReceiverSide: nil,
            currentReceiverParticipantID: nil,
            teamServiceOrder: nil,
            serveOrder: nil,
            receiverDeuceOrder: nil,
            tieBreakFirstServerSide: nil,
            tieBreakFirstServerParticipantID: nil,
            handicap: nil,
            matchDurationSeconds: 300,
            gameHistory: [],
            matchComplete: false,
            winnerName: nil,
            events: [openingServer, serviceTransferAtTwo]
        )

        let match = MatchDetail(
            id: matchID,
            courtName: "Personal Court",
            courtAlias: nil,
            courtDisplayCode: nil,
            sport: "squash",
            player1Name: "Martin",
            player1Surname: nil,
            player1Handedness: "right",
            player1ShirtColor: "navy",
            player2Name: "Paul",
            player2Surname: nil,
            player2Handedness: "right",
            player2ShirtColor: "white",
            refereeName: nil,
            scoreType: 11,
            bestOf: 1,
            handicapEnabled: false,
            player1Offset: 0,
            player2Offset: 0,
            player1Band: nil,
            player2Band: nil,
            status: "active",
            autoScheduled: false,
            autoScheduleReason: nil,
            createdAt: "2026-10-02T09:55:00Z",
            updatedAt: "2026-10-02T10:00:00Z",
            completedAt: nil,
            matchDurationSeconds: 300,
            state: state
        )

        return (session, match)
    }
}
