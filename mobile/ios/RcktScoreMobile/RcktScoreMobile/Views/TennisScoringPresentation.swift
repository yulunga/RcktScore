import SwiftUI

/// Tennis owns its score presentation so tennis concepts do not leak into the
/// squash/racketball score cards.
struct TennisScoringPresentation: View {
    let match: MatchDetail
    let state: MatchState
    let compact: Bool
    let landscapeTablet: Bool
    let scoringDisabled: Bool
    let onScore: (String) -> Void
    let onChooseReceiverCourt: (String) -> Void

    private let brandBlue = Color(red: 18 / 255, green: 116 / 255, blue: 208 / 255)
    private let activeGreen = Color(red: 82 / 255, green: 205 / 255, blue: 120 / 255)
    private let navy = Color(red: 28 / 255, green: 61 / 255, blue: 99 / 255)

    private var requiresReceiverChoice: Bool {
        state.tennisNoAdScoring
            && !state.isTieBreak
            && state.player1Score == 3
            && state.player2Score == 3
            && state.noAdDecidingSide == nil
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            formatBanner

            HStack(alignment: .top, spacing: landscapeTablet ? 22 : 12) {
                scoreCard(
                    side: "player1",
                    name: match.player1Name,
                    surname: match.player1Surname,
                    point: state.player1ScoreLabel ?? String(state.player1Score),
                    games: state.player1SetGames,
                    sets: state.player1GamesWon,
                    shirt: state.player1ShirtColor ?? match.player1ShirtColor ?? "navy"
                )

                VStack(spacing: 8) {
                    Text(state.isMatchTiebreak ? "MATCH\nTIEBREAK" : (state.isTieBreak ? "TIEBREAK" : "POINTS"))
                        .font(.caption2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Image(systemName: "tennisball.fill")
                        .font(.title2)
                        .foregroundStyle(activeGreen)
                    Text("Set \(state.currentGameNumber)")
                        .font(.caption.weight(.semibold))
                }
                .frame(minWidth: landscapeTablet ? 92 : 58)
                .padding(.top, compact ? 42 : 54)

                scoreCard(
                    side: "player2",
                    name: match.player2Name,
                    surname: match.player2Surname,
                    point: state.player2ScoreLabel ?? String(state.player2Score),
                    games: state.player2SetGames,
                    sets: state.player2GamesWon,
                    shirt: state.player2ShirtColor ?? match.player2ShirtColor ?? "white"
                )
            }
            .padding(.horizontal, compact ? 8 : 14)

            HStack(spacing: 12) {
                Label("Serving: \(state.currentServer ?? "Not set")", systemImage: "tennisball.fill")
                Spacer()
                Text("Receiving: \(state.currentReceiver ?? "Not set")")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, compact ? 12 : 18)

            if requiresReceiverChoice {
                receiverChoice
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: requiresReceiverChoice)
    }

    private var formatBanner: some View {
        HStack(spacing: 8) {
            Circle().fill(activeGreen).frame(width: 9, height: 9)
            Text(state.isMatchTiebreak
                 ? "Final-set match tiebreak • First to 10, win by 2"
                 : "Best of \(state.bestOf) sets • First to 6 games\(state.tennisNoAdScoring ? " • No-Ad" : "")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(brandBlue)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 9 : 11)
        .background(brandBlue.opacity(0.12))
        .clipShape(Capsule())
        .padding(.horizontal, 6)
    }

    private func scoreCard(
        side: String,
        name: String,
        surname: String?,
        point: String,
        games: Int,
        sets: Int,
        shirt: String
    ) -> some View {
        Button {
            onScore(side)
        } label: {
            VStack(spacing: compact ? 8 : 10) {
                HStack(spacing: 6) {
                    Text([name, surname].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
                        .font(compact ? .headline : .title3.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    if state.currentServerSide == side {
                        Image(systemName: "tennisball.fill")
                            .foregroundStyle(activeGreen)
                    }
                }
                .frame(maxWidth: .infinity)

                Text(point)
                    .font(.system(size: landscapeTablet ? 64 : (compact ? 44 : 52), weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, minHeight: compact ? 64 : 82)
                    .background(.white.opacity(0.17))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack {
                    stat("Games", games)
                    Divider().overlay(foreground(for: shirt).opacity(0.35))
                    stat("Sets", sets)
                }
                .frame(height: 42)
            }
            .padding(compact ? 10 : 14)
            .frame(maxWidth: .infinity, minHeight: landscapeTablet ? 260 : (compact ? 180 : 210))
            .background(fill(for: shirt))
            .foregroundStyle(foreground(for: shirt))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(scoringDisabled || requiresReceiverChoice)
        .accessibilityIdentifier("tennis.scoreCard.\(side)")
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 1) {
            Text(String(value)).font(.headline.weight(.bold))
            Text(label).font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private var receiverChoice: some View {
        VStack(spacing: 10) {
            Text("No-Ad Deciding Point")
                .font(.headline)
            Text("\(state.currentReceiver ?? "The receiver") chooses where to receive. The next point wins the game.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                courtButton("Deuce Court", side: "Right")
                courtButton("Ad Court", side: "Left")
            }
        }
        .padding(14)
        .background(activeGreen.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 12)
        .accessibilityIdentifier("tennis.noAdReceiverChoice")
    }

    private func courtButton(_ title: String, side: String) -> some View {
        Button(title) { onChooseReceiverCourt(side) }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(brandBlue)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private func fill(for shirt: String) -> Color {
        switch shirt.lowercased() {
        case "white": return Color(white: 0.88)
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "black": return .black
        default: return navy
        }
    }

    private func foreground(for shirt: String) -> Color {
        ["white", "yellow"].contains(shirt.lowercased()) ? .black : .white
    }
}
