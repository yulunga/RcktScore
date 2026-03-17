import React, { useEffect } from "react";
import { useParams } from "react-router-dom";

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
    scorePoint,
    sendEventAction,
    undoLastAction,
  } = useMatch();
  const displayUrl = `${window.location.origin}/display?match=${matchId}`;

  useEffect(() => {
    loadMatch(matchId);
    const disconnect = connectRealtime(matchId);
    return disconnect;
  }, [connectRealtime, loadMatch, matchId]);

  return (
    <main className="page-shell grid two-column">
      <div className="stack">
        <SessionBar />
        <Scoreboard match={currentMatch} />
        <MatchControls
          disabled={!currentMatch || loading}
          onScorePoint={(scorer) => scorePoint(matchId, scorer)}
          onEventAction={(actionType, payload) =>
            sendEventAction(matchId, actionType, payload)
          }
          onUndo={() => undoLastAction(matchId)}
        />
      </div>

      <div className="stack">
        <Timer />
        <section className="panel stack">
          <h2>Spectator Display</h2>
          <p className="helper-text">
            Open this URL on the venue display, TV browser, or secondary tablet.
          </p>
          <input className="read-only-input" readOnly value={displayUrl} />
        </section>
        {loading ? <div className="notice">Syncing match state...</div> : null}
        {error ? <div className="notice error">{error}</div> : null}
        <EventTimeline events={currentMatch?.state?.events || []} />
      </div>
    </main>
  );
}
