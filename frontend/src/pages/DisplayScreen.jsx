import React, { useCallback, useEffect, useMemo, useState } from "react";

import AppFooter from "../components/AppFooter";
import Scoreboard from "../components/Scoreboard";
import {
  createScoreboardDisplaySession,
  getScoreboardDisplayCurrent,
} from "../services/api";

const SCOREBOARD_SESSION_KEY = "rcktscore.scoreboardDisplay";
const SCOREBOARD_LAYOUT_KEY = "rcktscore.scoreboardLayout";
const ALL_GAMES_ROTATION_MS = 5 * 60 * 1000;
const ALL_GAMES_PAGE_SIZE = 8;

function readStoredDisplaySession() {
  if (typeof window === "undefined") {
    return null;
  }

  try {
    const rawValue = window.sessionStorage.getItem(SCOREBOARD_SESSION_KEY);
    if (!rawValue) {
      return null;
    }

    const parsedValue = JSON.parse(rawValue);
    if (!parsedValue?.display_session_token) {
      return null;
    }

    return parsedValue;
  } catch {
    return null;
  }
}

function storeDisplaySession(session) {
  if (typeof window === "undefined") {
    return;
  }

  if (!session) {
    window.sessionStorage.removeItem(SCOREBOARD_SESSION_KEY);
    return;
  }

  window.sessionStorage.setItem(SCOREBOARD_SESSION_KEY, JSON.stringify(session));
}

function readStoredDisplayMode() {
  if (typeof window === "undefined") {
    return "standard";
  }

  const storedValue = window.localStorage.getItem(SCOREBOARD_LAYOUT_KEY);
  return storedValue || "standard";
}

function storeDisplayMode(mode) {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.setItem(SCOREBOARD_LAYOUT_KEY, mode || "standard");
}

function formatGameHistory(gameHistory) {
  const history = Array.isArray(gameHistory) ? gameHistory : [];
  if (!history.length) {
    return "No completed games yet";
  }

  return history
    .map((game) => `${game?.player1_score ?? 0}-${game?.player2_score ?? 0}`)
    .join(" / ");
}

