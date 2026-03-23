import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import { endMatch, getDashboard } from "../services/api";

function formatScore(match) {
  const player1Score = match?.state?.player1_score ?? 0;
  const player2Score = match?.state?.player2_score ?? 0;
  return {
    player1: player1Score,
    player2: player2Score,
    label: `${player1Score} - ${player2Score}`,
  };
}

function formatGameScore(match) {
  const player1Games = match?.state?.player1_games_won ?? match?.player1_games_won ?? 0;
  const player2Games = match?.state?.player2_games_won ?? match?.player2_games_won ?? 0;
  return {
    player1: player1Games,
    player2: player2Games,
    label: `${player1Games} - ${player2Games}`,
  };
}

function splitPlayerName(firstName, surname) {
  return {
    firstName: (firstName || "").trim() || "Player",
    surname: (surname || "").trim(),
  };
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

function formatRunningTime(value, minuteTick) {
  void minuteTick;
  if (!value) {
    return "0m";
  }

  const startedAt = new Date(value);
  if (Number.isNaN(startedAt.getTime())) {
    return "0m";
  }

  const totalMinutes = Math.max(0, Math.floor((Date.now() - startedAt.getTime()) / 60000));
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;

  if (hours === 0) {
    return `${minutes}m`;
  }

  return `${hours}h ${minutes}m`;
}

export default function DashboardPage() {
  const navigate = useNavigate();
  const { session } = useAuth();
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [actionError, setActionError] = useState("");
  const [minuteTick, setMinuteTick] = useState(Date.now());

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

  useEffect(() => {
    const intervalId = window.setInterval(() => {
      setMinuteTick(Date.now());
    }, 60000);

    return () => window.clearInterval(intervalId);
  }, []);

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
  const dashboardActions = [
    {
      label: "Start New Match",
      onClick: () => navigate("/match/new"),
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
                <article className="dashboard-item dashboard-item--card" key={match.id}>
                  <div
                    className="dashboard-card-status"
                    aria-label={match.status || "active"}
                    title={match.status || "active"}
                  >
                    <span className="dashboard-status-dot status-pill--active" aria-hidden="true" />
                  </div>
                  <div className="dashboard-card-showcase">
                    <div className="dashboard-card-player-card">
                      <div className="dashboard-card-player-row">
                        <div className="dashboard-card-player-name">
                          <strong>{splitPlayerName(match.player1_name, match.player1_surname).firstName}</strong>
                          <span>{splitPlayerName(match.player1_name, match.player1_surname).surname || "\u00A0"}</span>
                        </div>
                        <span className="dashboard-score-inline">{formatScore(match).player1}</span>
                      </div>
                      <span className="dashboard-card-games-inline">Games: {formatGameScore(match).player1}</span>
                    </div>
                    <span className="dashboard-card-versus">vs</span>
                    <div className="dashboard-card-player-card dashboard-card-player-card--right">
                      <div className="dashboard-card-player-row">
                        <div className="dashboard-card-player-name">
                          <strong>{splitPlayerName(match.player2_name, match.player2_surname).firstName}</strong>
                          <span>{splitPlayerName(match.player2_name, match.player2_surname).surname || "\u00A0"}</span>
                        </div>
                        <span className="dashboard-score-inline">{formatScore(match).player2}</span>
                      </div>
                      <span className="dashboard-card-games-inline">Games: {formatGameScore(match).player2}</span>
                    </div>
                  </div>
                  <div className="dashboard-item-meta dashboard-item-meta--stacked dashboard-card-meta-box">
                    <span>Court: {match.court_name || "Unassigned"}</span>
                    <span>Running: {formatRunningTime(match.created_at || match.updated_at, minuteTick)}</span>
                  </div>
                  <div className="button-row dashboard-item-actions dashboard-item-actions--compact">
                    <button type="button" onClick={() => navigate(`/match/${match.id}`)}>
                      Resume
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
                    <span>Result: {formatScore(match).label}</span>
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
