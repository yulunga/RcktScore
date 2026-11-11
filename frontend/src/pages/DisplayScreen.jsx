import React, { useCallback, useEffect, useState } from "react";
import { QRCodeSVG } from "qrcode.react";

import AppFooter from "../components/AppFooter";
import PublicAccessHeader from "../components/PublicAccessHeader";
import Scoreboard from "../components/Scoreboard";
import {
  createScoreboardDisplaySession,
  createScoreboardPairing,
  exchangeScoreboardPairing,
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
  const [allGamesPage, setAllGamesPage] = useState(0);
  const [entryMode, setEntryMode] = useState("qr");
  const [pairing, setPairing] = useState(null);
  const [pairingAttempted, setPairingAttempted] = useState(false);
  const [pairingSeconds, setPairingSeconds] = useState(0);

  const pollIntervalSeconds = displaySession?.poll_interval_seconds || 5;
  const clearDisplaySession = useCallback(() => {
    setDisplaySession(null);
    setCourt(null);
    setCurrentMatch(null);
    setClubMatches([]);
    setPairing(null);
    setPairingAttempted(false);
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

  const startPairing = useCallback(async () => {
    setPairingAttempted(true);
    setLoading(true);
    setError("");
    try {
      const payload = await createScoreboardPairing();
      setPairing(payload?.pairing || null);
    } catch (requestError) {
      setPairing(null);
      setError(requestError.message || "Unable to create a scoreboard QR code.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (displaySession?.display_session_token || entryMode !== "qr" || pairing || pairingAttempted) return;
    startPairing();
  }, [displaySession?.display_session_token, entryMode, pairing, pairingAttempted, startPairing]);

  useEffect(() => {
    if (!pairing?.expires_at || displaySession?.display_session_token) return undefined;
    const updateCountdown = () => {
      setPairingSeconds(Math.max(0, Math.ceil((new Date(pairing.expires_at).getTime() - Date.now()) / 1000)));
    };
    updateCountdown();
    const intervalId = window.setInterval(updateCountdown, 1000);
    return () => window.clearInterval(intervalId);
  }, [displaySession?.display_session_token, pairing?.expires_at]);

  useEffect(() => {
    if (entryMode !== "qr" || !pairing?.token || displaySession?.display_session_token) return undefined;
    let cancelled = false;
    const checkPairing = async () => {
      if (new Date(pairing.expires_at).getTime() <= Date.now()) return;
      try {
        const payload = await exchangeScoreboardPairing(pairing.token);
        if (cancelled || payload?.state !== "approved") return;
        setError("");
        applyDisplayPayload(payload, payload.display_session_token);
        setPairing(null);
      } catch (requestError) {
        if (cancelled) return;
        if (["PAIRING_EXPIRED", "PAIRING_ALREADY_USED", "PAIRING_RATE_LIMITED"].includes(requestError.code)) {
          setPairing(null);
        }
        setError(requestError.message || "Unable to complete scoreboard pairing.");
      }
    };
    checkPairing();
    const intervalId = window.setInterval(checkPairing, 2000);
    return () => {
      cancelled = true;
      window.clearInterval(intervalId);
    };
  }, [applyDisplayPayload, displaySession?.display_session_token, entryMode, pairing?.expires_at, pairing?.token]);

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
      <PublicAccessHeader label="Live Scoreboard">
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
      </PublicAccessHeader>

      {!displaySession?.display_session_token ? (
        <section className="panel stack public-access-key-card scoreboard-entry-card">
          <div className="panel-heading">
            <h1>Open a Court Scoreboard</h1>
            <p className="helper-text">Pair this screen from a club administrator's HitnScore app, or enter the court display code.</p>
          </div>
          <div className="scoreboard-entry-tabs" role="tablist" aria-label="Scoreboard sign-in method">
            <button className={entryMode === "qr" ? "active" : "secondary"} type="button" onClick={() => setEntryMode("qr")}>Scan QR</button>
            <button className={entryMode === "code" ? "active" : "secondary"} type="button" onClick={() => setEntryMode("code")}>Enter Code</button>
          </div>
          {entryMode === "qr" ? (
            <div className="scoreboard-pairing stack" role="tabpanel">
              {pairing?.qr_value && pairingSeconds > 0 ? (
                <>
                  <div className="scoreboard-pairing__qr" aria-label="Scoreboard pairing QR code">
                    <QRCodeSVG value={pairing.qr_value} size={224} level="M" marginSize={2} />
                  </div>
                  <p className="helper-text">In the HitnScore app, open Club Management → Courts, choose this court and tap <strong>Scan Scoreboard QR</strong>.</p>
                  <p className="scoreboard-pairing__countdown">Expires in {pairingSeconds} seconds</p>
                </>
              ) : (
                <p className="helper-text">{loading ? "Preparing a secure QR code…" : "This QR code has expired."}</p>
              )}
              <div className="button-row scoreboard-shell__actions">
                <button className="secondary" disabled={loading} type="button" onClick={startPairing}>
                  {loading ? "Preparing…" : "Refresh QR"}
                </button>
              </div>
            </div>
          ) : (
          <form className="stack" onSubmit={handleCodeSubmit} role="tabpanel">
            <div className="field">
              <label htmlFor="scoreboard_code">Scoreboard Display Code</label>
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
          )}
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