export default function DisplayScreen() {
  const [code, setCode] = useState("");
  const [currentMatch, setCurrentMatch] = useState(null);
  const [clubMatches, setClubMatches] = useState([]);
  const [court, setCourt] = useState(null);
  const [displaySession, setDisplaySession] = useState(() => readStoredDisplaySession());
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [displayMode, setDisplayMode] = useState(() => readStoredDisplayMode());
  const [lastUpdatedAt, setLastUpdatedAt] = useState(null);
  const [allGamesPage, setAllGamesPage] = useState(0);

  const pollIntervalSeconds = displaySession?.poll_interval_seconds || 5;
  const scoreboardUrl = useMemo(() => {
    if (typeof window === "undefined") {
      return "/scoreboard";
    }

    return `${window.location.origin}/scoreboard`;
  }, []);

  const clearDisplaySession = useCallback(() => {
    setDisplaySession(null);
    setCourt(null);
    setCurrentMatch(null);
    setClubMatches([]);
    setLastUpdatedAt(null);
    storeDisplaySession(null);
  }, []);

  const applyDisplayPayload = useCallback((payload, tokenOverride = "") => {
    const nextToken = tokenOverride || payload?.display_session_token || displaySession?.display_session_token || "";
    const nextSession = nextToken
      ? {
        display_session_token: nextToken,
        poll_interval_seconds: payload?.poll_interval_seconds || pollIntervalSeconds,
        court: payload?.court || null,
      }
      : null;

    setDisplaySession(nextSession);
    storeDisplaySession(nextSession);
    setCourt(payload?.court || null);
    setCurrentMatch(payload?.match || null);
    setClubMatches(payload?.club_matches || []);
    setLastUpdatedAt(new Date());
  }, [displaySession?.display_session_token, pollIntervalSeconds]);

  const loadCurrent = useCallback(async (displaySessionToken, options = {}) => {
    if (!displaySessionToken) {
      return;
    }

    const setBusyState = options.silent ? setRefreshing : setLoading;
    setBusyState(true);
    if (!options.preserveError) {
      setError("");
    }

    try {
      const payload = await getScoreboardDisplayCurrent(displaySessionToken);
      applyDisplayPayload(payload, displaySessionToken);
    } catch (requestError) {
      const errorCode = requestError.code || "";
      if (
        errorCode === "DISPLAY_SESSION_REQUIRED"
        || errorCode === "DISPLAY_SESSION_INVALID"
        || errorCode === "DISPLAY_SESSION_EXPIRED"
      ) {
        clearDisplaySession();
      }
      setError(requestError.message || "Unable to refresh the scoreboard right now.");
    } finally {
      setBusyState(false);
    }
  }, [applyDisplayPayload, clearDisplaySession]);

  useEffect(() => {
    if (!displaySession?.display_session_token) {
      return undefined;
    }

    loadCurrent(displaySession.display_session_token, { silent: false });

    const intervalId = window.setInterval(() => {
      loadCurrent(displaySession.display_session_token, { silent: true, preserveError: true });
    }, pollIntervalSeconds * 1000);

    return () => window.clearInterval(intervalId);
  }, [displaySession?.display_session_token, loadCurrent, pollIntervalSeconds]);

  useEffect(() => {
    storeDisplayMode(displayMode);
  }, [displayMode]);

  async function handleCodeSubmit(event) {
    event.preventDefault();
    const trimmedCode = code.trim().toUpperCase();
    if (!trimmedCode) {
      setError("Enter the 12-character display code.");
      return;
    }

    setLoading(true);
    setError("");
    try {
      const payload = await createScoreboardDisplaySession({ code: trimmedCode });
      applyDisplayPayload(payload, payload.display_session_token);
      setCode("");
    } catch (requestError) {
      setError(requestError.message || "Unable to open the scoreboard.");
    } finally {
      setLoading(false);
    }
  }

  async function handleManualRefresh() {
    if (!displaySession?.display_session_token) {
      return;
    }

    await loadCurrent(displaySession.display_session_token, { silent: true });
  }

  const statusMessage = lastUpdatedAt
    ? `Auto-refreshing every ${pollIntervalSeconds}s • Last updated ${lastUpdatedAt.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit" })}`
    : `Auto-refreshing every ${pollIntervalSeconds}s after sign-in.`;
  const allGamesPageCount = Math.max(1, Math.ceil(clubMatches.length / ALL_GAMES_PAGE_SIZE));
  const visibleClubMatches = displayMode === "all-games"
    ? clubMatches.slice(
      allGamesPage * ALL_GAMES_PAGE_SIZE,
      (allGamesPage + 1) * ALL_GAMES_PAGE_SIZE,
    )
    : clubMatches;

  useEffect(() => {
    setAllGamesPage(0);
  }, [clubMatches.length, displayMode]);

  useEffect(() => {
    if (displayMode !== "all-games" || allGamesPageCount <= 1) {
      return undefined;
    }

    const intervalId = window.setInterval(() => {
      setAllGamesPage((currentPage) => (currentPage + 1) % allGamesPageCount);
    }, ALL_GAMES_ROTATION_MS);

    return () => window.clearInterval(intervalId);
  }, [allGamesPageCount, displayMode]);

  return (
    <main className={`page-shell stack display-shell display-mode-${displayMode} ${displaySession?.display_session_token ? "display-session-active" : "display-session-inactive"}`}>
      <section className="hero-card display-header-card">
        <div className="display-header-card__top">
          <div className="display-header-card__branding">
            <div className="display-header-card__brand-row">
              <img
                className="display-header-card__logo"
                src="/branding/logo/brand-logo.png"
                alt="Hit n Score"
              />
              <div className="display-header-card__brand-stack">
                <h1 className="display-header-card__wordmark" aria-label="HitnScore">
                  <span className="display-header-card__wordmark-hit">Hit</span>
                  <span className="display-header-card__wordmark-n">n</span>
                  <span className="display-header-card__wordmark-score">Score</span>
                </h1>
                <span className="display-header-card__subheading">Live Scoreboard</span>
              </div>
            </div>
            {!displaySession?.display_session_token ? (
              <p className="helper-text scoreboard-shell__status">
                Enter a court display code to open the live scoreboard.
              </p>
            ) : null}
          </div>
          <div className="display-header-card__controls">
            <div className="button-row display-header-card__actions">
              {displaySession?.display_session_token ? (
                <>
                  <button
                    className="secondary"
                    disabled={refreshing || loading}
                    type="button"
                    onClick={handleManualRefresh}
                  >
                    {refreshing ? "Refreshing..." : "Refresh"}
                  </button>
                  <button className="secondary" type="button" onClick={clearDisplaySession}>
                    Use Different Code
                  </button>
                </>
              ) : null}
              <label className="display-layout-control">
                <span className="display-layout-control__label">Layout</span>
                <select value={displayMode} onChange={(event) => setDisplayMode(event.target.value)}>
                  <option value="standard">Standard</option>
                  <option value="large-scores">Large Scores</option>
                  <option value="all-games">All Games</option>
                  <option value="minimal">Minimal</option>
                </select>
              </label>
            </div>
            {displaySession?.display_session_token ? (
              <p className="helper-text display-header-card__status-note">{statusMessage}</p>
            ) : null}
          </div>
        </div>
      </section>

      {!displaySession?.display_session_token ? (
        <section className="panel stack scoreboard-entry-card">
          <div className="panel-heading">
            <h2>Open A Court Scoreboard</h2>
            <p className="helper-text">
              Enter the 12-character court code. This screen is read-only and opens on {scoreboardUrl}.
            </p>
          </div>
          <form className="stack" onSubmit={handleCodeSubmit}>
            <div className="field">
              <label htmlFor="scoreboard_code">Display Code</label>
              <input
                autoCapitalize="characters"
                autoCorrect="off"
                id="scoreboard_code"
                inputMode="text"
                maxLength={12}
                placeholder="ABCD2345WXYZ"
                value={code}
                onChange={(event) => setCode(event.target.value.toUpperCase().replace(/[^A-Z0-9]/g, ""))}
              />
            </div>
            <div className="button-row scoreboard-shell__actions">
              <button disabled={loading} type="submit">
                {loading ? "Opening..." : "Open Scoreboard"}
              </button>
            </div>
          </form>
        </section>
      ) : null}

      {loading && displaySession?.display_session_token ? <div className="notice">Loading scoreboard...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}
      {displaySession?.display_session_token && !currentMatch ? (
        <section className="scoreboard-card scoreboard-card--idle">
          <div className="scoreboard-header">
            <div>
              <h2 style={{ marginBottom: 0 }}>{court?.court_name || "Court"}</h2>
            </div>
            <div className="scoreboard-header-meta">
              <span className="status-pill scoreboard-idle-pill">idle</span>
              <div className="score-series-chip scoreboard-idle-chip">Waiting for next match</div>
            </div>
          </div>
          <div className="scoreboard-idle-body">
            <p>
              No active match is currently running on {court?.court_name || "this court"}. Leave the screen open and it will refresh automatically.
            </p>
          </div>
        </section>
      ) : null}
      {currentMatch ? (
        <>
          <Scoreboard match={currentMatch} showServeDetails={false} />
        </>
      ) : null}
      {displaySession?.display_session_token && displayMode === "all-games" ? (
        <section className="panel scoreboard-club-panel">
          <div className="panel-heading panel-heading--with-action">
            <div>
              <h2>All Games</h2>
            </div>
            {allGamesPageCount > 1 ? (
              <span className="scoreboard-club-panel__page-indicator">
                Page {allGamesPage + 1} of {allGamesPageCount}
              </span>
            ) : null}
          </div>
          {clubMatches.length === 0 ? (
            <div className="dashboard-empty">No other active courts right now.</div>
          ) : (
                <div className="scoreboard-club-grid">
                  {visibleClubMatches.map((match) => (
                <article className="scoreboard-club-card" key={match.id}>
                  <div className="scoreboard-club-card__top">
                    <strong>{match.court_name || "Court"}</strong>
                    <span className="scoreboard-club-card__status-dot" aria-label={match.status || "active"} title={match.status || "active"} />
                  </div>
                  <div className="scoreboard-club-card__players">
                    <div className="scoreboard-club-card__player">
                      <span className="scoreboard-club-card__player-name">{`${match.player1_name} ${match.player1_surname || ""}`.trim()}</span>
                      <div className="scoreboard-club-card__score-stack">
                        <strong>{match.player1_score}</strong>
                        <small>{match.player1_games_won}</small>
                      </div>
                    </div>
                    <div className="scoreboard-club-card__player">
                      <span className="scoreboard-club-card__player-name">{`${match.player2_name} ${match.player2_surname || ""}`.trim()}</span>
                      <div className="scoreboard-club-card__score-stack">
                        <strong>{match.player2_score}</strong>
                        <small>{match.player2_games_won}</small>
                      </div>
                    </div>
                  </div>
                  <div className="scoreboard-club-card__meta">
                    <span>{formatGameHistory(match.game_history)}</span>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>
      ) : null}
      <AppFooter />
    </main>
  );
}
