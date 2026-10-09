import React, { useCallback, useEffect, useRef, useState } from "react";
import { useParams } from "react-router-dom";

import AppFooter from "../../../components/AppFooter";
import ClubPageHeader from "../../../components/ClubPageHeader";
import { useAuth } from "../../../hooks/useAuth";
import { createTournamentEntry, getTournament, searchTournamentPlayers } from "../../../services/api";
import { optionLabel, TOURNAMENT_FORMATS, TOURNAMENT_SPORTS } from "../tournamentOptions";

const EMPTY_ENTRY = {
  first_name: "",
  surname: "",
  email: "",
  home_club_name: "",
  ability_level: "",
};

const ABILITY_OPTIONS = [
  { value: "1", grade: "D", label: "Racket up is this way", detail: "New player learning grip, contact and basic movement." },
  { value: "2", grade: "C", label: "Developing player", detail: "Can serve, return and sustain a short rally." },
  { value: "3", grade: "B", label: "Club player", detail: "Consistent rallies with sound movement and match awareness." },
  { value: "4", grade: "A", label: "Advanced player", detail: "Experienced league or tournament competitor." },
];

function describeAddedPlayer(entry) {
  if (!entry) {
    return "Player added to the tournament. Tournament entry does not grant app or club access.";
  }
  if (entry.claim_status === "linked" && entry.relationship === "member") {
    return "Player added as a linked HitNScore club member. Their existing app role, plan and access are unchanged.";
  }
  if (entry.claim_status === "linked") {
    return "Player added as a guest linked to an existing HitNScore account. This does not grant membership, a role or access to this club.";
  }
  if (entry.claim_status === "claimable") {
    return "Player added as a claimable guest. They have no login, role, plan or club access from this tournament entry.";
  }
  return "Player added as an unclaimed named guest. They have no login, role, plan or club access.";
}

function findAddedEntry(nextTournament, player) {
  const entries = nextTournament?.entries || [];
  if (player.player_id) {
    return entries.find((entry) => entry.player_id === player.player_id);
  }
  const email = (player.email || "").trim().toLowerCase();
  if (email) {
    return entries.find((entry) => (entry.email || "").trim().toLowerCase() === email);
  }
  return entries.find((entry) => (
    entry.first_name === player.first_name && entry.surname === player.surname
  ));
}

