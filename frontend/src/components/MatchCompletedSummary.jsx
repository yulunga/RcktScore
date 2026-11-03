import React, { useMemo } from "react";

function formatDuration(value) {
  const seconds = Math.max(0, Math.floor(Number(value) || 0));
  return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}

function fullName(firstName, surname) {
  const first = String(firstName || "").trim();
  const last = String(surname || "").trim();
  if (!first) return last || "Player";
  if (!last || first.split(/\s+/).at(-1)?.toLowerCase() === last.toLowerCase()) return first;
  return `${first} ${last}`;
}

function teamName(match, side) {
  const participants = match?.state?.tennis_teams?.[side] || [];
  if (participants.length) {
    return participants
      .map((participant) => participant.display_name || fullName(participant.first_name, participant.surname))
      .join(" / ");
  }
  return side === "player2"
    ? fullName(match?.player2_name, match?.player2_surname)
    : fullName(match?.player1_name, match?.player1_surname);
}

function eventGameNumber(event) {
  return Number(event?.payload?.game_number || event?.payload?.completed_game_number || 1);
}

function buildGameRows(match) {
  const live = match?.state || {};
  const events = live.events || [];
  const history = [...(live.game_history || [])];
  const scoringEvents = events.filter((event) => ["score_point", "stroke"].includes(event.event_type));
  const startedAt = new Date(events.find((event) => event.event_type === "match_started")?.created_at || match?.created_at || 0).getTime();
  let previousEnd = Number.isFinite(startedAt) ? startedAt : null;

  const rows = history.map((game, index) => {
    const number = Number(game.game_number || index + 1);
    const gameEvents = scoringEvents.filter((event) => eventGameNumber(event) === number);
    const lastTimestamp = new Date(gameEvents.at(-1)?.created_at || 0).getTime();
    const firstTimestamp = new Date(gameEvents[0]?.created_at || 0).getTime();
    const start = previousEnd ?? (Number.isFinite(firstTimestamp) ? firstTimestamp : null);
    const duration = Number(game.duration_seconds)
      || (start != null && Number.isFinite(lastTimestamp) ? Math.max(0, Math.floor((lastTimestamp - start) / 1000)) : 0);
    if (Number.isFinite(lastTimestamp)) previousEnd = lastTimestamp;
    return {
      number,
      player1: Number(game.player1_score ?? 0),
      player2: Number(game.player2_score ?? 0),
      duration,
    };
  });

  if (live.ended_early && !rows.some((row) => row.number === Number(live.current_game_number || 1))) {
    const number = Number(live.current_game_number || rows.length + 1);
    const gameEvents = scoringEvents.filter((event) => eventGameNumber(event) === number);
    const lastTimestamp = new Date(gameEvents.at(-1)?.created_at || match?.completed_at || 0).getTime();
    rows.push({
      number,
      player1: Number(live.player1_score || 0),
      player2: Number(live.player2_score || 0),
      duration: previousEnd != null && Number.isFinite(lastTimestamp)
        ? Math.max(0, Math.floor((lastTimestamp - previousEnd) / 1000))
        : 0,
    });
  }

  return rows;
}

function buildServeStats(events) {
  let server = "player1";
  const stats = {
    player1: { won: 0, lost: 0 },
    player2: { won: 0, lost: 0 },
  };

  (events || []).forEach((event) => {
    const payload = event.payload || {};
    if (["match_started", "server"].includes(event.event_type)) {
      server = payload.current_server_side || server;
      return;
    }
    if (!["score_point", "stroke"].includes(event.event_type)) return;
    const scorer = payload.scorer || payload.player_side;
    if (server in stats && scorer) {
      if (scorer === server) stats[server].won += 1;
      else stats[server].lost += 1;
    }
    server = payload.current_server_side || scorer || server;
  });
  return stats;
}

export default function MatchCompletedSummary({ match, personalPlus = false, onClose }) {
  const live = match?.state || {};
  const player1Name = teamName(match, "player1");
  const player2Name = teamName(match, "player2");
  const player1Games = Number(live.player1_games_won ?? match?.player1_games_won ?? 0);
  const player2Games = Number(live.player2_games_won ?? match?.player2_games_won ?? 0);
  const rows = useMemo(() => buildGameRows(match), [match]);
  const serveStats = useMemo(() => buildServeStats(live.events), [live.events]);
  const recordedDuration = Number(live.match_duration_seconds ?? match?.match_duration_seconds ?? 0);
  const totalDuration = Math.max(recordedDuration, rows.reduce((total, row) => total + row.duration, 0));
  const tennisStyle = ["tennis", "padel"].includes(String(match?.sport || "").toLowerCase());
  const unit = tennisStyle ? "Set" : "Game";
  const endedEarly = Boolean(live.ended_early ?? match?.ended_early);
  const winnerSide = endedEarly && !live.winner_side && !match?.winner_side
    ? null
    : (live.winner_side
      ?? match?.winner_side
      ?? (player1Games === player2Games ? null : (player1Games > player2Games ? "player1" : "player2")));
  const resultLabel = winnerSide === "player1"
    ? `${player1Name} wins`
    : winnerSide === "player2"
      ? `${player2Name} wins`
      : "Draw / no winner";

  return (
    <main className="match-completed-page" data-testid="match-completed-summary">
      <section className="match-completed-card">
        <button aria-label="Close completed match" className="match-completed-close" type="button" onClick={onClose}>&times;</button>
        <div className="match-completed-heading">
          <span>{endedEarly ? "MATCH ENDED" : "MATCH COMPLETED"}</span>
          <h1>{resultLabel}</h1>
          <p>Total time {formatDuration(totalDuration)}</p>
        </div>

        <div className="match-completed-score" aria-label="Final match score">
          <div><strong>{player1Name}</strong><b>{player1Games}</b><small>{unit}s won</small></div>
          <span>–</span>
          <div><strong>{player2Name}</strong><b>{player2Games}</b><small>{unit}s won</small></div>
        </div>

        <section className="match-completed-games">
          <h2>{unit} summary</h2>
          {rows.length ? rows.map((row) => (
            <div className="match-completed-game-row" key={`${unit}-${row.number}`}>
              <strong>{unit} {row.number}</strong>
              <span>{row.player1}–{row.player2}</span>
              <small>{formatDuration(row.duration)}</small>
            </div>
          )) : <p className="helper-text">No completed {unit.toLowerCase()} details were recorded.</p>}
        </section>

        {personalPlus ? (
          <section className="match-completed-serve-stats">
            <h2>Serve performance</h2>
            <div><strong>{player1Name}</strong><span>{serveStats.player1.won} won on serve</span><span>{serveStats.player1.lost} serves lost</span></div>
            <div><strong>{player2Name}</strong><span>{serveStats.player2.won} won on serve</span><span>{serveStats.player2.lost} serves lost</span></div>
          </section>
        ) : null}
      </section>
    </main>
  );
}
