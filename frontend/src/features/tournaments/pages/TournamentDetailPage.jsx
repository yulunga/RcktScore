import React, { useCallback, useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import AppFooter from "../../../components/AppFooter";
import ClubPageHeader from "../../../components/ClubPageHeader";
import { useAuth } from "../../../hooks/useAuth";
import { createTournamentEntry, getTournament } from "../../../services/api";
import { optionLabel, TOURNAMENT_FORMATS, TOURNAMENT_SPORTS } from "../tournamentOptions";

const EMPTY_ENTRY = {
  first_name: "",
  surname: "",
  email: "",
  home_club_name: "",
  country: "",
  seed: "",
};

export default function TournamentDetailPage() {
  const navigate = useNavigate();
  const { tournamentId } = useParams();
  const { session } = useAuth();
  const organizationId = session?.organization_id;
  const [tournament, setTournament] = useState(null);
  const [entryForm, setEntryForm] = useState(EMPTY_ENTRY);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

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
      setTournament(response?.tournament || null);
      setEntryForm(EMPTY_ENTRY);
      setMessage("Player added. Registered emails are linked automatically; other players remain claimable guests.");
    } catch (requestError) {
      setError(requestError.message || "Unable to add the player.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        title={tournament?.name || "Tournament"}
        subtitle={tournament
          ? `${optionLabel(TOURNAMENT_SPORTS, tournament.sport)} · ${optionLabel(TOURNAMENT_FORMATS, tournament.draw_format)}`
          : "Tournament Manager"}
        actions={[{ label: "All Tournaments", onClick: () => navigate("/tournaments") }]}
      />

      {loading ? <div className="notice">Loading tournament...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {tournament ? (
        <>
          <section className="tournament-summary-grid">
            <article className="panel stack">
              <div className="dashboard-item-head">
                <h2>Event Summary</h2>
                <span className="status-pill">{tournament.status.replaceAll("_", " ")}</span>
              </div>
              <div className="dashboard-item-meta">
                <span>Venue: {tournament.venue_name || session?.organization_name || "Not set"}</span>
                <span>Start: {tournament.starts_on || "Not set"}</span>
                <span>End: {tournament.ends_on || "Not set"}</span>
                <span>Revision: {tournament.revision}</span>
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
            <section className="panel stack">
              <div className="panel-heading">
                <h2>Add Player</h2>
                <p className="helper-text">
                  Email is optional. If it belongs to an approved HitNScore account, this player is linked to that account. Otherwise the player can be claimed later.
                </p>
              </div>
              <form className="stack" onSubmit={handleAddEntry}>
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
                  <div className="field">
                    <label htmlFor="entry-country">Country</label>
                    <input
                      id="entry-country"
                      value={entryForm.country}
                      onChange={(event) => setEntryForm((current) => ({ ...current, country: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="entry-seed">Seed</label>
                    <input
                      id="entry-seed"
                      min="1"
                      type="number"
                      value={entryForm.seed}
                      onChange={(event) => setEntryForm((current) => ({ ...current, seed: event.target.value }))}
                    />
                  </div>
                </div>
                <div className="button-row">
                  <button disabled={saving} type="submit">{saving ? "Adding..." : "Add Tournament Player"}</button>
                </div>
              </form>
            </section>

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
                        {entry.seed ? <span className="status-pill">Seed {entry.seed}</span> : null}
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
