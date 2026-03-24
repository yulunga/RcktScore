import React, { useEffect } from "react";
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

  useEffect(() => {
    loadMatch(matchId);
    const disconnect = connectRealtime(matchId);
    return disconnect;
  }, [connectRealtime, loadMatch, matchId]);

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        subtitle="Manage the live scoring session."
        title={session?.organization_name || currentMatch?.organization_name || "Live Match"}
      />

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
        </div>

        <div className="stack match-secondary-column">
          <Timer />
          {loading ? <div className="notice">Syncing match state...</div> : null}
          {error ? <div className="notice error">{error}</div> : null}
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
