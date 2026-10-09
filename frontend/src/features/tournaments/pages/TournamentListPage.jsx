import React, { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../../../components/AppFooter";
import ClubPageHeader from "../../../components/ClubPageHeader";
import { useAuth } from "../../../hooks/useAuth";
import { createTournament, getOrganizationSettings, getTournaments } from "../../../services/api";
import { optionLabel, TOURNAMENT_FORMATS, TOURNAMENT_SPORTS } from "../tournamentOptions";

const EMPTY_FORM = {
  name: "",
  sport: "squash",
  draw_format: "knockout",
  audience: "internal",
  graded_enabled: false,
  limit_draw_size: false,
  draw_size_limit: "",
  venue_name: "",
  starts_on: "",
  ends_on: "",
};

function formatDate(value) {
  if (!value) return "Date not set";
  return new Intl.DateTimeFormat("en-GB", { dateStyle: "medium" }).format(new Date(`${value}T12:00:00`));
}

function statusLabel(status) {
  if (status === "draw_published") return "Live";
  return (status || "draft").replaceAll("_", " ");
}

export default function TournamentListPage() {
  const navigate = useNavigate();
  const { session } = useAuth();
  const organizationId = session?.organization_id;
  const isAdmin = session?.role === "admin";
  const [tournaments, setTournaments] = useState([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [featureChecked, setFeatureChecked] = useState(false);
  const [featureEnabled, setFeatureEnabled] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!organizationId) return;
    setLoading(true);
    setError("");
    try {
      const settingsResponse = await getOrganizationSettings(organizationId);
      const organization = settingsResponse?.organizationSettings?.organization;
      const enabled = organization?.org_type === "club"
        && Boolean(organization?.features?.tournament_manager?.web_enabled);
      setFeatureEnabled(enabled);
      setFeatureChecked(true);
      if (!enabled) {
        setTournaments([]);
        return;
      }
      const response = await getTournaments(organizationId);
      setTournaments(response?.tournaments || []);
    } catch (requestError) {
      setError(requestError.message || "Unable to load Tournament Manager.");
    } finally {
      setLoading(false);
    }
  }, [organizationId]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleCreate(event) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      const response = await createTournament(organizationId, form);
      const tournament = response?.tournament;
      setForm(EMPTY_FORM);
      if (tournament?.id) {
        navigate(`/tournaments/${tournament.id}`);
      } else {
        await load();
      }
    } catch (requestError) {
      setError(requestError.message || "Unable to create the tournament.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader />

      {loading ? <div className="notice">Loading tournaments...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {featureChecked && !featureEnabled ? (
        <section className="panel stack">
          <div className="panel-heading">
            <h2>Tournament Manager is not enabled</h2>
            <p className="helper-text">A HitNScore root administrator must enable this feature for the current club.</p>
          </div>
          <div className="button-row">
            <button type="button" onClick={() => navigate("/settings")}>Return to Settings</button>
          </div>
        </section>
      ) : null}

      {featureEnabled ? (
        <section className="tournament-manager-grid">
          {isAdmin ? <section className="panel stack">
            <div className="panel-heading">
              <h2>New Tournament</h2>
              <p className="helper-text">This creates a draft. Draw generation and scheduling remain separate steps.</p>
            </div>
            <form className="stack" onSubmit={handleCreate}>
              <div className="field-grid">
                <div className="field settings-field-wide">
                  <label htmlFor="tournament-name">Tournament Name</label>
                  <input
                    id="tournament-name"
                    required
                    value={form.name}
                    onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
                  />
                </div>
                <div className="field">
                  <label htmlFor="tournament-sport">Sport</label>
                  <select
                    id="tournament-sport"
                    value={form.sport}
                    onChange={(event) => setForm((current) => ({ ...current, sport: event.target.value }))}
                  >
                    {TOURNAMENT_SPORTS.map((sport) => <option key={sport.value} value={sport.value}>{sport.label}</option>)}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="tournament-format">Draw Format</label>
                  <select
                    id="tournament-format"
                    value={form.draw_format}
                    onChange={(event) => setForm((current) => ({ ...current, draw_format: event.target.value }))}
                  >
                    {TOURNAMENT_FORMATS.map((format) => <option key={format.value} value={format.value}>{format.label}</option>)}
                  </select>
                </div>
                <div className="field settings-field-wide">
                  <label htmlFor="tournament-audience">Tournament Access</label>
                  <select
                    id="tournament-audience"
                    value={form.audience}
                    onChange={(event) => setForm((current) => ({ ...current, audience: event.target.value }))}
                  >
                    <option value="internal">Internal — club members only</option>
                    <option value="open">Open — club and external players</option>
                  </select>
                </div>
                <div className="field settings-field-wide">
                  <label htmlFor="tournament-venue">Venue</label>
                  <input
                    id="tournament-venue"
                    placeholder={session?.organization_name || "Club venue"}
                    value={form.venue_name}
                    onChange={(event) => setForm((current) => ({ ...current, venue_name: event.target.value }))}
                  />
                </div>
                <div className="field">
                  <label htmlFor="tournament-start">Start Date</label>
                  <input
                    id="tournament-start"
                    type="date"
                    value={form.starts_on}
                    onChange={(event) => setForm((current) => ({ ...current, starts_on: event.target.value }))}
                  />
                </div>
                <div className="field">
                  <label htmlFor="tournament-end">End Date</label>
                  <input
                    id="tournament-end"
                    type="date"
                    value={form.ends_on}
                    onChange={(event) => setForm((current) => ({ ...current, ends_on: event.target.value }))}
                  />
                </div>
              </div>
              <div className="tournament-option-list">
                <label className="match-option-switch" htmlFor="tournament-graded">
                  <span className="match-option-switch__copy">
                    <strong>Graded tournament</strong>
                    <small>Assess each player and prepare separate A, B, C and D draw groups.</small>
                  </span>
                  <span className="match-option-switch__control">
                    <input
                      id="tournament-graded"
                      type="checkbox"
                      checked={form.graded_enabled}
                      onChange={(event) => setForm((current) => ({ ...current, graded_enabled: event.target.checked }))}
                    />
                    <span className="match-option-switch__track" aria-hidden="true"><span /></span>
                  </span>
                </label>
                <label className="match-option-switch" htmlFor="tournament-limit-draw">
                  <span className="match-option-switch__copy">
                    <strong>Limit draw size</strong>
                    <small>Stop new entries when this tournament reaches the selected capacity.</small>
                  </span>
                  <span className="match-option-switch__control">
                    <input
                      id="tournament-limit-draw"
                      type="checkbox"
                      checked={form.limit_draw_size}
                      onChange={(event) => setForm((current) => ({
                        ...current,
                        limit_draw_size: event.target.checked,
                        draw_size_limit: event.target.checked ? current.draw_size_limit : "",
                      }))}
                    />
                    <span className="match-option-switch__track" aria-hidden="true"><span /></span>
                  </span>
                </label>
                {form.limit_draw_size ? (
                  <div className="field tournament-draw-limit-field">
                    <label htmlFor="tournament-draw-limit">Maximum Entries</label>
                    <input
                      id="tournament-draw-limit"
                      min="2"
                      required
                      type="number"
                      value={form.draw_size_limit}
                      onChange={(event) => setForm((current) => ({ ...current, draw_size_limit: event.target.value }))}
                    />
                  </div>
                ) : null}
              </div>
              <div className="button-row">
                <button disabled={saving} type="submit">{saving ? "Creating..." : "Create Draft Tournament"}</button>
              </div>
            </form>
          </section> : (
            <section className="panel stack">
              <div className="panel-heading">
                <h2>Club Tournaments</h2>
                <p className="helper-text">You have member access to view this club&apos;s tournaments. Club administrators manage events and entries.</p>
              </div>
            </section>
          )}

          <section className="panel stack">
            <div className="panel-heading">
              <h2>Your Tournaments</h2>
              <p className="helper-text">Open a tournament to manage players or view its draw.</p>
            </div>
            <div className="dashboard-list">
              {!loading && tournaments.length === 0 ? (
                <div className="dashboard-empty">No tournaments have been created for this club.</div>
              ) : tournaments.map((tournament) => (
                <button
                  className="dashboard-item tournament-list-item"
                  key={tournament.id}
                  type="button"
                  onClick={() => navigate(`/tournaments/${tournament.id}`)}
                >
                  <div className="dashboard-item-head">
                    <strong>{tournament.name}</strong>
                    <span className="status-pill">{statusLabel(tournament.status)}</span>
                  </div>
                  <div className="dashboard-item-meta">
                    <span>{optionLabel(TOURNAMENT_SPORTS, tournament.sport)} · {optionLabel(TOURNAMENT_FORMATS, tournament.draw_format)}</span>
                    <span>{formatDate(tournament.starts_on)} · {tournament.entry_count} entr{tournament.entry_count === 1 ? "y" : "ies"}</span>
                  </div>
                  <span className="tournament-list-action">
                    {tournament.status === "draw_published" ? "View Draw" : "Open Tournament"}
                  </span>
                </button>
              ))}
            </div>
          </section>
        </section>
      ) : null}

      <AppFooter />
    </main>
  );
}
