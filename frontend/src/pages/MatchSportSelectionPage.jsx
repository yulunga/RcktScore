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

  function handleClose() {
    navigate("/dashboard");
  }

  return (
    <main className="page-shell stack match-sport-selection-page">
      <ClubPageHeader showMobileMenu={false} />

      <section className="panel stack match-sport-selection-card">
        <header className="match-sport-selection-card__heading">
          <div className="section-heading stack compact">
            <h1>Choose Racket Sport</h1>
            <p>Select a sport to start match setup.</p>
          </div>
          <button className="match-sport-selection-card__close" type="button" onClick={handleClose}>Close</button>
        </header>

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
              aria-label={`Start a ${sport.label} match`}
              onClick={() => handleSelectSport(sport.value)}
            >
              <MatchSportArtwork sport={sport.value} />
              <span className="match-sport-overlay__option-label"><i aria-hidden="true" /><strong>{sport.label}</strong></span>
            </button>
          ))}
        </div>
      </section>

    </main>
  );
}