function AbilitySelector({ value, onChange, idPrefix }) {
  return (
    <fieldset className="tournament-ability-fieldset">
      <legend>Player Ability</legend>
      <div className="tournament-ability-options">
        {ABILITY_OPTIONS.map((option) => (
          <label
            className={`tournament-ability-option${value === option.value ? " tournament-ability-option--selected" : ""}`}
            htmlFor={`${idPrefix}-${option.value}`}
            key={option.value}
          >
            <input
              checked={value === option.value}
              id={`${idPrefix}-${option.value}`}
              name={`${idPrefix}-ability`}
              required
              type="radio"
              value={option.value}
              onChange={(event) => onChange(event.target.value)}
            />
            <span className="tournament-ability-number">{option.value}</span>
            <span>
              <strong>{option.label}</strong>
              <small>{option.detail}{` Grade ${option.grade}.`}</small>
            </span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}

export default function TournamentDetailPage() {
  const { tournamentId } = useParams();
  const { session } = useAuth();
  const organizationId = session?.organization_id;
  const isAdmin = session?.role === "admin";
  const [tournament, setTournament] = useState(null);
  const [entryForm, setEntryForm] = useState(EMPTY_ENTRY);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [selectedPlayer, setSelectedPlayer] = useState(null);
  const [selectedAbility, setSelectedAbility] = useState("");
  const [manualEntryOpen, setManualEntryOpen] = useState(false);
  const [searching, setSearching] = useState(false);
  const [searchPerformed, setSearchPerformed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const searchRequestRef = useRef(0);

  const load = useCallback(async () => {
    if (!tournamentId || !organizationId) return;
    setLoading(true);
    setError("");
    try {
      const response = await getTournament(tournamentId, organizationId);
      setTournament(response?.tournament || null);
    } catch (requestError) {
      setError(requestError.message || "Unable to load the tournament.");
    } finally {
      setLoading(false);
    }
  }, [organizationId, tournamentId]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    const query = searchQuery.trim();
    const requestId = searchRequestRef.current + 1;
    searchRequestRef.current = requestId;
    setSelectedPlayer(null);

    if (query.length < 2 || !organizationId) {
      setSearchResults([]);
      setSearchPerformed(false);
      setSearching(false);
      return undefined;
    }

    setSearching(true);
    setSearchPerformed(false);
    const timeoutId = window.setTimeout(async () => {
      try {
        const response = await searchTournamentPlayers(organizationId, query);
        if (searchRequestRef.current !== requestId) return;
        setSearchResults(response?.players || []);
        setSearchPerformed(true);
        setError("");
      } catch (requestError) {
        if (searchRequestRef.current !== requestId) return;
        setSearchResults([]);
        setSearchPerformed(true);
        setError(requestError.message || "Unable to search for players.");
      } finally {
        if (searchRequestRef.current === requestId) setSearching(false);
      }
    }, 300);

    return () => window.clearTimeout(timeoutId);
  }, [organizationId, searchQuery]);

  async function handleAddEntry(event) {
    event.preventDefault();
    setSaving(true);
    setMessage("");
    setError("");
    try {
      const response = await createTournamentEntry(tournamentId, {
        ...entryForm,
        organization_id: organizationId,
      });
      const nextTournament = response?.tournament || null;
      setTournament(nextTournament);
      setEntryForm(EMPTY_ENTRY);
      setManualEntryOpen(false);
      setMessage(describeAddedPlayer(findAddedEntry(nextTournament, entryForm)));
    } catch (requestError) {
      setError(requestError.message || "Unable to add the player.");
    } finally {
      setSaving(false);
    }
  }

  async function handleAddSelected(event) {
    event.preventDefault();
    if (!selectedPlayer || !selectedAbility) return;
    setSaving(true);
    setMessage("");
    setError("");
    try {
      const response = await createTournamentEntry(tournamentId, {
        organization_id: organizationId,
        player_id: selectedPlayer.player_id,
        first_name: selectedPlayer.first_name,
        surname: selectedPlayer.surname,
        email: selectedPlayer.email,
        home_club_name: selectedPlayer.home_club_name,
        ability_level: selectedAbility,
      });
      const nextTournament = response?.tournament || null;
      setTournament(nextTournament);
      setSearchQuery("");
      setSearchResults([]);
      setSearchPerformed(false);
      setSelectedPlayer(null);
      setSelectedAbility("");
      setMessage(describeAddedPlayer(findAddedEntry(nextTournament, selectedPlayer)));
    } catch (requestError) {
      setError(requestError.message || "Unable to add the player.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader />

      {loading ? <div className="notice">Loading tournament...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {tournament ? (
        <>
          <section className="tournament-summary-grid">
            <article className="panel stack">
              <div className="dashboard-item-head">
                <div className="panel-heading">
                  <h2>{tournament.name}</h2>
                  <p className="helper-text">
                    {optionLabel(TOURNAMENT_SPORTS, tournament.sport)} · {optionLabel(TOURNAMENT_FORMATS, tournament.draw_format)}
                  </p>
                </div>
                <span className="status-pill">{tournament.status.replaceAll("_", " ")}</span>
              </div>
              <div className="dashboard-item-meta">
                <span>Venue: {tournament.venue_name || session?.organization_name || "Not set"}</span>
                <span>Start: {tournament.starts_on || "Not set"}</span>
                <span>End: {tournament.ends_on || "Not set"}</span>
                <span>{tournament.audience === "open" ? "Open tournament" : "Internal — club members only"}</span>
                <span>{tournament.graded_enabled ? "A–D grading enabled" : "Single ungraded draw"}</span>
                <span>{(tournament.draws || []).map((draw) => draw.name).join(" · ") || "Draw setup pending"}</span>
                <span>{tournament.draw_size_limit ? `Maximum ${tournament.draw_size_limit} entries` : "No draw size limit"}</span>
              </div>
            </article>
            <article className="panel stack tournament-next-stage">
              <div className="panel-heading">
                <h2>Draw & Scheduling</h2>
                <p className="helper-text">The event and identity foundation is active. Deterministic draw generation, fixtures and court scheduling are the next delivery stage.</p>
              </div>
              <button disabled type="button">Draw tools coming next</button>
            </article>
          </section>

          <section className="tournament-manager-grid">
            {isAdmin ? <section className="panel stack">
              <div className="panel-heading">
                <h2>Add Player</h2>
                <p className="helper-text">
                  Search the shared HitNScore player list first. If there is no match, add a new player manually.
                </p>
              </div>
              <div className="stack">
                <div className="field tournament-player-search">
                  <label htmlFor="tournament-player-search">Search Players</label>
                  <input
                    id="tournament-player-search"
                    placeholder="Type a name or email address"
                    value={searchQuery}
                    onChange={(event) => setSearchQuery(event.target.value)}
                  />
                  {searching ? <small className="tournament-search-status">Searching...</small> : null}
                </div>
              </div>

              {searchResults.length ? (
                <div className="tournament-search-results" aria-label="Player search results">
                  {searchResults.map((player) => {
                    const key = player.player_id || player.user_id || player.email;
                    const selected = (selectedPlayer?.player_id || selectedPlayer?.user_id) === (player.player_id || player.user_id);
                    return (
                      <button
                        className={`tournament-search-result${selected ? " tournament-search-result--selected" : ""}`}
                        key={key}
                        type="button"
                        onClick={() => setSelectedPlayer(player)}
                      >
                        <span><strong>{player.display_name || player.email}</strong><small>{player.email}</small></span>
                        <span><small>{player.home_club_name || "No home club"}</small><span className="status-pill">{player.relationship}</span></span>
                      </button>
                    );
                  })}
                </div>
              ) : searchPerformed && !searching ? <p className="helper-text">No matching player was found. You can add them manually below.</p> : null}

              {selectedPlayer ? (
                <form className="stack" onSubmit={handleAddSelected}>
                  <AbilitySelector idPrefix="selected-player" value={selectedAbility} onChange={setSelectedAbility} />
                  <div className="button-row">
                    <button disabled={saving || !selectedAbility} type="submit">{saving ? "Adding..." : `Add ${selectedPlayer.display_name}`}</button>
                  </div>
                </form>
              ) : null}

              <div className="tournament-manual-divider"><span>Player not found?</span></div>
              <div className="button-row tournament-add-player-row">
                <button type="button" onClick={() => setManualEntryOpen((current) => !current)}>
                  {manualEntryOpen ? "Close Manual Entry" : "Add Player Manually"}
                </button>
              </div>

              {manualEntryOpen ? <form className="stack" onSubmit={handleAddEntry}>
                <div className="field-grid">
                  <div className="field">
                    <label htmlFor="entry-first-name">First Name</label>
                    <input
                      id="entry-first-name"
                      required
                      value={entryForm.first_name}
                      onChange={(event) => setEntryForm((current) => ({ ...current, first_name: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="entry-surname">Surname</label>
                    <input
                      id="entry-surname"
                      value={entryForm.surname}
                      onChange={(event) => setEntryForm((current) => ({ ...current, surname: event.target.value }))}
                    />
                  </div>
                  <div className="field settings-field-wide">
                    <label htmlFor="entry-email">Email Address</label>
                    <input
                      id="entry-email"
                      type="email"
                      value={entryForm.email}
                      onChange={(event) => setEntryForm((current) => ({ ...current, email: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="entry-club">Home Club</label>
                    <input
                      id="entry-club"
                      value={entryForm.home_club_name}
                      onChange={(event) => setEntryForm((current) => ({ ...current, home_club_name: event.target.value }))}
                    />
                  </div>
                </div>
                <AbilitySelector
                  idPrefix="manual-player"
                  value={entryForm.ability_level}
                  onChange={(value) => setEntryForm((current) => ({ ...current, ability_level: value }))}
                />
                <div className="button-row">
                  <button disabled={saving} type="submit">{saving ? "Adding..." : "Add Tournament Player"}</button>
                </div>
              </form> : null}
            </section> : (
              <section className="panel stack">
                <div className="panel-heading">
                  <h2>Member View</h2>
                  <p className="helper-text">Entries are read-only. A club administrator manages players, draws and scheduling.</p>
                </div>
              </section>
            )}

            <section className="panel stack">
              <div className="panel-heading">
                <h2>Entries</h2>
                <p className="helper-text">{tournament.entries.length} registered player{tournament.entries.length === 1 ? "" : "s"}</p>
              </div>
              <div className="dashboard-list">
                {tournament.entries.length === 0 ? (
                  <div className="dashboard-empty">No players have been added yet.</div>
                ) : tournament.entries.map((entry) => (
                  <article className="dashboard-item" key={entry.id}>
                    <div className="dashboard-item-head">
                      <strong>{entry.display_name}</strong>
                      <div className="dashboard-status-group">
                        {entry.ability_level ? (
                          <span className="status-pill">
                            {tournament.graded_enabled ? `Grade ${entry.ability_grade}` : `Ability ${entry.ability_level}`}
                          </span>
                        ) : null}
                        <span className="status-pill">{entry.relationship}</span>
                      </div>
                    </div>
                    <div className="dashboard-item-meta">
                      <span>{entry.home_club_name || "No home club recorded"}</span>
                      <span>{entry.email || "Named player — no email yet"}</span>
                      <span>{entry.claim_status === "linked" ? "Linked HitNScore account" : entry.claim_status === "claimable" ? "Can be claimed after registration" : "Unclaimed named player"}</span>
                    </div>
                  </article>
                ))}
              </div>
            </section>
          </section>
        </>
      ) : null}

      <AppFooter />
    </main>
  );
}
