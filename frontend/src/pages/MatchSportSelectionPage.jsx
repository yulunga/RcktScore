import React from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { MATCH_SPORT_OPTIONS } from "../constants/matchSports";

export default function MatchSportSelectionPage() {
  const navigate = useNavigate();

  function handleSelectSport(sport) {
    navigate(`/match/new/setup?sport=${encodeURIComponent(sport)}`);
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        actions={[
          {
            label: "Back to Dashboard",
            onClick: () => navigate("/dashboard"),
          },
        ]}
        subtitle="Choose the racket sport first, then continue into the correct match setup flow."
        title="Choose Racket Sport"
      />

      <section className="panel stack">
        <div className="section-heading stack compact">
          <h2>Start New Match</h2>
          <p>Squash and racketball currently share the same setup screen.</p>
        </div>

        <div className="match-sport-overlay__grid">
          {MATCH_SPORT_OPTIONS.map((sport) => (
            <button
              key={sport.value}
              className="match-sport-overlay__option"
              type="button"
              onClick={() => handleSelectSport(sport.value)}
            >
              <strong>{sport.label}</strong>
              <span>Available now</span>
              <p>{sport.note}</p>
            </button>
          ))}
        </div>
      </section>

      <AppFooter />
    </main>
  );
}
