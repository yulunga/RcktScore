import React, { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import EventTimeline from "../components/EventTimeline";
import MatchControls from "../components/MatchControls";
import Scoreboard from "../components/Scoreboard";
import Timer from "../components/Timer";
import { useAuth } from "../hooks/useAuth";
import { useMatch } from "../hooks/useMatch";

function formatDate(value) {
  if (!value) {
    return "Unknown";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function getInitials(value) {
  if (!value) {
    return "--";
  }

  const parts = String(value)
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  if (parts.length === 0) {
    return "--";
  }

  return parts
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || "")
    .join("");
}

function inferOrganizationType(session) {
  if (session?.organization_type) {
    return session.organization_type;
  }

  return Number(session?.organization_id) >= 50000 ? "personal" : "club";
}

const WARMUP_SECONDS = 60;
const INTERVAL_SECONDS = 90;
const MATCH_TIMER_STORAGE_KEY = "rcktscore.matchTimer";

function isFreshMatch(match) {
  if (!match) {
    return false;
  }

  const live = match.state ?? {};
  const events = live.events || [];

  return (
    (live.current_game_number ?? match.current_game_number ?? 1) === 1
    && (live.player1_score ?? 0) === 0
    && (live.player2_score ?? 0) === 0
    && (live.game_history || []).length === 0
    && events.length <= 1
  );
}

function defaultSecondsForPhase(phase) {
  if (phase === "warmup_ready" || phase === "warmup_side_one" || phase === "warmup_side_two") {
    return WARMUP_SECONDS;
  }

  if (phase === "interval") {
    return INTERVAL_SECONDS;
  }

  return 0;
}

function readStoredTimerState(matchId) {
  try {
    const raw = window.localStorage.getItem(`${MATCH_TIMER_STORAGE_KEY}.${matchId}`);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function writeStoredTimerState(matchId, state) {
  try {
    window.localStorage.setItem(`${MATCH_TIMER_STORAGE_KEY}.${matchId}`, JSON.stringify(state));
  } catch {
    // ignore persistence failures
  }
}

function clearStoredTimerState(matchId) {
  try {
    window.localStorage.removeItem(`${MATCH_TIMER_STORAGE_KEY}.${matchId}`);
  } catch {
    // ignore persistence failures
  }
}

function advanceTimerSnapshot(snapshot) {
  if (!snapshot?.running) {
    return snapshot;
  }

  const elapsed = Math.max(0, Math.floor((Date.now() - snapshot.updatedAt) / 1000));
  if (elapsed === 0) {
    return snapshot;
  }

  if (snapshot.phase === "match_live") {
    return {
      ...snapshot,
      seconds: snapshot.seconds + elapsed,
      updatedAt: Date.now(),
    };
  }

  let remainingElapsed = elapsed;
  let phase = snapshot.phase;
  let seconds = snapshot.seconds;

  while (remainingElapsed > 0) {
    if (phase === "warmup_side_one") {
      if (remainingElapsed >= seconds) {
        remainingElapsed -= seconds;
        phase = "warmup_side_two";
        seconds = WARMUP_SECONDS;
        continue;
      }

      seconds -= remainingElapsed;
      remainingElapsed = 0;
      break;
    }

    if (phase === "warmup_side_two") {
      if (remainingElapsed >= seconds) {
        remainingElapsed -= seconds;
        phase = "first_server";
        seconds = 0;
        break;
      }

      seconds -= remainingElapsed;
      remainingElapsed = 0;
      break;
    }

    if (phase === "interval") {
      if (remainingElapsed >= seconds) {
        remainingElapsed -= seconds;
        phase = "match_live";
        seconds = 0;
        continue;
      }

      seconds -= remainingElapsed;
      remainingElapsed = 0;
      break;
    }

    if (phase === "warmup_ready" || phase === "first_server") {
      break;
    }

    seconds += remainingElapsed;
    remainingElapsed = 0;
  }

  return {
    ...snapshot,
    phase,
    seconds,
    updatedAt: Date.now(),
  };
}

export default function MatchScreen() {
  const { matchId } = useParams();
  const { session } = useAuth();
  const {
    currentMatch,
    error,
    loading,
    loadMatch,
    connectRealtime,
    endMatch,
    scorePoint,
    sendEventAction,
    undoLastAction,
  } = useMatch();
  const navigate = useNavigate();
  const live = currentMatch?.state ?? {};
  const gameHistory = live.game_history || [];
  const serviceSide = live.service_side || "Right";
  const isPersonalAccount = inferOrganizationType(session) === "personal";
  const displayUrl = !isPersonalAccount ? `${window.location.origin}/display?match=${matchId}` : "";
  const [timerPhase, setTimerPhase] = useState("warmup_ready");
  const [timerSeconds, setTimerSeconds] = useState(WARMUP_SECONDS);
  const [timerRunning, setTimerRunning] = useState(false);
  const [showWarmupOverlay, setShowWarmupOverlay] = useState(false);
  const [showFirstServerOverlay, setShowFirstServerOverlay] = useState(false);
  const [showExtraMatchDetails, setShowExtraMatchDetails] = useState(false);
  const bootstrappedMatchRef = useRef(null);
  const previousGameHistoryCountRef = useRef(0);

  useEffect(() => {
    loadMatch(matchId);
    const disconnect = connectRealtime(matchId);
    return disconnect;
  }, [connectRealtime, loadMatch, matchId]);

  useEffect(() => {
    if (!currentMatch?.id) {
      return;
    }

    if (bootstrappedMatchRef.current === currentMatch.id) {
      return;
    }

    bootstrappedMatchRef.current = currentMatch.id;
    previousGameHistoryCountRef.current = gameHistory.length;

    const storedState = readStoredTimerState(currentMatch.id);
    if (storedState) {
      const advancedState = advanceTimerSnapshot(storedState);
      const needsFirstServer = advancedState.phase === "first_server";
      setTimerPhase(needsFirstServer ? "warmup_side_two" : advancedState.phase);
      setTimerSeconds(needsFirstServer ? 0 : advancedState.seconds);
      setTimerRunning(needsFirstServer ? false : advancedState.running);
      setShowWarmupOverlay(["warmup_ready", "warmup_side_one", "warmup_side_two"].includes(advancedState.phase));
      setShowFirstServerOverlay(needsFirstServer);
      return;
    }

    if (isFreshMatch(currentMatch)) {
      setTimerPhase("warmup_ready");
      setTimerSeconds(WARMUP_SECONDS);
      setTimerRunning(false);
      setShowWarmupOverlay(true);
      return;
    }

    setTimerPhase("match_live");
    setTimerSeconds(0);
    setTimerRunning(true);
    setShowWarmupOverlay(false);
    setShowFirstServerOverlay(false);
  }, [currentMatch, gameHistory.length]);

  useEffect(() => {
    if (!currentMatch?.id) {
      return;
    }

    const previousCount = previousGameHistoryCountRef.current;
    if (gameHistory.length > previousCount) {
      previousGameHistoryCountRef.current = gameHistory.length;
      const matchComplete = currentMatch?.state?.match_complete || currentMatch?.status === "completed";

      if (!matchComplete) {
        setTimerPhase("interval");
        setTimerSeconds(INTERVAL_SECONDS);
        setTimerRunning(true);
      }
      return;
    }

    previousGameHistoryCountRef.current = gameHistory.length;
  }, [currentMatch?.id, currentMatch?.state?.match_complete, currentMatch?.status, gameHistory.length]);

  useEffect(() => {
    if (!currentMatch?.id) {
      return;
    }

    if (currentMatch?.state?.match_complete || currentMatch?.status === "completed") {
      clearStoredTimerState(currentMatch.id);
      return;
    }

    writeStoredTimerState(currentMatch.id, {
      phase: showFirstServerOverlay ? "first_server" : timerPhase,
      running: timerRunning,
      seconds: timerSeconds,
      updatedAt: Date.now(),
    });
  }, [
    currentMatch?.id,
    currentMatch?.state?.match_complete,
    currentMatch?.status,
    showFirstServerOverlay,
    timerPhase,
    timerRunning,
    timerSeconds,
  ]);

  useEffect(() => {
    if (!timerRunning) {
      return undefined;
    }

    const intervalId = window.setInterval(() => {
      setTimerSeconds((value) => {
        if (timerPhase === "match_live") {
          return value + 1;
        }

        return Math.max(0, value - 1);
      });
    }, 1000);

    return () => window.clearInterval(intervalId);
  }, [timerRunning, timerPhase]);

  useEffect(() => {
    if (!timerRunning || timerSeconds !== 0) {
      return;
    }

    if (timerPhase === "warmup_side_one") {
      setTimerPhase("warmup_side_two");
      setTimerSeconds(WARMUP_SECONDS);
      setTimerRunning(true);
      return;
    }

    if (timerPhase === "warmup_side_two") {
      setTimerRunning(false);
      setShowFirstServerOverlay(true);
      return;
    }

    if (timerPhase === "interval") {
      window.alert("Game break complete. Resume play.");
      setTimerPhase("match_live");
      setTimerSeconds(0);
      setTimerRunning(true);
    }
  }, [timerPhase, timerRunning, timerSeconds]);

  const timerLabel = useMemo(() => {
    if (timerPhase === "warmup_ready") {
      return "Warm-Up Ready";
    }

    if (timerPhase === "warmup_side_one") {
      return "Warm-Up: Side 1";
    }

    if (timerPhase === "warmup_side_two") {
      return "Warm-Up: Side 2";
    }

    if (timerPhase === "interval") {
      return "Game Break - 90s";
    }

    return "";
  }, [timerPhase]);

  const timerHelperText = useMemo(() => {
    if (timerPhase === "warmup_ready") {
      return "Warm-up starts when both players are ready.";
    }

    if (timerPhase === "warmup_side_one" || timerPhase === "warmup_side_two") {
      return "Warm-up runs for 60 seconds on each side of the court.";
    }

    if (timerPhase === "interval") {
      return "90 second break between games.";
    }

    return "Tap the clock to pause or resume the match.";
  }, [timerPhase]);

  const timerSkipLabel = useMemo(() => {
    if (timerPhase === "warmup_side_one" || timerPhase === "warmup_side_two") {
      return "Skip Warm-Up";
    }

    if (timerPhase === "interval") {
      return "Skip Break";
    }

    return "";
  }, [timerPhase]);

  function handleStartWarmup() {
    setShowWarmupOverlay(true);
    setShowFirstServerOverlay(false);
    setTimerPhase("warmup_side_one");
    setTimerSeconds(WARMUP_SECONDS);
    setTimerRunning(true);
  }

  function handleSkipWarmup() {
    setShowWarmupOverlay(false);
    setTimerRunning(false);
    setShowFirstServerOverlay(true);
  }

  function handleToggleTimer() {
    if (timerPhase === "warmup_ready") {
      handleStartWarmup();
      return;
    }

    setTimerRunning((value) => !value);
  }

  function handleSkipTimedPhase() {
    if (timerPhase === "warmup_side_one" || timerPhase === "warmup_side_two" || timerPhase === "interval") {
      if (timerPhase === "warmup_side_one" || timerPhase === "warmup_side_two") {
        setTimerRunning(false);
        setShowFirstServerOverlay(true);
        return;
      }

      setTimerPhase("match_live");
      setTimerSeconds(0);
      setTimerRunning(true);
    }
  }

  async function handleChooseFirstServer(playerSide) {
    const selectedPlayerName = playerSide === "player2"
      ? currentMatch?.player2_name
      : currentMatch?.player1_name;
    const receiverHandedness = playerSide === "player2"
      ? currentMatch?.player1_handedness
      : currentMatch?.player2_handedness;
    const serviceSideForServer = receiverHandedness === "left" ? "Left" : "Right";

    await sendEventAction(matchId, "server", {
      current_server: selectedPlayerName,
      current_server_side: playerSide,
      service_side: serviceSideForServer,
    });
    setShowWarmupOverlay(false);
    setShowFirstServerOverlay(false);
    setTimerPhase("match_live");
    setTimerSeconds(0);
    setTimerRunning(true);
  }

  const showWarmupFlowOverlay = showWarmupOverlay
    || showFirstServerOverlay
    || timerPhase === "warmup_side_one"
    || timerPhase === "warmup_side_two";

  return (
    <main className="page-shell stack match-screen-shell">
      <ClubPageHeader
        className="club-page-header--match"
        subtitle="Manage the live scoring session."
        title={session?.organization_name || currentMatch?.organization_name || "Live Match"}
      />

      {showWarmupFlowOverlay ? (
        <div className="overlay-backdrop">
          <div className="overlay-panel overlay-panel--warmup stack">
            {showFirstServerOverlay && currentMatch ? (
              <>
                <h2>First Server</h2>
                <p className="helper-text">
                  Choose which player starts serving. The match begins after this selection.
                </p>
                <div className="first-server-options">
                  <button
                    disabled={loading}
                    type="button"
                    onClick={() => handleChooseFirstServer("player1")}
                  >
                    {`${currentMatch.player1_name} ${currentMatch.player1_surname || ""}`.trim()}
                  </button>
                  <button
                    className="secondary"
                    disabled={loading}
                    type="button"
                    onClick={() => handleChooseFirstServer("player2")}
                  >
                    {`${currentMatch.player2_name} ${currentMatch.player2_surname || ""}`.trim()}
                  </button>
                </div>
              </>
            ) : (
              <>
                <h2>{timerPhase === "warmup_side_two" ? "Change Sides" : "Warm-Up"}</h2>
                <p className="helper-text">
                  {timerPhase === "warmup_ready"
                    ? "Start 60 seconds on side 1, swap sides for another 60 seconds, then choose the first server."
                    : timerPhase === "warmup_side_two"
                      ? "Side 1 is complete. Players should change sides while the second warm-up runs."
                      : "Warm-up is running. Keep this window open until the first server is selected."}
                </p>
                {timerPhase === "warmup_ready" ? (
                  <div className="button-row warmup-overlay__actions">
                    <button type="button" onClick={handleStartWarmup}>
                      Start Warm-Up
                    </button>
                    <button className="secondary" type="button" onClick={handleSkipWarmup}>
                      Skip Warm-Up
                    </button>
                  </div>
                ) : (
                  <>
                    <button
                      className={`timer-chip timer-chip--button timer-chip--overlay${timerRunning ? "" : " timer-chip--paused"}`}
                      type="button"
                      onClick={handleToggleTimer}
                    >
                      {String(Math.floor(timerSeconds / 60)).padStart(2, "0")}:
                      {String(timerSeconds % 60).padStart(2, "0")}
                    </button>
                    <div className="button-row warmup-overlay__actions">
                      <button className="secondary" type="button" onClick={handleSkipTimedPhase}>
                        Skip Warm-Up
                      </button>
                    </div>
                  </>
                )}
              </>
            )}
          </div>
        </div>
      ) : null}

      {timerPhase === "interval" && currentMatch?.status !== "completed" ? (
        <div className="overlay-backdrop">
          <div className="overlay-panel overlay-panel--warmup stack">
            <h2>Game Break</h2>
            <p className="helper-text">
              90 second interval between games. Tap the clock to pause or resume if needed.
            </p>
            <button
              className={`timer-chip timer-chip--button timer-chip--overlay${timerRunning ? "" : " timer-chip--paused"}`}
              type="button"
              onClick={handleToggleTimer}
            >
              {String(Math.floor(timerSeconds / 60)).padStart(2, "0")}:
              {String(timerSeconds % 60).padStart(2, "0")}
            </button>
            <div className="button-row warmup-overlay__actions">
              <button className="secondary" type="button" onClick={handleSkipTimedPhase}>
                Skip Break
              </button>
            </div>
          </div>
        </div>
      ) : null}

      <div className="match-top-grid">
        <div className="stack match-primary-column">
          <Scoreboard
            disabled={!currentMatch || loading}
            match={currentMatch}
            onScorePoint={(scorer) => scorePoint(matchId, scorer)}
            onToggleServeSide={() =>
              sendEventAction(matchId, "serve_side", {
                side: serviceSide === "Left" ? "Right" : "Left",
              })
            }
          >
            <MatchControls
              disabled={!currentMatch || loading}
              match={currentMatch}
              onEventAction={(actionType, payload) =>
                sendEventAction(matchId, actionType, payload)
              }
              onUndo={() => undoLastAction(matchId)}
              onEndMatch={async (payload) => {
                const updatedMatch = await endMatch(matchId, payload);
                if (updatedMatch?.status === "completed") {
                  navigate("/dashboard");
                }
              }}
            />
          </Scoreboard>
          <Timer
            helperText={timerHelperText}
            label={timerLabel}
            onSkip={timerSkipLabel ? handleSkipTimedPhase : undefined}
            onToggle={handleToggleTimer}
            running={timerRunning}
            seconds={timerSeconds}
            skipLabel={timerSkipLabel}
            title="Match Timer"
          />
          {loading ? <div className="notice">Syncing match state...</div> : null}
          {error ? <div className="notice error">{error}</div> : null}
        </div>
      </div>

      {currentMatch && !isPersonalAccount ? (
        <section className="panel stack match-detail-panel">
          <div className="match-meta-toggle-wrap">
            <button
              className="match-meta-toggle"
              type="button"
              onClick={() => setShowExtraMatchDetails((value) => !value)}
            >
              Match Details
              <span className="match-meta-toggle__arrow" aria-hidden="true">
                {showExtraMatchDetails ? "^" : "v"}
              </span>
            </button>
          </div>

          {showExtraMatchDetails ? (
            <>
              <div className="meta-grid match-meta-grid">
                <div className="meta-item meta-item--compact">
                  <strong>Server</strong>
                  <div>{live.current_server || "Not set"}</div>
                </div>
                <div className="meta-item meta-item--compact">
                  <strong>Service Side</strong>
                  <div>{serviceSide}</div>
                </div>
                <div className="meta-item meta-item--compact">
                  <strong>Referee</strong>
                  <div>{currentMatch.referee_name || "TBC"}</div>
                </div>
              </div>
              {currentMatch?.updated_at ? (
                <div className="notice match-updated-notice">Updated: {formatDate(currentMatch.updated_at)}</div>
              ) : null}
              <EventTimeline events={currentMatch?.state?.events || []} />
            </>
          ) : null}
        </section>
      ) : null}

      {!isPersonalAccount ? (
      <div className="stack match-secondary-column">
        <section className="panel stack">
          <h2>Spectator Display</h2>
          <p className="helper-text">
            Open this URL on the venue display, TV browser, or secondary tablet.
          </p>
          <input className="read-only-input" readOnly value={displayUrl} />
        </section>
      </div>
      ) : null}

      <div className="stack match-bottom-stack">
        <button
          className="match-bottom-back-button"
          type="button"
          onClick={() => navigate("/dashboard")}
        >
          Dashboard
        </button>
      </div>
      <AppFooter />
    </main>
  );
}
