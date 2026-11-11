import React, { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { archiveRootAdminMatch, deleteRootAdminMatch, getRootAdminMatch, getRootAdminMatches } from "../services/api";

const PAGE_SIZE = 50;
const SPORT_ABBREVIATIONS = {
  squash: "S", racketball: "RB", tennis: "T", padel: "Pa",
  table_tennis: "TT", badminton: "B", pickleball: "Pi",
};
const DIRECTORY = "/rckscoreAdmin/matches";
const dateKey = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/London", year: "numeric", month: "2-digit", day: "2-digit" });
const dateTime = new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/London", dateStyle: "medium", timeStyle: "short" });
const matchDate = (match) => match.completed_at || match.created_at;
const participants = (match) => `${match.player1_display_name} vs ${match.player2_display_name}`;

function MatchIcon({ path }) {
  return <svg aria-hidden="true" viewBox="0 0 24 24"><path d={path} /></svg>;
}

function MatchDirectory() {
  const navigate = useNavigate();
  const [directory, setDirectory] = useState(null);
  const [sport, setSport] = useState("");
  const [organization, setOrganization] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [page, setPage] = useState(1);
  const [archiving, setArchiving] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let current = true;
    getRootAdminMatches().then(
      (response) => { if (current) setDirectory(response.rootAdminMatches); },
      (failure) => { if (current) setError(failure.message); },
    );
    return () => { current = false; };
  }, []);

  const invalidRange = from && to && from > to;
  const scopedMatches = (directory?.matches || []).filter((match) => {
    const day = dateKey.format(new Date(matchDate(match)));
    return !invalidRange
      && match.organization_name.toLowerCase().includes(organization.trim().toLowerCase())
      && (!from || day >= from)
      && (!(to || from) || day <= (to || from));
  });
  const matches = scopedMatches.filter((match) => !sport || match.sport === sport);
  const pageCount = Math.max(1, Math.ceil(matches.length / PAGE_SIZE));
  const currentPage = Math.min(page, pageCount);
  const firstIndex = (currentPage - 1) * PAGE_SIZE;
  const visibleMatches = matches.slice(firstIndex, firstIndex + PAGE_SIZE);
  const completedBySport = new Map();
  for (const match of scopedMatches) {
    if (match.status === "completed") {
      completedBySport.set(match.sport, (completedBySport.get(match.sport) || 0) + 1);
    }
  }

  async function archive(match) {
    if (!window.confirm(`Archive ${participants(match)}? It will disappear from standard views.`)) return;
    setArchiving(match.id);
    setError("");
    try {
      await archiveRootAdminMatch(match.id);
      setDirectory((current) => ({ ...current, matches: current.matches.filter((row) => row.id !== match.id) }));
    } catch (failure) {
      setError(failure.message);
    } finally {
      setArchiving(null);
    }
  }

  return (
    <section className="panel stack">
      <h1>Match Directory</h1>
      <div className="root-admin-match-filters">
        <label className="field">Racket Sport
          <select value={sport} onChange={(event) => { setSport(event.target.value); setPage(1); }}>
            <option value="">All Sports</option>
            {directory?.sports.map(({ value, label }) => <option key={value} value={value}>{label}</option>)}
          </select>
        </label>
        <label className="field">Organisation
          <input type="search" list="root-admin-match-organisations" placeholder="Search by club or account name" value={organization} onChange={(event) => { setOrganization(event.target.value); setPage(1); }} />
          <datalist id="root-admin-match-organisations">
            {directory?.organizations.map((org) => <option key={org.id} value={org.organization_name} />)}
          </datalist>
        </label>
        <label className="field">Match date / From
          <input type="date" value={from} onChange={(event) => { setFrom(event.target.value); setPage(1); }} />
        </label>
        <label className="field">To (optional)
          <input type="date" value={to} onChange={(event) => { setTo(event.target.value); setPage(1); }} />
        </label>
      </div>
      <p className="helper-text">Enter a From date for a single day, or both dates for an inclusive range. Dates use UK time.</p>
      {invalidRange ? <div className="notice error">The To date must be on or after the From date.</div> : null}
      {error ? <div className="notice error">{error}</div> : null}
      {!directory && !error ? <div className="notice">Loading matches…</div> : null}
      {directory ? (
        <>
          <section className="dashboard-item stack compact">
            <h2>Completed matches by racket sport</h2>
            <div className="root-admin-match-details">
              {directory.sports.map(({ value, label }) => (
                <span key={value}>{label} <strong>{completedBySport.get(value) || 0}</strong></span>
              ))}
            </div>
          </section>
          <p className="helper-text" aria-live="polite">{matches.length ? firstIndex + 1 : 0}–{firstIndex + visibleMatches.length} of {matches.length} matches</p>
          {!matches.length && !invalidRange ? <div className="dashboard-empty">No matches match the current filters.</div> : null}
          <div className="root-admin-match-list">
            {visibleMatches.map((match) => (
              <article key={match.id} className="root-admin-match-row">
                <span className={`root-admin-match-sport root-admin-match-sport--${match.sport}`} role="img" aria-label={match.sport_label} title={match.sport_label}>
                  {SPORT_ABBREVIATIONS[match.sport] || "?"}
                </span>
                <h3 className="root-admin-match-heading">
                  <span className="root-admin-match-player-one">{match.player1_display_name}</span>
                  <span>vs</span>
                  <span className="root-admin-match-player-two">{match.player2_display_name}</span>
                  <span
                    className={match.status === "completed" ? "root-admin-match-complete" : "root-admin-match-incomplete"}
                    role="img"
                    aria-label={match.status}
                    title={match.status}
                  >
                    {match.status === "completed" ? "✓" : "✕"}
                  </span>
                </h3>
                <time dateTime={matchDate(match)}>{dateTime.format(new Date(matchDate(match)))}</time>
                  <span className={`status-pill root-admin-match-${match.organization_type === "personal" ? "personal" : "club"}`}>
                    {match.organization_type === "personal" ? "Personal" : match.organization_name}
                  </span>
                <div className="button-row root-admin-match-actions">
                  <button type="button" className="root-admin-icon-button" aria-label={`View match: ${participants(match)}`} title="View match" onClick={() => navigate(`${DIRECTORY}/${match.id}`)}>
                    <MatchIcon path="M2 12s4-6 10-6 10 6 10 6-4 6-10 6S2 12 2 12zm13 0a3 3 0 1 0-6 0 3 3 0 0 0 6 0z" />
                  </button>
                  <button type="button" className="secondary root-admin-icon-button" aria-label={`Archive match: ${participants(match)}`} title="Archive match" disabled={Boolean(archiving)} onClick={() => archive(match)}>
                    <MatchIcon path="M3 4h18v5H3zM5 9v11h14V9m-10 4h6" />
                  </button>
                </div>
              </article>
            ))}
          </div>
          {pageCount > 1 ? (
            <nav className="button-row" aria-label="Match pages">
              <button type="button" className="secondary" disabled={currentPage === 1} onClick={() => setPage(currentPage - 1)}>Previous</button>
              <span className="helper-text">Page {currentPage} of {pageCount}</span>
              <button type="button" className="secondary" disabled={currentPage === pageCount} onClick={() => setPage(currentPage + 1)}>Next</button>
            </nav>
          ) : null}
        </>
      ) : null}
    </section>
  );
}

