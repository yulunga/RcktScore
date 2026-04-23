import React, { useEffect, useRef } from "react";

import {
  DEFAULT_PLAYER_SHIRT_COLORS,
  getPlayerShirtColor,
} from "../constants/playerShirtColors";

export default function Scoreboard({
  match,
  disabled = false,
  onScorePoint,
  onToggleServeSide,
  children,
}) {
  const pointStripRef = useRef(null);
  const live = match?.state ?? {};
  const player1Score = live.player1_score ?? 0;
  const player2Score = live.player2_score ?? 0;
  const bestOf = live.best_of ?? match?.best_of ?? 1;
  const player1GamesWon = live.player1_games_won ?? match?.player1_games_won ?? 0;
  const player2GamesWon = live.player2_games_won ?? match?.player2_games_won ?? 0;
  const currentGameNumber = live.current_game_number ?? match?.current_game_number ?? 1;
  const currentServerSide = live.current_server_side || "player1";
  const serviceSide = live.service_side || "Right";
  const player1ShirtColor = live.player1_shirt_color
    ?? match?.player1_shirt_color
    ?? DEFAULT_PLAYER_SHIRT_COLORS.player1;
  const player2ShirtColor = live.player2_shirt_color
    ?? match?.player2_shirt_color
    ?? DEFAULT_PLAYER_SHIRT_COLORS.player2;
  const isActive = (match?.status || "").toLowerCase() === "active";
  const gameHistory = live.game_history || [];
  const pointStripEntries = match ? buildPointStripEntries(live.events || []) : [];
  const canToggleServiceSide = match
    ? canCurrentServerChooseServiceSide(live.events || [], currentServerSide)
    : true;

  function splitName(name, surname) {
    return {
      firstName: (name || "").trim() || "Player",
      surname: (surname || "").trim(),
    };
  }

  function findServerBeforeEvent(events, eventIndex) {
    for (let index = eventIndex - 1; index >= 0; index -= 1) {
      const event = events[index];

      if (event.event_type === "server" && event.payload?.current_server_side) {
        return event.payload.current_server_side;
      }

      if (["score_point", "stroke"].includes(event.event_type) && event.payload?.current_server_side) {
        return event.payload.current_server_side;
      }
    }

    return "player1";
  }

  function canCurrentServerChooseServiceSide(events, serverSide) {
    let latestScoringEventIndex = -1;
    for (let index = events.length - 1; index >= 0; index -= 1) {
      if (["score_point", "stroke"].includes(events[index].event_type)) {
        latestScoringEventIndex = index;
        break;
      }
    }

    if (latestScoringEventIndex === -1) {
      return true;
    }

    const latestScoringEvent = events[latestScoringEventIndex];
    if (latestScoringEvent.payload?.game_completed && !latestScoringEvent.payload?.match_completed) {
      return true;
    }

    const previousServerSide = findServerBeforeEvent(events, latestScoringEventIndex);
    const scorerSide = latestScoringEvent.payload?.scorer || latestScoringEvent.payload?.player_side;
    const serverAfterRally = latestScoringEvent.payload?.current_server_side || scorerSide;

    if (serverAfterRally !== serverSide) {
      return true;
    }

    return scorerSide !== previousServerSide;
  }

  function serviceSideInitial(value) {
    return String(value || "").trim().charAt(0).toUpperCase();
  }

  function getWinnerScore(payload, winnerSide) {
    if (winnerSide === "player1") {
      return payload?.game_result?.player1_score ?? payload?.player1_score ?? "";
    }

    if (winnerSide === "player2") {
      return payload?.game_result?.player2_score ?? payload?.player2_score ?? "";
    }

    return "";
  }

  function buildPointStripEntries(events) {
    let runningServerSide = "player1";
    let runningServiceSide = "Right";
    const entries = [];

    events.forEach((event, index) => {
      const payload = event.payload || {};

      if (event.event_type === "match_started") {
        runningServerSide = payload.current_server_side || runningServerSide;
        runningServiceSide = payload.service_side || runningServiceSide;
        return;
      }

      if (event.event_type === "server") {
        runningServerSide = payload.current_server_side || runningServerSide;
        runningServiceSide = payload.service_side || runningServiceSide;
        return;
      }

      if (event.event_type === "serve_side") {
        runningServiceSide = payload.side || runningServiceSide;
        return;
      }

      if (!["score_point", "stroke"].includes(event.event_type)) {
        return;
      }

      const winnerSide = payload.scorer || payload.player_side;
      const eventGameNumber = payload.game_number ?? currentGameNumber;

      if (eventGameNumber === currentGameNumber) {
        entries.push({
          id: event.id || `${event.created_at}-${index}`,
          event_type: "scored_rally",
          rally_server_side: runningServerSide,
          rally_service_side: runningServiceSide,
          winner_side: winnerSide,
          winner_score: getWinnerScore(payload, winnerSide),
          created_at: event.created_at,
        });
      }

      runningServerSide = payload.current_server_side || winnerSide || runningServerSide;
      runningServiceSide = payload.service_side || runningServiceSide;
    });

    entries.push({
      id: "current-serve",
      event_type: "current_serve",
      current_server_side: currentServerSide,
      service_side: serviceSide,
    });

    return entries;
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
              className={`server-badge server-badge--${serviceSide.toLowerCase()}`}
              disabled={disabled || !canToggleServiceSide}
              type="button"
              onClick={onToggleServeSide}
              title={canToggleServiceSide ? "Choose service side" : "Service side is set by the previous rally"}
            >
              {serviceSide}
            </button>
          ) : (
            <span className="server-badge server-badge--placeholder" aria-hidden="true" />
          )}
        </div>
      </>
    );
  }

  function playerCardStyle(colorValue) {
    const color = getPlayerShirtColor(colorValue);
    return {
      "--player-card-bg": color.background,
      "--player-card-fg": color.foreground,
      "--player-card-border": color.border,
      "--player-card-score-border": color.scoreBorder || "rgba(255, 255, 255, 0.26)",
      "--player-card-score-bg": color.scoreBackground || "rgba(255, 255, 255, 0.14)",
    };
  }

  useEffect(() => {
    if (!pointStripRef.current) {
      return;
    }

    pointStripRef.current.scrollTop = pointStripRef.current.scrollHeight;
  }, [pointStripEntries.length]);

  if (!match) {
    return (
      <section className="scoreboard-card">
        <p className="notice">No live match is currently loaded.</p>
      </section>
    );
  }

  function renderPointMarker(side, markerType, active, label = "") {
    return (
      <span
        className={[
          "scoreboard-point-marker",
          `scoreboard-point-marker--${markerType}`,
          `scoreboard-point-marker--${side}`,
          active ? "scoreboard-point-marker--active" : "",
          active ? "" : "scoreboard-point-marker--inactive",
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
        <article
          className="player-card player-card--compact"
          style={playerCardStyle(player1ShirtColor)}
        >
          {renderPlayerCard("player1", match.player1_name, match.player1_surname)}
        </article>
        <div className="scoreboard-point-strip-wrap">
          <div ref={pointStripRef} className="scoreboard-point-strip" aria-label="Point order">
            {pointStripEntries.map((event, index) => {
              if (event.event_type === "current_serve") {
                const serverSide = event.current_server_side || "player1";
                const currentServiceSideLabel = serviceSideInitial(event.service_side);

                return (
                  <div
                    className="scoreboard-point-token scoreboard-point-token--current"
                    key={event.id || `current-serve-${index}`}
                    title={`Current serve: ${serverSide === "player1" ? "P1" : "P2"} ${currentServiceSideLabel}`}
                  >
                    <div className="scoreboard-point-row">
                      {renderPointMarker("player1", "server", serverSide === "player1", serverSide === "player1" ? currentServiceSideLabel : "")}
                      {renderPointMarker("player2", "server", serverSide === "player2", serverSide === "player2" ? currentServiceSideLabel : "")}
                    </div>
                  </div>
                );
              }

              const winnerSide = event.winner_side;
              const serverSide = event.rally_server_side || winnerSide;
              const serviceSideLabel = serviceSideInitial(event.rally_service_side);
              const winnerScore = event.winner_score;

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
              })}
          </div>
        </div>
        <article
          className="player-card player-card--compact"
          style={playerCardStyle(player2ShirtColor)}
        >
          {renderPlayerCard("player2", match.player2_name, match.player2_surname)}
        </article>
      </div>

      <div className="game-history-strip match-history-strip scoreboard-history-strip">
        {gameHistory.length === 0 ? (
          <div className="meta-item meta-item--compact">Playing</div>
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
