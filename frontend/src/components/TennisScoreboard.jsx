import React, { useEffect, useMemo, useRef } from "react";

import { DEFAULT_PLAYER_SHIRT_COLORS, getPlayerShirtColor } from "../constants/playerShirtColors";

function participantName(participant) {
  return participant?.display_name
    || [participant?.first_name, participant?.surname].filter(Boolean).join(" ")
    || "Player";
}

function teamName(match, live, side) {
  const participants = live.tennis_teams?.[side] || [];
  if (participants.length) return participants.map(participantName).join(" / ");
  return side === "player1"
    ? [match.player1_name, match.player1_surname].filter(Boolean).join(" ")
    : [match.player2_name, match.player2_surname].filter(Boolean).join(" ");
}

function cardStyle(value) {
  const color = getPlayerShirtColor(value);
  return {
    "--tennis-team-bg": color.background,
    "--tennis-team-fg": color.foreground,
    "--tennis-team-border": color.border,
  };
}

function pointLabel(event, side) {
  const payload = event.payload || {};
  if (payload.tennis_game_completed || payload.game_completed) return "Game";
  return side === "player1"
    ? (payload.point_player1_score_label ?? payload.player1_score_label ?? payload.point_player1_score ?? "•")
    : (payload.point_player2_score_label ?? payload.player2_score_label ?? payload.point_player2_score ?? "•");
}

