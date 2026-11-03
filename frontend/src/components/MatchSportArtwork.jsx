import React from "react";

export default function MatchSportArtwork({ sport }) {
  const isSquashCourt = sport === "squash" || sport === "racketball";

  return (
    <span className={`match-sport-artwork match-sport-artwork--${sport}`} aria-hidden="true">
      <svg className="match-sport-artwork__court" viewBox="0 0 120 76">
        <rect x="3" y="3" width="114" height="70" rx="10" />
        {isSquashCourt ? (
          <>
            <path d="M18 17h84M18 57h84M60 17v40" />
            <path d="M29 57 18 73M91 57l11 16" />
          </>
        ) : (
          <>
            <path d="M60 3v70M3 38h114" />
            <path d="M18 3v70M102 3v70" />
            {sport === "padel" ? <path d="M10 10h100v56H10z" /> : null}
          </>
        )}
      </svg>
      <span className="match-sport-artwork__ball" />
    </span>
  );
}