function detailLabel(key) {
  return key.replaceAll("_", " ").replace(/^./, (character) => character.toUpperCase());
}

function detailValue(key, value) {
  if (value == null || value === "") return "—";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  if (key.endsWith("_at")) return dateTime.format(new Date(value));
  return String(value);
}

function MatchDetail({ matchId }) {
  const navigate = useNavigate();
  const [match, setMatch] = useState(null);
  const [confirmation, setConfirmation] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let current = true;
    getRootAdminMatch(matchId).then(
      (response) => { if (current) setMatch(response.match); },
      (failure) => { if (current) setError(failure.message); },
    );
    return () => { current = false; };
  }, [matchId]);

  async function remove(event) {
    event.preventDefault();
    if (confirmation !== "DELETE" || deleting) return;
    setDeleting(true);
    setError("");
    try {
      await deleteRootAdminMatch(matchId, confirmation);
      navigate(DIRECTORY, { replace: true });
    } catch (failure) {
      setError(failure.message);
      setDeleting(false);
    }
  }

  return (
    <section className="panel stack">
      <div className="root-admin-section-header">
        <h1>{match ? participants(match) : "Match Details"}</h1>
        <button type="button" className="secondary" onClick={() => navigate(DIRECTORY)}>Back to Matches</button>
      </div>
      {error ? <div className="notice error" role="alert">{error}</div> : null}
      {!match && !error ? <div className="notice">Loading match…</div> : null}
      {match ? (
        <>
          <dl className="root-admin-profile-detail-grid">
            {Object.entries(match).filter(([key, value]) => key !== "state" && key !== "court_display_code" && typeof value !== "object").map(([key, value]) => (
              <div key={key}><dt>{detailLabel(key)}</dt><dd>{detailValue(key, value)}</dd></div>
            ))}
          </dl>
          <h2>Score and match activity</h2>
          <dl className="root-admin-profile-detail-grid">
            {Object.entries(match.state).filter(([, value]) => value !== null && typeof value !== "object").map(([key, value]) => (
              <div key={key}><dt>{detailLabel(key)}</dt><dd>{detailValue(key, value)}</dd></div>
            ))}
          </dl>
          <h2>Scoring timeline</h2>
          {match.state.events?.length ? (
            <ol className="root-admin-match-timeline">
              {match.state.events.map((event) => (
                <li key={event.id}>
                  <time dateTime={event.created_at}>{detailValue("created_at", event.created_at)}</time>
                  <span>{event.summary || detailLabel(event.event_type)}</span>
                </li>
              ))}
            </ol>
          ) : <p className="helper-text">No scoring events recorded.</p>}
          <details>
            <summary>Full scoring data, lineups and game or set history</summary>
            <pre className="root-admin-match-state">{JSON.stringify(match.state, null, 2)}</pre>
          </details>
          <form className="stack compact" onSubmit={remove}>
            <h2>Delete match</h2>
            <p>Permanently delete this match and its scoring records. Any separate tournament bracket result is retained.</p>
            <label className="field">Type DELETE to confirm
              <input value={confirmation} onChange={(event) => setConfirmation(event.target.value)} autoComplete="off" />
            </label>
            <div><button type="submit" className="danger" disabled={confirmation !== "DELETE" || deleting}>{deleting ? "Deleting…" : "Delete match"}</button></div>
          </form>
        </>
      ) : null}
    </section>
  );
}

export default function RootAdminMatchesPage() {
  const { matchId } = useParams();
  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />
      {matchId ? <MatchDetail key={matchId} matchId={matchId} /> : <MatchDirectory />}
      <AppFooter />
    </main>
  );
}
