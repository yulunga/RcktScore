import Foundation
import UIKit
import WatchConnectivity

@MainActor
final class WristScoringBridge: NSObject, WCSessionDelegate {
    private var scorerID: UUID?
    private var handleRequest: ((WristRequest) async -> WristReply)?
    private var isHandlingAction = false
    private let isEligible: () -> Bool

    init(isEligible: @escaping () -> Bool) {
        self.isEligible = isEligible
        super.init()
        guard WCSession.isSupported(), UIDevice.current.userInterfaceIdiom == .phone else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func connect(id: UUID, handler: @escaping (WristRequest) async -> WristReply) {
        scorerID = id
        handleRequest = handler
    }

    func disconnect(id: UUID) {
        guard scorerID == id else { return }
        scorerID = nil
        handleRequest = nil
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession, didReceiveMessageData messageData: Data,
        replyHandler: @escaping (Data) -> Void
    ) {
        guard let request = try? JSONDecoder().decode(WristRequest.self, from: messageData) else {
            replyHandler(Data())
            return
        }

        Task { @MainActor in
            let reply = await respond(to: request)
            replyHandler((try? JSONEncoder().encode(reply)) ?? Data())
        }
    }

    private func respond(to request: WristRequest) async -> WristReply {
        guard isEligible() else {
            return WristReply(score: nil, message: "Sign in on your iPhone with Personal Plus.")
        }
        guard let handleRequest else {
            return WristReply(score: nil, message: "Open a live match on your iPhone.")
        }
        guard request.action != nil else { return await handleRequest(request) }
        guard !isHandlingAction else {
            return WristReply(score: nil, message: "Wait for the previous action to finish.")
        }
        isHandlingAction = true
        defer { isHandlingAction = false }
        return await handleRequest(request)
    }
}
