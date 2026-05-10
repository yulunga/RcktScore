import React, { useCallback, useEffect, useMemo, useState } from "react";

import AppFooter from "../components/AppFooter";
import EventTimeline from "../components/EventTimeline";
import Scoreboard from "../components/Scoreboard";
import {
  createScoreboardDisplaySession,
  getScoreboardDisplayCurrent,
} from "../services/api";

const SCOREBOARD_SESSION_KEY = "rcktscore.scoreboardDisplay";

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

export default function DisplayScreen() {
  const [code, setCode] = useState("");
  const [currentMatch, setCurrentMatch] = useState(null);
  const [court, setCourt] = useState(null);
  const [displaySession, setDisplaySession] = useState(() => readStoredDisplaySession());
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [showTimeline, setShowTimeline] = useState(false);
  const [displayMode, setDisplayMode] = useState("standard");
  const [lastUpdatedAt, setLastUpdatedAt] = useState(null);

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
    setShowTimeline(false);
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

  return (
    <main className={`page-shell stack display-shell display-mode-${displayMode}`}>
      <section className="hero-card display-header-card">
        <div className="display-header-card__top">
          <div className="display-header-card__branding">
            <div className="club-page-header__brand-row">
              <img
                className="club-page-header__logo"
                src="/branding/logo/brand-logo.png"
                alt="Hit n Score"
              />
              <div className="club-page-header__brand-stack">
                <h1 className="club-page-header__wordmark" aria-label="HitnScore">
                  <span className="club-page-header__wordmark-hit">Hit</span>
                  <span className="club-page-header__wordmark-n">n</span>
                  <span className="club-page-header__wordmark-score">Score</span>
                </h1>
                <span className="display-header-card__subheading">Live Scoreboard</span>
              </div>
            </div>
            <p className="helper-text scoreboard-shell__status">
              {displaySession?.display_session_token
                ? statusMessage
                : "Enter a court display code to open the live scoreboard."}
            </p>
          </div>
          <div className="display-header-card__controls">
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
                <option value="minimal">Minimal</option>
              </select>
            </label>
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
        <div className="notice">
          No active match is currently running on {court?.court_name || "this court"}. Leave the screen open and it will refresh automatically.
        </div>
      ) : null}
      {currentMatch ? (
        <>
          <Scoreboard match={currentMatch} />
          <div className="match-meta-toggle-wrap display-timeline-toggle-wrap">
            <button
              className="match-meta-toggle"
              type="button"
              onClick={() => setShowTimeline((value) => !value)}
            >
              {showTimeline ? "Hide Event Timeline" : "Show Event Timeline"}
              <span className="match-meta-toggle__arrow" aria-hidden="true">
                {showTimeline ? "^" : "v"}
              </span>
            </button>
          </div>
          {showTimeline ? <EventTimeline events={currentMatch?.state?.events || []} /> : null}
        </>
      ) : null}
      <AppFooter />
    </main>
  );
}
