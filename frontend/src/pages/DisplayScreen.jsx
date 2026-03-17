import { useEffect } from "react";
import { useSearchParams } from "react-router-dom";

import EventTimeline from "../components/EventTimeline";
import Scoreboard from "../components/Scoreboard";
import { useMatch } from "../hooks/useMatch";

export default function DisplayScreen() {
  const [searchParams] = useSearchParams();
  const matchId = searchParams.get("match");
  const { currentMatch, connectRealtime, error, loadMatch, loading } = useMatch();

  useEffect(() => {
    if (!matchId) {
      return undefined;
    }

    loadMatch(matchId);
    const disconnect = connectRealtime(matchId);
    return disconnect;
  }, [connectRealtime, loadMatch, matchId]);

  return (
    <main className="page-shell stack">
      <section className="hero-card">
        <span className="status-pill">Spectator Display</span>
        <h1>Live Court Display</h1>
      </section>
      {!matchId ? (
        <div className="notice error">
          No match was selected. Open this screen with a `?match=` query value.
        </div>
      ) : null}
      {loading ? <div className="notice">Loading live match...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}
      <Scoreboard match={currentMatch} />
      <EventTimeline events={currentMatch?.state?.events || []} />
    </main>
  );
}