export default function TennisScoreboard({ match, disabled = false, onScorePoint, children }) {
  const timelineRef = useRef(null);
  const live = match?.state || {};
  const events = useMemo(
    () => (live.events || []).filter((event) => ["score_point", "stroke"].includes(event.event_type)
      && (event.payload?.scorer || event.payload?.player_side)),
    [live.events],
  );
  const isPadel = String(match?.sport || "").toLowerCase() === "padel";
  const complete = match?.status === "completed" || live.match_complete;
  const player1Name = teamName(match, live, "player1");
  const player2Name = teamName(match, live, "player2");
  const modeLabel = live.is_match_tiebreak
    ? "Final-set match tiebreak · First to 10, win by 2"
    : `${isPadel ? "Padel" : "Tennis"} · Best of ${live.best_of ?? match.best_of ?? 3} sets · First to 6 games`
      + (live.tennis_no_ad_scoring ? " · Golden Point" : " · Advantage")
      + (live.tennis_timed_breaks ? " · Timed breaks" : "");
  const pointMode = live.is_match_tiebreak ? "Match tiebreak" : (live.is_tie_break ? "Tiebreak" : "Points");
  const courtLabel = String(live.service_side || "Right").toLowerCase() === "left" ? "Ad court" : "Deuce court";

  useEffect(() => {
    if (timelineRef.current) timelineRef.current.scrollTop = timelineRef.current.scrollHeight;
  }, [events.length]);

  function scoreCard(side, name, shirtColor) {
    const point = side === "player1"
      ? (live.player1_score_label ?? live.player1_score ?? 0)
      : (live.player2_score_label ?? live.player2_score ?? 0);
    const games = side === "player1" ? (live.player1_set_games ?? 0) : (live.player2_set_games ?? 0);
    const sets = side === "player1" ? (live.player1_games_won ?? 0) : (live.player2_games_won ?? 0);
    const serving = live.current_server_side === side;

    return (
      <button
        aria-label={`Score point for ${name}`}
        className="tennis-team-card"
        data-testid={`tennis-score-${side}`}
        disabled={disabled || complete}
        style={cardStyle(shirtColor)}
        type="button"
        onClick={() => onScorePoint?.(side)}
      >
        <span className="tennis-team-card__name">{name}{serving ? <span aria-label="Serving" className="tennis-server-ball">●</span> : null}</span>
        <strong className="tennis-team-card__point">{point}</strong>
        <span className="tennis-team-card__stats"><span><b>{games}</b> Games</span><span><b>{sets}</b> Sets</span></span>
      </button>
    );
  }

  function participantLineup(side) {
    return (live.tennis_teams?.[side] || []).map((participant) => {
      const color = getPlayerShirtColor(participant.shirt_color);
      return (
        <span className="tennis-participant-chip" key={participant.id || participantName(participant)}>
          <span
            aria-hidden="true"
            className="tennis-participant-chip__shirt"
            style={{ background: color.background, borderColor: color.border }}
          />
          {participantName(participant)}
        </span>
      );
    });
  }

  return (
    <section className="scoreboard-card tennis-scoreboard" data-testid="tennis-scoreboard">
      <div className="tennis-format-banner">
        <span className="scoreboard-club-card__status-dot" aria-hidden="true" />
        <span>{modeLabel}</span>
      </div>

      {complete ? (
        <section className="tennis-completion-summary" data-testid="tennis-completion-summary">
          <span>{isPadel ? "Padel Match Complete" : "Tennis Match Complete"}</span>
          <strong>{live.winner_name || match.winner_name || "Result recorded"}</strong>
          <p>{live.player1_games_won ?? 0}–{live.player2_games_won ?? 0} sets</p>
        </section>
      ) : null}

      <div className="tennis-score-grid">
        {scoreCard("player1", player1Name, live.player1_shirt_color || match.player1_shirt_color || DEFAULT_PLAYER_SHIRT_COLORS.player1)}
        <div className="tennis-score-centre">
          <strong>{pointMode}</strong>
          <span>Set {live.current_game_number ?? 1}</span>
        </div>
        {scoreCard("player2", player2Name, live.player2_shirt_color || match.player2_shirt_color || DEFAULT_PLAYER_SHIRT_COLORS.player2)}
      </div>

      <div className="tennis-serve-status" data-testid="tennis-serve-status">
        <span><b>Serving:</b> {live.current_server || "Not set"}</span>
        <span><b>Receiving:</b> {live.current_receiver || "Not set"}</span>
        <span><b>Court:</b> {courtLabel}</span>
      </div>

      <div className="tennis-participant-lineups" aria-label="Player lineups">
        <div>{participantLineup("player1")}</div>
        <div>{participantLineup("player2")}</div>
      </div>

      {(live.game_history || []).length ? (
        <div className="tennis-set-history" aria-label="Completed sets">
          {(live.game_history || []).map((set, index) => (
            <span key={`${set.game_number || index}-${index}`}>
              Set {set.game_number || index + 1}: {set.player1_score}–{set.player2_score}
              {set.is_match_tiebreak ? ` (${set.player1_tiebreak_score}–${set.player2_tiebreak_score})` : ""}
            </span>
          ))}
        </div>
      ) : null}

      {events.length ? (
        <section className="tennis-point-timeline">
          <h3>Point timeline</h3>
          <div className="tennis-point-timeline__scroll" ref={timelineRef}>
            {events.map((event, index) => {
              const scorer = event.payload?.scorer || event.payload?.player_side;
              const gameCompleted = event.payload?.tennis_game_completed || event.payload?.game_completed;
              return (
                <React.Fragment key={event.id || `${event.created_at}-${index}`}>
                  <div className={`tennis-point-row tennis-point-row--${scorer}`}>
                    <span>{scorer === "player1" ? pointLabel(event, "player1") : ""}</span>
                    <span>{scorer === "player2" ? pointLabel(event, "player2") : ""}</span>
                  </div>
                  {gameCompleted ? (
                    <div className="tennis-game-divider">
                      <span />
                      <b>{event.payload?.completed_game_player1_games ?? "–"}–{event.payload?.completed_game_player2_games ?? "–"}</b>
                      <span />
                      {event.payload?.set_completed ? <em>Set complete</em> : null}
                    </div>
                  ) : null}
                </React.Fragment>
              );
            })}
          </div>
        </section>
      ) : null}

      {children ? <div className="scoreboard-controls">{children}</div> : null}
    </section>
  );
}
