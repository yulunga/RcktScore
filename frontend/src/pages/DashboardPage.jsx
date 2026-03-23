import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import { endMatch, getDashboard } from "../services/api";

function formatScore(match) {
  const player1Score = match?.state?.player1_score ?? 0;
  const player2Score = match?.state?.player2_score ?? 0;
  return `${player1Score} - ${player2Score}`;
}

function formatPlayers(match) {
  return `${match.player1_name} ${match.player1_surname || ""}`.trim()
    + " vs "
    + `${match.player2_name} ${match.player2_surname || ""}`.trim();
}

function formatDate(value) {
  if (!value) {
    return "Unknown date";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default function DashboardPage() {
  const navigate = useNavigate();
  const { session } = useAuth();
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [actionError, setActionError] = useState("");

  useEffect(() => {
    async function loadDashboard() {
      if (!session?.organization_id) {
        setLoading(false);
        return;
      }

      setLoading(true);
      setActionError("");
      try {
        const response = await getDashboard(session.organization_id);
        setDashboard(response.dashboard || null);
      } catch (requestError) {
        setActionError(requestError.message || "Failed to load dashboard.");
      } finally {
        setLoading(false);
      }
    }

    loadDashboard();
  }, [session?.organization_id]);

  async function handleEndMatch(matchId) {
    setActionError("");
    try {
      await endMatch({ match_id: matchId });
      const response = await getDashboard(session.organization_id);
      setDashboard(response.dashboard || null);
    } catch (requestError) {
      setActionError(requestError.message || "Failed to end match.");
    }
  }

  const activeMatches = dashboard?.active_matches || [];
  const recentMatches = dashboard?.recent_matches || [];
  const organization = dashboard?.organization || {};
  const primaryDisplayMatch = activeMatches[0];
  const dashboardActions = [
    {
      label: "Start New Match",
      onClick: () => navigate("/match/new"),
    },
    {
      label: "Open Display Screen",
      onClick: () => {
        const displayUrl = primaryDisplayMatch
          ? `${window.location.origin}/display?match=${primaryDisplayMatch.id}`
          : `${window.location.origin}/display`;
        window.open(displayUrl, "_blank", "noopener,noreferrer");
      },
    },
    {
      label: "Match History",
      onClick: () => {
        document.getElementById("match-history-section")?.scrollIntoView({
          behavior: "smooth",
          block: "start",
        });
      },
    },
    {
      label: "Settings",
      onClick: () => navigate("/settings"),
    },
  ];

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        actions={dashboardActions}
        subtitle="Manage live scoring, keep an eye on active courts, and review recent matches."
        title={organization.name || session?.organization_name || "Club Dashboard"}
      />

      {loading ? <div className="notice">Loading dashboard...</div> : null}
      {actionError ? <div className="notice error">{actionError}</div> : null}

      <section className="dashboard-grid">
        <section className="panel stack">
          <div className="panel-heading">
            <h2>Active Matches</h2>
            <p className="helper-text">Matches currently in progress for this organisation.</p>
          </div>

          {activeMatches.length === 0 ? (
            <div className="dashboard-empty">No active matches right now.</div>
          ) : (
            <div className="dashboard-card-grid">
              {activeMatches.map((match) => (
                <article className="dashboard-item" key={match.id}>
                  <div className="dashboard-item-head">
                    <strong>{formatPlayers(match)}</strong>
                    <span className="status-pill">{match.status || "active"}</span>
                  </div>
                  <div className="dashboard-item-meta">
                    <span>Score: {formatScore(match)}</span>
                    <span>Court: {match.court_name || "Unassigned"}</span>
                    <span>Updated: {formatDate(match.updated_at)}</span>
                  </div>
                  <div className="button-row">
                    <button type="button" onClick={() => navigate(`/match/${match.id}`)}>
                      Resume
                    </button>
                    <button
                      className="secondary"
                      type="button"
                      onClick={() =>
                        window.open(
                          `${window.location.origin}/display?match=${match.id}`,
                          "_blank",
                          "noopener,noreferrer",
                        )}
                    >
                      Display
                    </button>
                    <button
                      className="danger"
                      type="button"
                      onClick={() => handleEndMatch(match.id)}
                    >
                      End Match
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        <section className="panel stack" id="match-history-section">
          <div className="panel-heading">
            <h2>Recent Matches</h2>
            <p className="helper-text">Completed matches for this organisation.</p>
          </div>

          {recentMatches.length === 0 ? (
            <div className="dashboard-empty">Completed matches will appear here once they are ended.</div>
          ) : (
            <div className="dashboard-list">
              {recentMatches.map((match) => (
                <article className="dashboard-item" key={match.id}>
                  <div className="dashboard-item-head">
                    <strong>{formatPlayers(match)}</strong>
                    <span>{formatDate(match.updated_at)}</span>
                  </div>
                  <div className="dashboard-item-meta">
                    <span>Result: {formatScore(match)}</span>
                    <span>Court: {match.court_name || "Unassigned"}</span>
                  </div>
                  <div className="button-row">
                    <button type="button" onClick={() => navigate(`/match/${match.id}`)}>
                      View
                    </button>
                    <button className="secondary" disabled type="button">
                      Stats
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

      </section>

      <AppFooter />
    </main>
  );
}
