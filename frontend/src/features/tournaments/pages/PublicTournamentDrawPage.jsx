import React, { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import { getPublicTournamentDraw } from "../../../services/api";
import TournamentBracket from "../components/TournamentBracket";
import { optionLabel, TOURNAMENT_FORMATS, TOURNAMENT_SPORTS } from "../tournamentOptions";

function publicPlateDraw(draw) {
  const mainMatches = (draw.matches || []).filter((match) => match.player1_entry_id && match.player2_entry_id);
  const matches = [];
  for (let index = 0; index < mainMatches.length; index += 2) {
    matches.push({
      id: `${draw.id}-plate-${index / 2 + 1}`,
      round_number: 1,
      player1_name: `Loser Championship Match ${index + 1}`,
      player2_name: mainMatches[index + 1] ? `Loser Championship Match ${index + 2}` : "Bye",
    });
  }
  return { id: `${draw.id}-plate`, name: `${draw.name} Plate`, matches };
}

export default function PublicTournamentDrawPage() {
  const { accessKey } = useParams();
  const navigate = useNavigate();
  const [keyInput, setKeyInput] = useState(accessKey || "");
  const [tournament, setTournament] = useState(null);
  const [loading, setLoading] = useState(Boolean(accessKey));
  const [error, setError] = useState("");

  useEffect(() => {
    if (!accessKey) return;
    setLoading(true);
    setError("");
    getPublicTournamentDraw(accessKey)
      .then((response) => setTournament(response?.tournament || null))
      .catch((requestError) => setError(requestError.message || "Published tournament draw not found."))
      .finally(() => setLoading(false));
  }, [accessKey]);

  function openDraw(event) {
    event.preventDefault();
    const normalized = keyInput.toUpperCase().replace(/[^A-Z0-9]/g, "");
    if (normalized) navigate(`/tournament-draw/${normalized}`);
  }

  return (
    <main className="page-shell public-tournament-page stack">
      <header className="panel public-tournament-header">
        <a href="https://www.hitnscore.com/" aria-label="HitNScore home"><strong>Hit<span>n</span>Score</strong></a>
        <p>Public Tournament Draw</p>
      </header>

      {!accessKey ? (
        <section className="panel public-tournament-key-card stack">
          <div className="panel-heading">
            <h1>View a Tournament Draw</h1>
            <p className="helper-text">Enter the draw key supplied by the tournament organiser. No login is required.</p>
          </div>
          <form className="stack" onSubmit={openDraw}>
            <div className="field">
              <label htmlFor="public-tournament-key">Tournament Draw Key</label>
              <input id="public-tournament-key" autoCapitalize="characters" required value={keyInput} onChange={(event) => setKeyInput(event.target.value)} />
            </div>
            <div className="button-row"><button type="submit">View Draw</button></div>
          </form>
        </section>
      ) : null}

      {loading ? <div className="notice">Loading published draw...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}
      {tournament ? (
        <>
          <section className="panel stack">
            <div className="panel-heading">
              <h1>{tournament.name}</h1>
              <p className="helper-text">{optionLabel(TOURNAMENT_SPORTS, tournament.sport)} · {optionLabel(TOURNAMENT_FORMATS, tournament.draw_format)}</p>
            </div>
            <div className="tournament-summary-details">
              <span>Venue: {tournament.venue_name || "Not set"}</span>
              <span>Start: {tournament.starts_on || "Not set"} · End: {tournament.ends_on || "Not set"}</span>
              <span>{tournament.audience === "open" ? "Open tournament" : "Internal tournament"}</span>
              <span>{tournament.graded_enabled ? "Graded tournament" : "Ungraded tournament"}</span>
            </div>
          </section>
          {(tournament.draws || []).filter((draw) => (draw.matches || []).length).map((draw) => (
            <section className="panel" key={draw.id || draw.name}>
              {tournament.draw_format === "knockout" || tournament.draw_format === "knockout_plate" ? (
                <div className="stack">
                  <TournamentBracket draw={draw} entries={tournament.entries || []} title={`${draw.name} — Championship`} />
                  {tournament.draw_format === "knockout_plate" && ((draw.plate_matches || []).length || publicPlateDraw(draw).matches.length) ? (
                    <TournamentBracket draw={(draw.plate_matches || []).length ? { ...draw, id: `${draw.id}-plate`, matches: draw.plate_matches } : publicPlateDraw(draw)} title={`${draw.name} — Plate`} />
                  ) : null}
                </div>
              ) : (
                <div className="stack">
                  <h2>{draw.name}</h2>
                  {(draw.matches || []).map((match) => <div className="tournament-draw-match" key={match.id}><span>{match.player1_name}</span><small>vs</small><span>{match.player2_name}</span></div>)}
                </div>
              )}
            </section>
          ))}
        </>
      ) : null}
    </main>
  );
}
