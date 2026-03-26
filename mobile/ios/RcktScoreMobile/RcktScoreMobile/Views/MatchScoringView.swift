import SwiftUI

struct MatchScoringView: View {
    let matchID: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Match Scoring")
                .font(.title2.bold())
            Text("Match ID: \(matchID)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Scoring actions, undo, and timeline integration will be wired next.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Live Match")
    }
}
