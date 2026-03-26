import React, { useEffect, useRef } from "react";

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
  const pointStripRef = useRef(null);
  const pointEvents = (live.events || []).filter((event) => {
    if (!["score_point", "stroke"].includes(event.event_type)) {
      return false;
    }

    const eventGameNumber = event.payload?.game_number;
    return eventGameNumber === currentGameNumber;
  });
  const gameHistory = live.game_history || [];

  function splitName(name, surname) {
    return {
      firstName: (name || "").trim() || "Player",
      surname: (surname || "").trim(),
    };
  }

  function renderPlayerCard(side, name, surname) {
    const isServing = currentServerSide === side;
    const playerName = splitName(name, surname);
    return (
      <>
        <button
          className="player-card-action"
          disabled={disabled}
          type="button"
          onClick={() => onScorePoint?.(side)}
        >
          <div className="player-card-main">
            <div className="player-card-copy">
              <div className="player-name-stack">
                <h3>{playerName.firstName}</h3>
                {playerName.surname ? <h3>{playerName.surname}</h3> : null}
              </div>
              <div className="player-score player-score-button">
                {side === "player1" ? player1Score : player2Score}
              </div>
              <div className="player-games">Games: {side === "player1" ? player1GamesWon : player2GamesWon}</div>
            </div>
          </div>
        </button>
        <div className="server-badge-slot">
          {isServing ? (
            <button
              className="server-badge"
              disabled={disabled}
              type="button"
              onClick={onToggleServeSide}
            >
              Serve {serviceSide}
            </button>
          ) : (
            <span className="server-badge server-badge--placeholder" aria-hidden="true" />
          )}
        </div>
      </>
    );
  }

  useEffect(() => {
    if (!pointStripRef.current) {
      return;
    }

    pointStripRef.current.scrollTop = pointStripRef.current.scrollHeight;
  }, [pointEvents.length]);

  function renderPointMarker(side, markerType, active, label = "") {
    return (
      <span
        className={[
          "scoreboard-point-marker",
          `scoreboard-point-marker--${markerType}`,
          `scoreboard-point-marker--${side}`,
          active ? "scoreboard-point-marker--active" : "",
        ].join(" ").trim()}
      >
        {label}
      </span>
    );
  }

  return (
    <section className="scoreboard-card">
      <div className="scoreboard-header">
        <div>
          <h2 style={{ marginBottom: 0 }}>{match.court_name || "Court"}</h2>
        </div>
        <div className="scoreboard-header-meta">
          <span className={`status-pill${isActive ? " status-pill--active" : ""}`}>
            <span className="status-pill__dot" aria-hidden="true" />
            {match.status || "active"}
          </span>
          <div className="score-series-chip">
            Score to {match.score_type} • Game {currentGameNumber} • Best of {bestOf}
          </div>
        </div>
      </div>

      <div className="scoreboard-grid">
        <article className="player-card player-card--compact">
          {renderPlayerCard("player1", match.player1_name, match.player1_surname)}
        </article>
        <div className="scoreboard-point-strip-wrap">
          <div ref={pointStripRef} className="scoreboard-point-strip" aria-label="Point order">
            {pointEvents.length === 0 ? (
              <div className="scoreboard-point-empty">No points yet</div>
            ) : (
              pointEvents.map((event, index) => {
                const winnerSide = event.payload?.scorer || event.payload?.player_side;
                const serverSide = event.payload?.current_server_side || winnerSide;
                const serviceSideLabel = String(event.payload?.service_side || "").trim().charAt(0).toUpperCase();
                const winnerScore = winnerSide === "player1"
                  ? (event.payload?.game_result?.player1_score ?? event.payload?.player1_score ?? "")
                  : (event.payload?.game_result?.player2_score ?? event.payload?.player2_score ?? "");

                return (
                  <div
                    className="scoreboard-point-token"
                    key={event.id || `${event.created_at}-${index}`}
                    title={`Serve: ${serverSide === "player1" ? "P1" : "P2"} • Point: ${winnerSide === "player1" ? "P1" : "P2"}`}
                  >
                    <div className="scoreboard-point-row">
                      {renderPointMarker("player1", "server", serverSide === "player1", serverSide === "player1" ? serviceSideLabel : "")}
                      {renderPointMarker("player2", "server", serverSide === "player2", serverSide === "player2" ? serviceSideLabel : "")}
                    </div>
                    <div className="scoreboard-point-row">
                      {renderPointMarker("player1", "winner", winnerSide === "player1", winnerSide === "player1" ? String(winnerScore) : "")}
                      {renderPointMarker("player2", "winner", winnerSide === "player2", winnerSide === "player2" ? String(winnerScore) : "")}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
        <article className="player-card player-card--compact">
          {renderPlayerCard("player2", match.player2_name, match.player2_surname)}
        </article>
      </div>

      <div className="game-history-strip match-history-strip scoreboard-history-strip">
        {gameHistory.length === 0 ? (
          <div className="meta-item meta-item--compact">No completed games yet.</div>
        ) : (
          gameHistory.map((game) => (
            <div className="meta-item meta-item--compact" key={`scoreboard-game-${game.game_number}`}>
              <div>
                {game.player1_score} - {game.player2_score}
              </div>
              <div>{game.winner_name}</div>
            </div>
          ))
        )}
      </div>

      {children ? <div className="scoreboard-controls">{children}</div> : null}
    </section>
  );
}
