import SwiftUI
import WatchConnectivity

@main
struct HitnScoreWatchApp: App {
    var body: some Scene {
        WindowGroup { WristScorerView() }
    }
}

@MainActor
private final class WristConnection: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var score: WristScore?
    @Published private(set) var message: String? = "Connecting to iPhone…"
    @Published private(set) var isSending = false
    private var isRefreshing = false
    private var latestRequest = UUID()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ action: WristAction? = nil, for displayedScore: WristScore? = nil) async {
        guard !isSending, action != nil || !isRefreshing else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            score = nil
            message = "Connect to your paired iPhone."
            return
        }

        let request: WristRequest
        if let action {
            guard let score, score == displayedScore, score.actions.contains(action) else { return }
            request = WristRequest(action: action, matchID: score.matchID, revision: score.revision)
        } else {
            request = .refresh
        }

        guard let payload = try? JSONEncoder().encode(request) else { return }
        let requestID = UUID()
        latestRequest = requestID
        if action == nil {
            isRefreshing = true
        } else {
            isSending = true
        }
        defer {
            if action == nil {
                isRefreshing = false
            } else {
                isSending = false
            }
        }

        let data: Data? = await withCheckedContinuation { continuation in
            session.sendMessageData(payload, replyHandler: { data in
                continuation.resume(returning: data)
            }, errorHandler: { _ in
                continuation.resume(returning: nil)
            })
        }

        guard latestRequest == requestID else { return }
        guard let data, let reply = try? JSONDecoder().decode(WristReply.self, from: data) else {
            score = nil
            message = action == nil
                ? "Waiting for your iPhone…"
                : "Checking the score after a lost connection…"
            return
        }

        score = reply.score
        message = reply.message
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}

private struct WristScorerView: View {
    @StateObject private var connection = WristConnection()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showDecisions = false

    var body: some View {
        ScrollView {
            if let score = connection.score {
                VStack(spacing: 6) {
                    if !score.status.isEmpty {
                        Text(score.status)
                            .font(.caption2.bold())
                    }
                    HStack(spacing: 6) {
                        side(score.one, action: .pointOne, score: score, color: .blue)
                        side(score.two, action: .pointTwo, score: score, color: .purple)
                    }
                    if let server = score.server {
                        Label(server, systemImage: "circle.fill")
                            .font(.caption2)
                            .lineLimit(1)
                            .accessibilityLabel("Serving: \(server)")
                    }
                    if score.actions.contains(.receiveRight) {
                        HStack(spacing: 6) {
                            actionButton("Right", action: .receiveRight, score: score)
                            actionButton("Left", action: .receiveLeft, score: score)
                        }
                    }
                    if score.actions.contains(.undo) || score.actions.contains(.letCall) {
                        HStack(spacing: 6) {
                            if score.actions.contains(.undo) {
                                Button {
                                    Task { await connection.send(.undo, for: score) }
                                } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                }
                                .accessibilityLabel("Undo last point")
                            }
                            if score.actions.contains(.letCall) {
                                Button("Decisions") { showDecisions = true }
                            }
                        }
                        .font(.caption)
                        .disabled(connection.isSending)
                    }
                    if let message = connection.message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
                .sheet(isPresented: $showDecisions) {
                    ScrollView {
                        actionButton("Let", action: .letCall, score: score)
                        actionButton("Stroke to \(score.one.name)", action: .strokeOne, score: score)
                        actionButton("Stroke to \(score.two.name)", action: .strokeTwo, score: score)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "applewatch")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    Text(connection.message ?? "Open a live match on your iPhone.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .onChange(of: connection.score?.matchID) { showDecisions = false }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await connection.send()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func actionButton(_ title: String, action: WristAction, score: WristScore) -> some View {
        Button(title) {
            showDecisions = false
            Task { await connection.send(action, for: score) }
        }
        .disabled(connection.isSending || connection.score?.actions.contains(action) != true)
    }

    private func side(_ side: WristScore.Side, action: WristAction, score: WristScore, color: Color) -> some View {
        let canScore = score.actions.contains(action)
        return Button {
            Task { await connection.send(action, for: score) }
        } label: {
            VStack(spacing: 2) {
                Text(side.name)
                    .font(.caption2.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(side.points)
                    .font(.title.bold().monospacedDigit())
                if let sets = side.sets {
                    Text("\(side.games) G · \(sets) S").font(.caption2.monospacedDigit())
                } else {
                    Text("\(side.games) games").font(.caption2.monospacedDigit())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(3)
            .background(color.opacity(canScore ? 0.35 : 0.17), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canScore || connection.isSending)
        .accessibilityLabel("\(side.name), \(side.points) points, \(side.games) games"
            + (side.sets.map { ", \($0) sets" } ?? "")
            + (side.serving ? ", serving" : ""))
        .accessibilityHint(canScore ? "Awards one point" : "")
    }
}
