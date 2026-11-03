import React from "react";
import { useNavigate } from "react-router-dom";

import AccountContextSwitcher from "../components/AccountContextSwitcher";
import ClubPageHeader from "../components/ClubPageHeader";
import MatchSportArtwork from "../components/MatchSportArtwork";
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
    <main className="page-shell stack match-sport-selection-page">
      <ClubPageHeader />

      <section className="panel stack match-sport-selection-card">
        <div className="section-heading stack compact">
          <h2>Personal or Club Match</h2>
          <p>Confirm the match account, then choose a racket sport.</p>
        </div>

        <AccountContextSwitcher
          className="account-context-switcher--match-start"
          label="Score this match for"
        />

        <div className="match-sport-overlay__grid">
          {availableSports.map((sport) => (
            <button
              key={sport.value}
              className="match-sport-overlay__option"
              type="button"
              onClick={() => handleSelectSport(sport.value)}
            >
              <MatchSportArtwork sport={sport.value} />
              <strong>{sport.label}</strong>
            </button>
          ))}
        </div>
      </section>

    </main>
  );
}
