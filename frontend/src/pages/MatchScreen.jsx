import React, { useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import EventTimeline from "../components/EventTimeline";
import MatchControls from "../components/MatchControls";
import Scoreboard from "../components/Scoreboard";
import Timer from "../components/Timer";
import {
  DEFAULT_PLAYER_SHIRT_COLORS,
  PLAYER_SHIRT_COLORS,
} from "../constants/playerShirtColors";
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

function canChooseShirtColors(session) {
  const organizationType = inferOrganizationType(session);
  return organizationType !== "personal" || session?.plan === "personal_plus";
}

const WARMUP_SECONDS = 60;
const INTERVAL_SECONDS = 90;
const MATCH_TIMER_STORAGE_KEY = "rcktscore.matchTimer";
const scoreTypeOptions = [
  { value: 11, label: "PAR-11" },
  { value: 15, label: "PAR-15" },
];
const bestOfOptions = [
  { value: 1, label: "Best of 1" },
  { value: 3, label: "Best of 3" },
  { value: 5, label: "Best of 5" },
];

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

function formatSeconds(value) {
  const minutes = String(Math.floor(Math.max(0, value) / 60)).padStart(2, "0");
  const seconds = String(Math.max(0, value) % 60).padStart(2, "0");
  return `${minutes}:${seconds}`;
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
  const location = useLocation();
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
  const matchComplete = currentMatch?.state?.match_complete || currentMatch?.status === "completed";
  const completedAtTimestamp = currentMatch?.completed_at ? new Date(currentMatch.completed_at).getTime() : NaN;
  const undoLocked = matchComplete
    && Number.isFinite(completedAtTimestamp)
    && (Date.now() - completedAtTimestamp) > (5 * 60 * 1000);
  const recordedMatchDurationSeconds = live.match_duration_seconds ?? currentMatch?.match_duration_seconds ?? 0;
  const isPersonalAccount = inferOrganizationType(session) === "personal";
  const canChoosePlayerShirtColors = canChooseShirtColors(session);
  const scoreboardUrl = !isPersonalAccount ? `${window.location.origin}/scoreboard` : "";
  const displayCode = currentMatch?.court_display_code || "";
  const [timerPhase, setTimerPhase] = useState("warmup_ready");
  const [timerSeconds, setTimerSeconds] = useState(WARMUP_SECONDS);
  const [timerRunning, setTimerRunning] = useState(false);
  const [showWarmupOverlay, setShowWarmupOverlay] = useState(false);
  const [showFirstServerOverlay, setShowFirstServerOverlay] = useState(false);
  const [showGameSettingsOverlay, setShowGameSettingsOverlay] = useState(false);
  const [gameSettingsForm, setGameSettingsForm] = useState({
    score_type: 15,
    best_of: 5,
    player1_shirt_color: DEFAULT_PLAYER_SHIRT_COLORS.player1,
    player2_shirt_color: DEFAULT_PLAYER_SHIRT_COLORS.player2,
  });
  const [showExtraMatchDetails, setShowExtraMatchDetails] = useState(false);
  const bootstrappedMatchRef = useRef(null);
  const previousGameHistoryCountRef = useRef(0);
  const durationSyncRef = useRef({});
  const settingsAutoloadedRef = useRef(false);

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
    if (!currentMatch?.id || settingsAutoloadedRef.current) {
      return;
    }

    const searchParams = new URLSearchParams(location.search);
    if (searchParams.get("settings") !== "1") {
      return;
    }

    settingsAutoloadedRef.current = true;
    setShowGameSettingsOverlay(true);
  }, [currentMatch?.id, location.search]);

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

    if (matchComplete) {
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
    matchComplete,
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

  function resolveMatchDurationSeconds() {
    if (timerPhase === "match_live") {
      return timerSeconds;
    }

    if (currentMatch?.id) {
      const storedState = readStoredTimerState(currentMatch.id);
      if (storedState) {
        const advancedState = advanceTimerSnapshot(storedState);
        if (advancedState.phase === "match_live") {
          return advancedState.seconds;
        }
      }
    }

    return timerSeconds;
  }

  useEffect(() => {
    if (!currentMatch?.id || !matchComplete) {
      return;
    }

    setTimerRunning(false);

    if (recordedMatchDurationSeconds > 0) {
      setTimerSeconds(recordedMatchDurationSeconds);
      clearStoredTimerState(currentMatch.id);
      durationSyncRef.current[currentMatch.id] = true;
      return;
    }

    if (durationSyncRef.current[currentMatch.id]) {
      return;
    }

    const finalDuration = Math.max(0, resolveMatchDurationSeconds());
    setTimerSeconds(finalDuration);
    clearStoredTimerState(currentMatch.id);
    durationSyncRef.current[currentMatch.id] = true;

    if (finalDuration > 0) {
      void sendEventAction(matchId, "timer", {
        match_duration_seconds: finalDuration,
        note: "Match duration recorded",
      });
    }
  }, [
    currentMatch?.id,
    matchComplete,
    matchId,
    recordedMatchDurationSeconds,
    sendEventAction,
    timerPhase,
    timerSeconds,
  ]);

  const timerLabel = useMemo(() => {
    if (matchComplete) {
      return "Match Time";
    }

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
  }, [matchComplete, timerPhase]);

  const timerHelperText = useMemo(() => {
    if (matchComplete) {
      return recordedMatchDurationSeconds > 0
        ? `Recorded total match time: ${formatSeconds(recordedMatchDurationSeconds)}`
        : "Recording total match time...";
    }

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
  }, [matchComplete, recordedMatchDurationSeconds, timerPhase]);

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

  function openGameSettings() {
    setGameSettingsForm({
      score_type: currentMatch?.score_type ?? currentMatch?.state?.score_type ?? 15,
      best_of: currentMatch?.best_of ?? currentMatch?.state?.best_of ?? 5,
      player1_shirt_color: currentMatch?.player1_shirt_color
        ?? currentMatch?.state?.player1_shirt_color
        ?? DEFAULT_PLAYER_SHIRT_COLORS.player1,
      player2_shirt_color: currentMatch?.player2_shirt_color
        ?? currentMatch?.state?.player2_shirt_color
        ?? DEFAULT_PLAYER_SHIRT_COLORS.player2,
    });
    setShowGameSettingsOverlay(true);
  }

  async function handleSaveGameSettings(event) {
    event.preventDefault();
    const settingsPayload = {
      score_type: Number(gameSettingsForm.score_type),
      best_of: Number(gameSettingsForm.best_of),
    };

    if (canChoosePlayerShirtColors) {
      settingsPayload.player1_shirt_color = gameSettingsForm.player1_shirt_color;
      settingsPayload.player2_shirt_color = gameSettingsForm.player2_shirt_color;
    }

    const updatedMatch = await sendEventAction(matchId, "match_settings", settingsPayload);

    if (updatedMatch) {
      setShowGameSettingsOverlay(false);
    }
  }

  function renderShirtColorField(playerKey, label) {
    const fieldName = `${playerKey}_shirt_color`;
    return (
      <div className="field shirt-color-field">
        <label>{label}</label>
        <div className="shirt-color-grid" role="radiogroup" aria-label={`${label} shirt color`}>
          {PLAYER_SHIRT_COLORS.map((color) => {
            const selected = gameSettingsForm[fieldName] === color.value;
            return (
              <button
                aria-checked={selected}
                className={`shirt-color-option${selected ? " shirt-color-option--selected" : ""}`}
                key={`${fieldName}-${color.value}`}
                role="radio"
                type="button"
                onClick={() =>
                  setGameSettingsForm((current) => ({
                    ...current,
                    [fieldName]: color.value,
                  }))
                }
              >
                <span
                  aria-hidden="true"
                  className="shirt-color-swatch"
                  style={{
                    background: color.background,
                    borderColor: color.border,
                  }}
                />
                <span>{color.label}</span>
              </button>
            );
          })}
        </div>
      </div>
    );
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
  const isWarmupCountdownWarning = timerRunning
    && (timerPhase === "warmup_side_one" || timerPhase === "warmup_side_two")
    && timerSeconds <= 10
    && timerSeconds > 0;

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
                      className={[
                        "timer-chip",
                        "timer-chip--button",
                        "timer-chip--overlay",
                        timerRunning ? "" : "timer-chip--paused",
                        isWarmupCountdownWarning ? "timer-chip--warmup-warning" : "",
                      ].join(" ").trim()}
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

      {showGameSettingsOverlay ? (
        <div className="overlay-backdrop">
          <form className="overlay-panel overlay-panel--game-settings stack" onSubmit={handleSaveGameSettings}>
            <div className="settings-header-row">
              <h2>Game Settings</h2>
              <button
                aria-label="Close game settings"
                className="help-close-button"
                type="button"
                onClick={() => setShowGameSettingsOverlay(false)}
              >
                &times;
              </button>
            </div>
            <div className="game-settings-match-grid">
              <div className="field">
                <label htmlFor="live_best_of">Match Format</label>
                <select
                  id="live_best_of"
                  value={gameSettingsForm.best_of}
                  onChange={(event) =>
                    setGameSettingsForm((current) => ({
                      ...current,
                      best_of: Number(event.target.value),
                    }))
                  }
                >
                  {bestOfOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label htmlFor="live_score_type">Game Format</label>
                <select
                  id="live_score_type"
                  value={gameSettingsForm.score_type}
                  onChange={(event) =>
                    setGameSettingsForm((current) => ({
                      ...current,
                      score_type: Number(event.target.value),
                    }))
                  }
                >
                  {scoreTypeOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            {canChoosePlayerShirtColors ? (
              <div className="game-settings-shirt-grid">
                {renderShirtColorField("player1", "Player 1 Shirt")}
                {renderShirtColorField("player2", "Player 2 Shirt")}
              </div>
            ) : null}
            {error ? <div className="notice error">{error}</div> : null}
            <div className="button-row game-settings-actions">
              <button disabled={loading} type="submit">
                Save
              </button>
              <button
                className="secondary"
                disabled={loading}
                type="button"
                onClick={() => setShowGameSettingsOverlay(false)}
              >
                Cancel
              </button>
            </div>
          </form>
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
              undoDisabled={undoLocked}
              onEventAction={(actionType, payload) =>
                sendEventAction(matchId, actionType, payload)
              }
              onUndo={() => undoLastAction(matchId)}
              onEndMatch={async (payload) => {
                const finalDuration = Math.max(0, resolveMatchDurationSeconds());
                setTimerRunning(false);
                setTimerSeconds(finalDuration);
                const updatedMatch = await endMatch(matchId, {
                  ...payload,
                  match_duration_seconds: finalDuration,
                });
                if (updatedMatch?.status === "completed") {
                  navigate("/dashboard");
                }
              }}
              onOpenSettings={openGameSettings}
            />
          </Scoreboard>
          <Timer
            disabled={matchComplete}
            helperText={timerHelperText}
            label={timerLabel}
            onSkip={timerSkipLabel ? handleSkipTimedPhase : undefined}
            onToggle={handleToggleTimer}
            running={timerRunning && !matchComplete}
            seconds={matchComplete && recordedMatchDurationSeconds > 0 ? recordedMatchDurationSeconds : timerSeconds}
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
            Open this URL on the venue display, TV browser, or secondary tablet, then enter the court display code below.
          </p>
          <input className="read-only-input" readOnly value={scoreboardUrl} />
          <div className="field">
            <label htmlFor="spectator_display_code">Court Display Code</label>
            <input
              className="read-only-input"
              id="spectator_display_code"
              readOnly
              value={displayCode || "Generate a display code for this court in Settings."}
            />
          </div>
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
