import React from "react";

export default function Scoreboard({
  match,
  disabled = false,
  onScorePoint,
  onToggleServeSide,
  children,
}) {
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
  const bestOf = live.best_of ?? match.best_of ?? 1;
  const player1GamesWon = live.player1_games_won ?? match.player1_games_won ?? 0;
  const player2GamesWon = live.player2_games_won ?? match.player2_games_won ?? 0;
  const currentGameNumber = live.current_game_number ?? match.current_game_number ?? 1;
  const currentServerSide = live.current_server_side;
  const serviceSide = live.service_side || "Right";
  const isActive = (match.status || "").toLowerCase() === "active";

  function splitName(name, surname) {
    return {
      firstName: (name || "").trim() || "Player",
      surname: (surname || "").trim(),
    };
  }

  function renderPlayerName(side, name, surname) {
    const isServing = currentServerSide === side;
    const playerName = splitName(name, surname);
    return (
      <div className="player-card-main">
        <div className="player-card-copy">
          <div className="player-name-stack">
            <h3>{playerName.firstName}</h3>
            {playerName.surname ? <h3>{playerName.surname}</h3> : null}
          </div>
          <div className="player-games">Games: {side === "player1" ? player1GamesWon : player2GamesWon}</div>
          {isServing ? (
            <button
              className="server-badge"
              disabled={disabled}
              type="button"
              onClick={onToggleServeSide}
            >
              Serve {serviceSide}
            </button>
          ) : null}
        </div>
        <button
          className="player-score player-score-button"
          disabled={disabled}
          type="button"
          onClick={() => onScorePoint?.(side)}
        >
          {side === "player1" ? player1Score : player2Score}
        </button>
      </div>
    );
  }

  return (
    <section className="scoreboard-card">
      <div className="scoreboard-header">
        <div>
          <h2 style={{ marginBottom: 6 }}>{match.court_name || "Court"}</h2>
          <span className={`status-pill${isActive ? " status-pill--active" : ""}`}>{match.status || "active"}</span>
        </div>
        <div className="score-series-chip">
          Score to {match.score_type} • Game {currentGameNumber} • Best of {bestOf}
        </div>
      </div>

      <div className="scoreboard-grid">
        <article className="player-card player-card--compact">
          {renderPlayerName("player1", match.player1_name, match.player1_surname)}
        </article>
        <article className="player-card player-card--compact">
          {renderPlayerName("player2", match.player2_name, match.player2_surname)}
        </article>
      </div>

      {children ? <div className="scoreboard-controls">{children}</div> : null}
    </section>
  );
}
