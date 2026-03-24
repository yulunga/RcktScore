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

const WARMUP_SECONDS = 120;
const INTERVAL_SECONDS = 90;

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
  const displayUrl = `${window.location.origin}/display?match=${matchId}`;
  const live = currentMatch?.state ?? {};
  const gameHistory = live.game_history || [];
  const serviceSide = live.service_side || "Right";
  const [timerPhase, setTimerPhase] = useState("warmup_ready");
  const [timerSeconds, setTimerSeconds] = useState(WARMUP_SECONDS);
  const [timerRunning, setTimerRunning] = useState(false);
  const [showWarmupOverlay, setShowWarmupOverlay] = useState(false);
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
      window.alert("Two minutes are over. Ask the players to change sides.");
      setTimerPhase("warmup_side_two");
      setTimerSeconds(WARMUP_SECONDS);
      setTimerRunning(true);
      return;
    }

    if (timerPhase === "warmup_side_two") {
      window.alert("Warm-up complete. Start the game.");
      setTimerPhase("match_live");
      setTimerSeconds(0);
      setTimerRunning(true);
      return;
    }

    if (timerPhase === "interval") {
      window.alert("The 90 second interval is complete. Resume play.");
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
      return "Between Games";
    }

    return "Match Clock";
  }, [timerPhase]);

  const timerHelperText = useMemo(() => {
    if (timerPhase === "warmup_ready") {
      return "Start the warm-up when both players are ready.";
    }

    if (timerPhase === "warmup_side_one" || timerPhase === "warmup_side_two") {
      return "Warm-up runs for 2 minutes on each side of the court.";
    }

    if (timerPhase === "interval") {
      return "Players have a 90 second interval between games.";
    }

    return "Pause or reset the current live match clock if needed.";
  }, [timerPhase]);

  function handleStartWarmup() {
    setShowWarmupOverlay(false);
    setTimerPhase("warmup_side_one");
    setTimerSeconds(WARMUP_SECONDS);
    setTimerRunning(true);
  }

  function handleToggleTimer() {
    if (timerPhase === "warmup_ready") {
      handleStartWarmup();
      return;
    }

    setTimerRunning((value) => !value);
  }

  function handleResetTimer() {
    setTimerRunning(false);
    setTimerSeconds(defaultSecondsForPhase(timerPhase));
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        subtitle="Manage the live scoring session."
        title={session?.organization_name || currentMatch?.organization_name || "Live Match"}
      />

      {showWarmupOverlay ? (
        <div className="overlay-backdrop">
          <div className="overlay-panel stack">
            <h2>Start Warm-Up</h2>
            <p className="helper-text">
              Start the warm-up timer when both players are ready. The timer will run for two minutes,
              then alert the scorer to change sides for the second two-minute warm-up.
            </p>
            <div className="button-row">
              <button type="button" onClick={handleStartWarmup}>
                Start Warm-Up
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {currentMatch ? (
        <section className="panel stack">
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

          <div className="game-history-strip match-history-strip">
            {gameHistory.length === 0 ? (
              <div className="meta-item meta-item--compact">No completed games yet.</div>
            ) : (
              gameHistory.map((game) => (
                <div className="meta-item meta-item--compact" key={`game-${game.game_number}`}>
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
      ) : null}

      <div className="grid two-column match-top-grid">
        <div className="stack match-primary-column">
          <Scoreboard match={currentMatch} />
          <MatchControls
            disabled={!currentMatch || loading}
            match={currentMatch}
            onScorePoint={(scorer) => scorePoint(matchId, scorer)}
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
            onBackToMatches={() => navigate("/dashboard")}
          />
        </div>

        <div className="stack match-secondary-column">
          <Timer
            helperText={timerHelperText}
            label={timerLabel}
            onReset={handleResetTimer}
            onToggle={handleToggleTimer}
            running={timerRunning}
            seconds={timerSeconds}
            title="Match Timer"
          />
          {loading ? <div className="notice">Syncing match state...</div> : null}
          {error ? <div className="notice error">{error}</div> : null}
          <section className="panel stack">
            <h2>Spectator Display</h2>
            <p className="helper-text">
              Open this URL on the venue display, TV browser, or secondary tablet.
            </p>
            <input className="read-only-input" readOnly value={displayUrl} />
          </section>
        </div>
      </div>

      <div className="stack match-bottom-stack">
        {currentMatch?.updated_at ? (
          <div className="notice match-updated-notice">Updated: {formatDate(currentMatch.updated_at)}</div>
        ) : null}
        <EventTimeline events={currentMatch?.state?.events || []} />
      </div>
      <AppFooter />
    </main>
  );
}
