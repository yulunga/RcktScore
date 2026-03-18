import React from "react";

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
  const bestOf = live.best_of ?? match.best_of ?? 1;
  const gamesToWin = live.games_to_win ?? match.games_to_win ?? 1;
  const player1GamesWon = live.player1_games_won ?? match.player1_games_won ?? 0;
  const player2GamesWon = live.player2_games_won ?? match.player2_games_won ?? 0;
  const currentGameNumber = live.current_game_number ?? match.current_game_number ?? 1;
  const currentServerSide = live.current_server_side;
  const serviceSide = live.service_side || "Right";
  const gameHistory = live.game_history || [];

  function renderPlayerName(side, name) {
    const isServing = currentServerSide === side;
    return (
      <div className="player-name-row">
        <h3>{name}</h3>
        {isServing ? (
          <span className="server-badge">
            Serve {serviceSide}
          </span>
        ) : null}
      </div>
    );
  }

  return (
    <section className="scoreboard-card">
      <div className="scoreboard-header">
        <div>
          <h2 style={{ marginBottom: 6 }}>{match.court_name || "Court"}</h2>
          <span className="status-pill">{match.status || "active"}</span>
        </div>
        <div className="stack compact scoreboard-header-meta">
          <div className="timer-chip">Score to {match.score_type}</div>
          <div className="score-series-chip">
            Game {currentGameNumber} • Best of {bestOf} • First to {gamesToWin}
          </div>
        </div>
      </div>

      <div className="scoreboard-grid">
        <article className="player-card">
          {renderPlayerName("player1", match.player1_name)}
          <div className="player-score">{player1Score}</div>
          <div className="player-games">Games won: {player1GamesWon}</div>
        </article>
        <article className="player-card">
          {renderPlayerName("player2", match.player2_name)}
          <div className="player-score">{player2Score}</div>
          <div className="player-games">Games won: {player2GamesWon}</div>
        </article>
      </div>

      <div className="meta-grid">
        <div className="meta-item">
          <strong>Server</strong>
          <div>{live.current_server || "Not set"}</div>
        </div>
        <div className="meta-item">
          <strong>Service Side</strong>
          <div>{serviceSide}</div>
        </div>
        <div className="meta-item">
          <strong>Referee</strong>
          <div>{match.referee_name || "TBC"}</div>
        </div>
        <div className="meta-item">
          <strong>Match Format</strong>
          <div>Best of {bestOf}</div>
        </div>
      </div>

      <div className="game-history-strip">
        {gameHistory.length === 0 ? (
          <div className="meta-item">No completed games yet.</div>
        ) : (
          gameHistory.map((game) => (
            <div className="meta-item" key={`game-${game.game_number}`}>
              <strong>Game {game.game_number}</strong>
              <div>
                {game.player1_score} - {game.player2_score}
              </div>
              <div>{game.winner_name}</div>
            </div>
          ))
        )}
      </div>
    </section>
  );
}
