import React, { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import EventTimeline from "../components/EventTimeline";
import Scoreboard from "../components/Scoreboard";
import { useMatch } from "../hooks/useMatch";

export default function DisplayScreen() {
  const [searchParams] = useSearchParams();
  const matchId = searchParams.get("match");
  const { currentMatch, connectRealtime, error, loadMatch, loading } = useMatch();
  const [showTimeline, setShowTimeline] = useState(false);
  const [displayMode, setDisplayMode] = useState("large-scores");

  useEffect(() => {
    if (!matchId) {
      return undefined;
    }

    loadMatch(matchId);
    const disconnect = connectRealtime(matchId);
    return disconnect;
  }, [connectRealtime, loadMatch, matchId]);

  return (
    <main className={`page-shell stack display-shell display-mode-${displayMode}`}>
      <section className="hero-card display-header-card">
        <div className="display-header-card__top">
          <h1>RcktScore Live Display</h1>
          <div className="display-header-card__controls">
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
      {!matchId ? (
        <div className="notice error">
          No match was selected. Open this screen with a `?match=` query value.
        </div>
      ) : null}
      {loading ? <div className="notice">Loading live match...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}
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
      <AppFooter />
    </main>
  );
}
