export default function Scoreboard({ match }) {
  if (!match) {
    return (
      <section className="scoreboard-card">
        <p className="notice">No live match is currently loaded.</p>
      </section>
    );
  }

  const live = match.state ?? {};
  const player1Score = live.player1_score ?? 0;
  const player2Score = live.player2_score ?? 0;

  return (
    <section className="scoreboard-card">
      <div className="scoreboard-header">
        <div>
          <h2 style={{ marginBottom: 6 }}>{match.court_name || "Court"}</h2>
          <span className="status-pill">{match.status || "active"}</span>
        </div>
        <div className="timer-chip">Score to {match.score_type}</div>
      </div>

      <div className="scoreboard-grid">
        <article className="player-card">
          <h3>{match.player1_name}</h3>
          <div className="player-score">{player1Score}</div>
        </article>
        <article className="player-card">
          <h3>{match.player2_name}</h3>
          <div className="player-score">{player2Score}</div>
        </article>
      </div>

      <div className="meta-grid">
        <div className="meta-item">
          <strong>Server</strong>
          <div>{live.current_server || "Not set"}</div>
        </div>
        <div className="meta-item">
          <strong>Service Side</strong>
          <div>{live.service_side || "Right"}</div>
        </div>
        <div className="meta-item">
          <strong>Referee</strong>
          <div>{match.referee_name || "TBC"}</div>
        </div>
      </div>
    </section>
  );
}
