import React, { useEffect } from "react";
import { useNavigate, useParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import EventTimeline from "../components/EventTimeline";
import MatchControls from "../components/MatchControls";
import Scoreboard from "../components/Scoreboard";
import SessionBar from "../components/SessionBar";
import Timer from "../components/Timer";
import { useMatch } from "../hooks/useMatch";

export default function MatchScreen() {
  const { matchId } = useParams();
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

  useEffect(() => {
    loadMatch(matchId);
    const disconnect = connectRealtime(matchId);
    return disconnect;
  }, [connectRealtime, loadMatch, matchId]);

  return (
    <main className="page-shell stack">
      <div className="grid two-column">
        <div className="stack">
          <SessionBar />
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

        <div className="stack">
          <Timer />
          {loading ? <div className="notice">Syncing match state...</div> : null}
          {error ? <div className="notice error">{error}</div> : null}
          <EventTimeline events={currentMatch?.state?.events || []} />
          <section className="panel stack">
            <h2>Spectator Display</h2>
            <p className="helper-text">
              Open this URL on the venue display, TV browser, or secondary tablet.
            </p>
            <input className="read-only-input" readOnly value={displayUrl} />
          </section>
        </div>
      </div>
      <AppFooter />
    </main>
  );
}
