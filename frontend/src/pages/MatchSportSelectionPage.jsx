import React from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { getPlayableMatchSports } from "../constants/matchSports";
import { useAuth } from "../hooks/useAuth";

export default function MatchSportSelectionPage() {
  const navigate = useNavigate();
  const { session } = useAuth();
  const availableSports = getPlayableMatchSports(session?.enabled_sports);

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
          <p>Choose from the racket sports that are enabled for your account or club.</p>
        </div>

        <div className="match-sport-overlay__grid">
          {availableSports.map((sport) => (
            <button
              key={sport.value}
              className="match-sport-overlay__option"
              type="button"
              onClick={() => handleSelectSport(sport.value)}
            >
              <strong>{sport.label}</strong>
            </button>
          ))}
        </div>
      </section>

      <AppFooter />
    </main>
  );
}
