import { useEffect } from "react";
import { useParams } from "react-router-dom";

import EventTimeline from "../components/EventTimeline";
import MatchControls from "../components/MatchControls";
import Scoreboard from "../components/Scoreboard";
import Timer from "../components/Timer";
import { useMatch } from "../hooks/useMatch";

export default function MatchScreen() {
  const { matchId } = useParams();
  const {
    currentMatch,
    error,
    loadMatch,
    connectRealtime,
    scorePoint,
    sendEventAction,
    undoLastAction,
  } = useMatch();

  useEffect(() => {
    loadMatch(matchId);
    const disconnect = connectRealtime(matchId);
    return disconnect;
  }, [connectRealtime, loadMatch, matchId]);

  return (
    <main className="page-shell grid two-column">
      <div className="stack">
        <Scoreboard match={currentMatch} />
        <MatchControls
          disabled={!currentMatch}
          onScorePoint={(scorer) => scorePoint(matchId, scorer)}
          onEventAction={(actionType, payload) =>
            sendEventAction(matchId, actionType, payload)
          }
          onUndo={() => undoLastAction(matchId)}
        />
      </div>

      <div className="stack">
        <Timer />
        {error ? <div className="notice error">{error}</div> : null}
        <EventTimeline events={currentMatch?.state?.events || []} />
      </div>
    </main>
  );
}
