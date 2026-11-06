import React from "react";

const BALL_ASSETS = {
  squash: "/sports/balls/squash.png",
  racketball: "/sports/balls/racketball.png",
  tennis: "/sports/balls/tennis.png",
  padel: "/sports/balls/padel.png",
};

export default function MatchSportArtwork({ sport }) {
  const isSquashCourt = sport === "squash" || sport === "racketball";
  const ballAsset = BALL_ASSETS[sport];

  return (
    <span className={`match-sport-artwork match-sport-artwork--${sport}`} aria-hidden="true">
      <svg className="match-sport-artwork__court" viewBox="0 0 120 120">
        <rect x="3" y="3" width="114" height="114" rx="3" />
        {isSquashCourt ? (
          <>
            <path d="M3 56h114M3 76h31M86 76h31" />
            <path d="M34 56v20M86 56v20M60 56v31" />
          </>
        ) : (
          <>
            <path d="M3 59h114M60 35v48" />
            <path d="M3 35h114M3 83h114" />
            {sport === "tennis" ? <path d="M12 3v114M108 3v114" /> : null}
            {sport === "padel" ? <rect x="10" y="10" width="100" height="100" rx="2" /> : null}
          </>
        )}
      </svg>
      {ballAsset ? (
        <img className="match-sport-artwork__ball-image" src={ballAsset} alt="" />
      ) : (
        <span className="match-sport-artwork__ball match-sport-artwork__ball--fallback" />
      )}
    </span>
  );
}
