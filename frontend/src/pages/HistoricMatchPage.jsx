import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { getScore } from "../services/api";

const HISTORY_EVENT_TYPES = new Set(["score_point", "stroke", "let"]);

function parseDate(value) {
  if (!value) {
    return null;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function formatDate(value) {
  const date = parseDate(value);
  return date
    ? new Intl.DateTimeFormat("en-GB", { dateStyle: "medium" }).format(date)
    : "Not available";
}

function formatTime(value) {
  const date = parseDate(value);
  return date
    ? new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit" }).format(date)
    : "Not available";
}

function formatDuration(value) {
  const totalSeconds = Math.max(0, Number(value) || 0);
  const minutes = String(Math.floor(totalSeconds / 60)).padStart(2, "0");
  const seconds = String(Math.floor(totalSeconds % 60)).padStart(2, "0");
  return `${minutes}:${seconds}`;
}

function fullName(firstName, surname) {
  return [firstName, surname].filter(Boolean).join(" ") || "Unknown player";
}

function sportName(value) {
  const names = {
    squash: "Squash",
    racketball: "Racketball",
    tennis: "Tennis",
    padel: "Padel",
    table_tennis: "Table Tennis",
    badminton: "Badminton",
    pickleball: "Pickleball",
  };
  return names[String(value || "squash").toLowerCase()] || "Squash";
}

function payloadValue(payload, snakeName, camelName) {
  return payload?.[snakeName] ?? payload?.[camelName];
}

function eventGameNumber(event) {
  return Number(payloadValue(event.payload, "game_number", "gameNumber") || 1);
}

function eventWinnerSide(event) {
  return payloadValue(event.payload, "scorer", "scorer")
    || payloadValue(event.payload, "player_side", "playerSide")
    || null;
}

function tennisScore(event) {
  const payload = event.payload || {};
  const player1Label = payloadValue(payload, "point_player1_score_label", "pointPlayer1ScoreLabel");
  const player2Label = payloadValue(payload, "point_player2_score_label", "pointPlayer2ScoreLabel");
  if (player1Label != null && player2Label != null) {
    return `${player1Label}–${player2Label}`;
  }

  const player1 = payloadValue(payload, "point_player1_score", "pointPlayer1Score");
  const player2 = payloadValue(payload, "point_player2_score", "pointPlayer2Score");
  if (player1 == null || player2 == null) {
    return null;
  }
  if (payloadValue(payload, "is_tie_break", "isTieBreak")) {
    return `${player1}–${player2}`;
  }
  if (player1 >= 3 && player2 >= 3) {
    if (player1 === player2) {
      return "Deuce";
    }
    return player1 > player2 ? "Ad–40" : "40–Ad";
  }
  const labels = ["0", "15", "30", "40"];
  return `${labels[Math.min(player1, 3)]}–${labels[Math.min(player2, 3)]}`;
}

function racketScore(event) {
  const payload = event.payload || {};
  const gameResult = payloadValue(payload, "game_result", "gameResult");
  const player1 = gameResult?.player1_score ?? gameResult?.player1Score
    ?? payloadValue(payload, "player1_score", "player1Score");
  const player2 = gameResult?.player2_score ?? gameResult?.player2Score
    ?? payloadValue(payload, "player2_score", "player2Score");
  return player1 == null || player2 == null ? null : `${player1}–${player2}`;
}

function participantName(participant) {
  return participant?.display_name
    || participant?.displayName
    || fullName(participant?.first_name || participant?.firstName, participant?.surname);
}

function teamNames(match, side) {
  const participants = match?.state?.tennis_teams?.[side] || [];
  if (participants.length) {
    return participants.map(participantName).join(" & ");
  }
  return side === "player2"
    ? fullName(match?.player2_name, match?.player2_surname)
    : fullName(match?.player1_name, match?.player1_surname);
}

function segmentDuration(entries) {
  const timestamps = entries.map((entry) => parseDate(entry.created_at)).filter(Boolean);
  if (timestamps.length < 2) {
    return 0;
  }
  return Math.max(0, Math.floor((timestamps.at(-1).getTime() - timestamps[0].getTime()) / 1000));
}

function resultForSegment(gameHistory, number) {
  return gameHistory.find((result) => Number(result.game_number ?? result.gameNumber) === number) || null;
}

function courtName(match) {
  return [match?.court_name, match?.court_alias]
    .filter((value, index, values) => value && values.findIndex(
      (candidate) => String(candidate || "").toLowerCase() === String(value).toLowerCase(),
    ) === index)
    .join(" • ") || "Not available";
}

export default function HistoricMatchPage() {
  const { matchId } = useParams();
  const navigate = useNavigate();
  const [match, setMatch] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [showMatchInformation, setShowMatchInformation] = useState(false);
  const [showDurations, setShowDurations] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError("");

    getScore(matchId)
      .then((payload) => {
        if (!cancelled) {
          setMatch(payload.match || payload);
        }
      })
      .catch((requestError) => {
        if (!cancelled) {
          setError(requestError.message || "Unable to load the historic match.");
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [matchId]);

  const live = match?.state || {};
  const tennisStyle = ["tennis", "padel"].includes(String(match?.sport || "").toLowerCase())
    || String(live.score_display_mode || "").toLowerCase() === "tennis";
  const segmentLabel = tennisStyle ? "Set" : "Game";
  const player1Name = teamNames(match, "player1");
  const player2Name = teamNames(match, "player2");
  const gameHistory = live.game_history || [];
  const startEvent = (live.events || []).find((event) => event.event_type === "match_started");
  const startedAt = startEvent?.created_at || match?.created_at;

  const segments = useMemo(() => {
    const grouped = new Map();
    (live.events || [])
      .filter((event) => HISTORY_EVENT_TYPES.has(event.event_type))
      .forEach((event) => {
        const number = eventGameNumber(event);
        grouped.set(number, [...(grouped.get(number) || []), event]);
      });

    gameHistory.forEach((result) => {
      const number = Number(result.game_number ?? result.gameNumber ?? 1);
      if (!grouped.has(number)) {
        grouped.set(number, []);
      }
    });

    return [...grouped.entries()]
      .sort(([left], [right]) => left - right)
      .map(([number, entries]) => ({
        number,
        entries: [...entries].sort((left, right) => String(left.created_at || "").localeCompare(String(right.created_at || ""))),
        result: resultForSegment(gameHistory, number),
        duration: segmentDuration(entries),
      }));
  }, [gameHistory, live.events]);

  const recordedDuration = Number(match?.match_duration_seconds ?? live.match_duration_seconds ?? 0);
  const derivedDuration = segments.reduce((total, segment) => total + segment.duration, 0);
  const matchDuration = Math.max(0, recordedDuration, derivedDuration);
  const bestOf = live.best_of ?? match?.best_of ?? 1;
  const scoreType = live.score_type ?? match?.score_type ?? 15;
  const noAd = Boolean(live.tennis_no_ad_scoring ?? match?.tennis_no_ad_scoring);
  const handicapEnabled = Boolean(live.handicap?.enabled ?? match?.handicap_enabled);
  const player1Offset = live.handicap?.player1_offset ?? match?.player1_offset ?? 0;
  const player2Offset = live.handicap?.player2_offset ?? match?.player2_offset ?? 0;
  const gameDetails = tennisStyle
    ? `Best of ${bestOf} sets • ${noAd ? "Golden Point" : "Advantage scoring"}`
    : `${handicapEnabled ? `Handicap ${player1Offset} | ${player2Offset}` : "No handicap"} • Best of ${bestOf} games • PAR-${scoreType}`;
  const player1GamesWon = Number(live.player1_games_won ?? match?.player1_games_won ?? 0);
  const player2GamesWon = Number(live.player2_games_won ?? match?.player2_games_won ?? 0);
  const winnerSide = match?.winner_side
    || live.winner_side
    || (player1GamesWon === player2GamesWon ? "" : (player1GamesWon > player2GamesWon ? "player1" : "player2"));

  function winnerName(side) {
    return side === "player2" ? player2Name : player1Name;
  }

  function segmentScore(segment) {
    if (!segment.result) {
      return null;
    }
    return `${segment.result.player1_score ?? segment.result.player1Score}–${segment.result.player2_score ?? segment.result.player2Score}`;
  }

  function completedGamesScore(segmentNumber) {
    const completed = gameHistory.filter(
      (result) => Number(result.game_number ?? result.gameNumber) <= segmentNumber,
    );
    const player1Games = completed.filter(
      (result) => Number(result.player1_score ?? result.player1Score) > Number(result.player2_score ?? result.player2Score),
    ).length;
    const player2Games = completed.filter(
      (result) => Number(result.player2_score ?? result.player2Score) > Number(result.player1_score ?? result.player1Score),
    ).length;
    return `${player1Games}–${player2Games}`;
  }

  return (
    <main className="page-shell stack historic-match-page" data-testid="historic-match-page">
      <ClubPageHeader />

      {loading ? <div className="notice">Loading historic match...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {match ? (
        <>
          <section className="panel historic-match-summary" aria-label="Match result">
            <div className={`historic-match-summary__player${winnerSide === "player1" ? " is-winner" : ""}`}>
              <strong>{player1Name}</strong>
              <span>{player1GamesWon}</span>
            </div>
            <div className={`historic-match-summary__player${winnerSide === "player2" ? " is-winner" : ""}`}>
              <strong>{player2Name}</strong>
              <span>{player2GamesWon}</span>
            </div>
          </section>

          <section className={`panel stack historic-match-section historic-match-information${showMatchInformation ? " is-expanded" : ""}`}>
            <button
              aria-expanded={showMatchInformation}
              aria-label={showMatchInformation ? "Collapse match information" : "Expand match information"}
              className="historic-match-disclosure"
              type="button"
              onClick={() => setShowMatchInformation((current) => !current)}
            >
              <strong>Match Information</strong>
              <span aria-hidden="true">{showMatchInformation ? "⌃" : "⌄"}</span>
            </button>
            {showMatchInformation ? (
              <div className="historic-match-meta-grid" data-testid="historic-match-information">
                <div><span>Sport</span><strong>{sportName(match.sport)}</strong></div>
                <div><span>Game Details</span><strong>{gameDetails}</strong></div>
                <div><span>Date</span><strong>{formatDate(startedAt)}</strong></div>
                <div><span>Started</span><strong>{formatTime(startedAt)}</strong></div>
                <div><span>Court</span><strong>{courtName(match)}</strong></div>
                <div><span>Referee</span><strong>{match.referee_name || "Not added"}</strong></div>
              </div>
            ) : null}
          </section>

          <section className="panel stack historic-match-time-card">
            <button
              aria-expanded={showDurations}
              className="historic-match-time-toggle"
              type="button"
              onClick={() => setShowDurations((current) => !current)}
            >
              <span><small>Match Time</small><strong>{formatDuration(matchDuration)}</strong></span>
              <span aria-hidden="true">{showDurations ? "−" : "+"}</span>
            </button>
            {showDurations ? (
              <div className="historic-match-duration-grid" data-testid="historic-segment-durations">
                {segments.map((segment) => (
                  <div key={segment.number}>
                    <span>{segmentLabel} {segment.number}</span>
                    <strong>{formatDuration(segment.duration)}</strong>
                  </div>
                ))}
              </div>
            ) : null}
          </section>

          <section className="panel stack historic-match-section">
            <h2>Point Timeline</h2>
            {segments.length === 0 ? (
              <p className="helper-text">No point history is available for this match.</p>
            ) : (
              <div className="historic-timeline">
                {segments.map((segment) => (
                  <article className="historic-timeline-segment" key={segment.number}>
                    <header>
                      <strong>{segmentLabel} {segment.number}</strong>
                    </header>
                    <div className="historic-timeline-players">
                      <span>{player1Name}</span>
                      <strong>{segmentScore(segment) || ""}</strong>
                      <span>{player2Name}</span>
                    </div>
                    <div className="historic-timeline-points">
                      {segment.entries.map((event) => {
                        const payload = event.payload || {};
                        const side = eventWinnerSide(event);
                        const gameCompleted = Boolean(payloadValue(payload, "tennis_game_completed", "tennisGameCompleted"));
                        const setCompleted = Boolean(payloadValue(payload, "set_completed", "setCompleted"));
                        const matchCompleted = Boolean(payloadValue(payload, "match_completed", "matchCompleted"));
                        const completedGames = [
                          payloadValue(payload, "completed_game_player1_games", "completedGamePlayer1Games"),
                          payloadValue(payload, "completed_game_player2_games", "completedGamePlayer2Games"),
                        ];
                        const serviceSide = payloadValue(payload, "point_service_side", "pointServiceSide")
                          || payloadValue(payload, "service_side", "serviceSide");
                        const serverSide = payloadValue(payload, "point_server_side", "pointServerSide")
                          || payloadValue(payload, "current_server_side", "currentServerSide");
                        const score = tennisStyle ? tennisScore(event) : racketScore(event);
                        const serviceLabel = String(serviceSide || "").slice(0, 1).toUpperCase();
                        return (
                          <React.Fragment key={event.id || `${event.created_at}-${side}`}>
                            <div className={`historic-point historic-point--${tennisStyle ? "tennis" : "racket"}`}>
                              {tennisStyle ? (
                                <>
                                  <div className="historic-point__detail">
                                    <strong>{winnerName(side)}</strong>
                                    <time>{formatTime(event.created_at)}</time>
                                  </div>
                                  {score ? <b className={`historic-point__tennis-score historic-point__tennis-score--${side}`}>{score}</b> : null}
                                </>
                              ) : (
                                <>
                                  <div className="historic-point__rail historic-point__rail--left">
                                    {side === "player1" ? (
                                      <>
                                        {serverSide === "player1" && serviceLabel ? <span className="historic-point__serve">{serviceLabel}</span> : null}
                                        {score ? <b className="historic-point__score historic-point__score--player1">{score}</b> : null}
                                      </>
                                    ) : null}
                                  </div>
                                  <div className="historic-point__detail">
                                    <strong>{winnerName(side)}</strong>
                                    <time>{formatTime(event.created_at)}</time>
                                  </div>
                                  <div className="historic-point__rail historic-point__rail--right">
                                    {side === "player2" ? (
                                      <>
                                        {score ? <b className="historic-point__score historic-point__score--player2">{score}</b> : null}
                                        {serverSide === "player2" && serviceLabel ? <span className="historic-point__serve">{serviceLabel}</span> : null}
                                      </>
                                    ) : null}
                                  </div>
                                </>
                              )}
                            </div>
                            {tennisStyle && gameCompleted ? (
                              <div className="historic-completion-divider historic-completion-divider--game" data-testid="historic-game-divider">
                                <small>{matchCompleted ? "Game, Set and Match" : "Game"}</small>
                                <strong>{winnerName(side)}</strong>
                                {completedGames.every((value) => value != null) ? <span>{completedGames.join("–")}</span> : null}
                              </div>
                            ) : null}
                            {tennisStyle && setCompleted && !matchCompleted ? (
                              <div className="historic-completion-divider historic-completion-divider--set" data-testid="historic-set-divider">
                                <small>Set</small>
                                <strong>{winnerName(side)}</strong>
                                {segmentScore(segment) ? <span>{segmentScore(segment)}</span> : null}
                              </div>
                            ) : null}
                          </React.Fragment>
                        );
                      })}
                    </div>
                    {!tennisStyle && segment.result ? (
                      <div className="historic-games-divider" data-testid="historic-games-divider">
                        Games {completedGamesScore(segment.number)}
                      </div>
                    ) : null}
                  </article>
                ))}
              </div>
            )}
          </section>

          <button className="match-bottom-back-button" type="button" onClick={() => navigate("/history")}>Back to History</button>
        </>
      ) : null}
      <AppFooter />
    </main>
  );
}
