import React, { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import { getWatchedMatch, saveWatchedMatch } from "../services/api";

const SCORING_EVENT_TYPES = new Set(["score_point", "stroke", "let"]);

function fullName(firstName, surname) {
  return [firstName, surname].filter(Boolean).join(" ") || "Player";
}

function formatSport(value) {
  return String(value || "Match").replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function formatTime(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit" }).format(date);
}

function eventScore(event, tennisStyle) {
  const payload = event?.payload || {};
  if (tennisStyle) {
    const left = payload.point_player1_score_label ?? payload.point_player1_score;
    const right = payload.point_player2_score_label ?? payload.point_player2_score;
    return left == null || right == null ? "" : `${left}–${right}`;
  }
  const left = payload.player1_score ?? payload.game_result?.player1_score;
  const right = payload.player2_score ?? payload.game_result?.player2_score;
  return left == null || right == null ? "" : `${left}–${right}`;
}

export default function RemoteMatchPage() {
  const { watchCode = "" } = useParams();
  const navigate = useNavigate();
  const { session } = useAuth();
  const [watch, setWatch] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const loadWatch = useCallback(async ({ silent = false } = {}) => {
    if (!session?.organization_id || !watchCode) return;
    if (!silent) setLoading(true);
    try {
      const response = await getWatchedMatch({ organization_id: session.organization_id, code: watchCode });
      setWatch(response.watch || null);
      setError("");
    } catch (requestError) {
      setError(requestError.message || "Unable to open this match.");
    } finally {
      if (!silent) setLoading(false);
    }
  }, [session?.organization_id, watchCode]);

  useEffect(() => {
    loadWatch();
  }, [loadWatch]);

  useEffect(() => {
    if (!watch || watch.finished) return undefined;
    const intervalId = window.setInterval(() => loadWatch({ silent: true }), 5000);
    return () => window.clearInterval(intervalId);
  }, [loadWatch, watch?.finished]);

  async function handleSave() {
    setSaving(true);
    setError("");
    try {
      const response = await saveWatchedMatch({ organization_id: session.organization_id, code: watchCode });
      setWatch(response.watch || watch);
    } catch (requestError) {
      setError(requestError.message || "Unable to add this match to your profile.");
    } finally {
      setSaving(false);
    }
  }

  const match = watch?.match;
  const live = match?.state || {};
  const tennisStyle = ["tennis", "padel"].includes(String(match?.sport || "").toLowerCase());
  const player1Name = fullName(match?.player1_name, match?.player1_surname);
  const player2Name = fullName(match?.player2_name, match?.player2_surname);
  const player1Games = Number(live.player1_games_won ?? match?.player1_games_won ?? 0);
  const player2Games = Number(live.player2_games_won ?? match?.player2_games_won ?? 0);
  const player1Points = live.player1_score_label ?? live.player1_score ?? 0;
  const player2Points = live.player2_score_label ?? live.player2_score ?? 0;
  const scoringEvents = useMemo(
    () => (live.events || []).filter((event) => SCORING_EVENT_TYPES.has(event.event_type)).slice().reverse(),
    [live.events],
  );

  return (
    <main className="page-shell stack remote-match-page">
      <ClubPageHeader />
      {loading ? <div className="notice">Opening remote match…</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {match ? (
        <>
          <section className={`panel remote-match-status${watch.finished ? " is-finished" : " is-live"}`}>
            <div>
              <span className="status-pill">{watch.finished ? "Finished" : "Live"}</span>
              <h1>{watch.finished ? "This match has finished" : "Watching live match"}</h1>
              <p>{formatSport(match.sport)} · Viewing code {watch.code}</p>
            </div>
            {watch.saved ? (
              <span className="remote-match-saved">Added to Viewed Matches</span>
            ) : (
              <button disabled={saving} type="button" onClick={handleSave}>
                {saving ? "Adding…" : "Add to Viewed Matches"}
              </button>
            )}
          </section>

          <section className="panel remote-match-score" aria-label="Remote match score">
            <article>
              <strong>{player1Name}</strong>
              <b>{watch.finished ? player1Games : player1Points}</b>
              <span>{tennisStyle ? `${player1Games} games` : `${player1Games} games won`}</span>
            </article>
            <div aria-hidden="true">–</div>
            <article>
              <strong>{player2Name}</strong>
              <b>{watch.finished ? player2Games : player2Points}</b>
              <span>{tennisStyle ? `${player2Games} games` : `${player2Games} games won`}</span>
            </article>
          </section>

          <section className="panel stack remote-match-timeline">
            <div className="panel-heading">
              <h2>{watch.finished ? "Result Timeline" : "Live Timeline"}</h2>
              <p className="helper-text">The newest scoring event appears first.</p>
            </div>
            {scoringEvents.length ? (
              <ol>
                {scoringEvents.map((event) => {
                  const side = event.payload?.scorer || event.payload?.player_side;
                  return (
                    <li key={event.id || `${event.created_at}-${side}`}>
                      <span>{formatTime(event.created_at)}</span>
                      <strong>{side === "player2" ? player2Name : player1Name}</strong>
                      <b>{eventScore(event, tennisStyle)}</b>
                      {event.summary ? <small>{event.summary}</small> : null}
                    </li>
                  );
                })}
              </ol>
            ) : <p className="dashboard-empty">No points have been recorded yet.</p>}
          </section>

          <button className="match-bottom-back-button" type="button" onClick={() => navigate("/matches")}>Back to Matches</button>
        </>
      ) : null}
      <AppFooter />
    </main>
  );
}
