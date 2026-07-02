import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import {
  archiveRootAdminMatch,
  deleteRootAdminMatch,
  getRootAdminMatches,
} from "../services/api";

function formatDateTime(value) {
  if (!value) {
    return "Not set";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function matchScoreSummary(match) {
  const gamesSummary = `${match.player1_games_won ?? 0}-${match.player2_games_won ?? 0}`;
  if ((match.status || "") === "completed") {
    return `Completed • Games ${gamesSummary}`;
  }
  if ((match.status || "") === "scheduled") {
    return `Scheduled • Games ${gamesSummary}`;
  }
  return `Live • Game ${match.current_game_number ?? 1} • Games ${gamesSummary}`;
}

export default function RootAdminMatchesPage() {
  const navigate = useNavigate();
  const [sportFilter, setSportFilter] = useState("");
  const [organizationFilter, setOrganizationFilter] = useState("");
  const [matchDirectory, setMatchDirectory] = useState(null);
  const [loading, setLoading] = useState(true);
  const [savingKey, setSavingKey] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function loadMatches(nextFilters = {}) {
    setLoading(true);
    setError("");
    try {
      const response = await getRootAdminMatches({
        sport: nextFilters.sport ?? sportFilter,
        organizationId: nextFilters.organizationId ?? organizationFilter,
      });
      setMatchDirectory(response.rootAdminMatches || null);
    } catch (requestError) {
      setError(requestError.message || "Failed to load root-admin matches.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadMatches();
  }, [sportFilter, organizationFilter]);

  const matches = matchDirectory?.matches || [];
  const organizations = matchDirectory?.organizations || [];
  const sports = matchDirectory?.sports || [];
  const summary = matchDirectory?.summary || {};

  const organizationOptions = useMemo(
    () => [
      { id: "", organization_name: "All Organisations" },
      ...organizations,
    ],
    [organizations],
  );

  const sportOptions = useMemo(
    () => [
      { value: "", label: "All Sports" },
      ...sports,
    ],
    [sports],
  );

  async function handleArchive(match) {
    const confirmed = window.confirm(
      `Archive ${match.player1_display_name} vs ${match.player2_display_name}? Archived matches disappear from standard views.`,
    );
    if (!confirmed) {
      return;
    }

    const actionKey = `archive-${match.id}`;
    setSavingKey(actionKey);
    setMessage("");
    setError("");
    try {
      await archiveRootAdminMatch(match.id);
      await loadMatches();
      setMessage("Match archived.");
    } catch (requestError) {
      setError(requestError.message || "Failed to archive match.");
    } finally {
      setSavingKey("");
    }
  }

  async function handleDelete(match) {
    const confirmed = window.confirm(
      `Delete ${match.player1_display_name} vs ${match.player2_display_name}? This permanently removes the match and related event history.`,
    );
    if (!confirmed) {
      return;
    }

    const actionKey = `delete-${match.id}`;
    setSavingKey(actionKey);
    setMessage("");
    setError("");
    try {
      await deleteRootAdminMatch(match.id);
      await loadMatches();
      setMessage("Match deleted.");
    } catch (requestError) {
      setError(requestError.message || "Failed to delete match.");
    } finally {
      setSavingKey("");
    }
  }

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

      <section className="hero-card stack compact">
        <div className="root-admin-section-header">
          <div>
            <h1>System Match Scores</h1>
            <p className="helper-text">
              Review every non-archived match across the platform, then archive or permanently delete as needed.
            </p>
          </div>
          <div className="button-row root-admin-actions">
            <button type="button" className="secondary" onClick={() => navigate("/rckscoreAdmin/dashboard")}>
              Back to Platform Control Centre
            </button>
          </div>
        </div>
      </section>

      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      <section className="panel stack">
        <div className="root-admin-section-header">
          <h2>Match Directory</h2>
          <div className="root-admin-toolbar">
            <div className="field">
              <label htmlFor="root-admin-match-sport">Racket Sport</label>
              <select
                id="root-admin-match-sport"
                value={sportFilter}
                onChange={(event) => setSportFilter(event.target.value)}
              >
                {sportOptions.map((sport) => (
                  <option key={sport.value || "all"} value={sport.value}>
                    {sport.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="field">
              <label htmlFor="root-admin-match-organization">Organisation</label>
              <select
                id="root-admin-match-organization"
                value={organizationFilter}
                onChange={(event) => setOrganizationFilter(event.target.value)}
              >
                {organizationOptions.map((organization) => (
                  <option key={organization.id || "all"} value={organization.id}>
                    {organization.organization_name}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>

        <div className="meta-grid root-admin-interest-summary">
          <div className="meta-item">
            <strong>Matches In View</strong>
            <div>{summary.match_count ?? 0}</div>
          </div>
          <div className="meta-item">
            <strong>Active</strong>
            <div>{summary.active_count ?? 0}</div>
          </div>
          <div className="meta-item">
            <strong>Scheduled</strong>
            <div>{summary.scheduled_count ?? 0}</div>
          </div>
          <div className="meta-item">
            <strong>Completed</strong>
            <div>{summary.completed_count ?? 0}</div>
          </div>
        </div>

        {loading ? <div className="notice">Loading platform match directory...</div> : null}

        {!loading && matches.length === 0 ? (
          <div className="dashboard-empty">No matches match the current filters.</div>
        ) : null}

        <div className="root-admin-match-list">
          {matches.map((match) => {
            const archiveKey = `archive-${match.id}`;
            const deleteKey = `delete-${match.id}`;
            return (
              <article key={match.id} className="root-admin-match-row">
                <div className="root-admin-match-main">
                  <div className="root-admin-match-heading">
                    <span className="status-pill">{match.sport_label}</span>
                    <span className={`status-pill root-admin-interest-status root-admin-interest-status--${match.status}`}>
                      {match.status}
                    </span>
                  </div>
                  <h3>{match.player1_display_name} vs {match.player2_display_name}</h3>
                  <p>{match.organization_name} • {match.court_alias || match.court_name || "No court set"}</p>
                </div>

                <div className="root-admin-match-details">
                  <span>{matchScoreSummary(match)}</span>
                  <span>Score to {match.score_type} • Best of {match.best_of}</span>
                  <span>Winner: {match.winner_name || "Not decided"}</span>
                  <span>Created: {formatDateTime(match.created_at)}</span>
                  <span>Updated: {formatDateTime(match.updated_at)}</span>
                  <span>Completed: {formatDateTime(match.completed_at)}</span>
                </div>

                <div className="button-row root-admin-match-actions">
                  <button
                    type="button"
                    className="secondary"
                    disabled={savingKey === archiveKey || savingKey === deleteKey}
                    onClick={() => handleArchive(match)}
                  >
                    {savingKey === archiveKey ? "Archiving..." : "Archive"}
                  </button>
                  <button
                    type="button"
                    className="danger"
                    disabled={savingKey === archiveKey || savingKey === deleteKey}
                    onClick={() => handleDelete(match)}
                  >
                    {savingKey === deleteKey ? "Deleting..." : "Delete"}
                  </button>
                </div>
              </article>
            );
          })}
        </div>
      </section>

      <AppFooter />
    </main>
  );
}
