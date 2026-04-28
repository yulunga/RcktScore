import React, { useEffect, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import { endMatch, getDashboard, startScheduledMatch } from "../services/api";

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

function formatMatchHistoryResult(match) {
  const gameHistory = match?.state?.game_history || [];
  const overallGameScore = formatGameScore(match).label;
  const completedGameScores = gameHistory
    .map((game) => `${game.player1_score}-${game.player2_score}`)
    .join(" | ");
  const liveScore = formatScore(match).label;

  return {
    winnerName: match?.winner_name || match?.state?.winner_name || "Winner not set",
    scoreLine: `${overallGameScore} [${completedGameScores || liveScore}]`,
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

function inferOrganizationType(session) {
  if (session?.organization_type) {
    return session.organization_type;
  }

  return Number(session?.organization_id) >= 50000 ? "personal" : "club";
}

export default function DashboardPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { session } = useAuth();
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [actionError, setActionError] = useState("");
  const [minuteTick, setMinuteTick] = useState(Date.now());
  const [expandedScheduledMatches, setExpandedScheduledMatches] = useState({});

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

  useEffect(() => {
    if (!location.hash) {
      return;
    }

    const targetId = location.hash.replace("#", "");
    window.requestAnimationFrame(() => {
      document.getElementById(targetId)?.scrollIntoView({
        behavior: "smooth",
        block: "start",
      });
    });
  }, [location.hash]);

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

  async function handleStartScheduledMatch(matchId) {
    setActionError("");
    try {
      await startScheduledMatch({ match_id: matchId });
      navigate(`/match/${matchId}`);
    } catch (requestError) {
      setActionError(requestError.message || "Failed to start scheduled match.");
    }
  }

  function toggleScheduledDetails(matchId) {
    setExpandedScheduledMatches((current) => ({
      ...current,
      [matchId]: !current[matchId],
    }));
  }

  const activeMatches = dashboard?.active_matches || [];
  const scheduledMatches = dashboard?.scheduled_matches || [];
  const recentMatches = dashboard?.recent_matches || [];
  const organization = dashboard?.organization || {};
  const organizationType = organization.type || inferOrganizationType(session);
  const organizationPlan = organization.plan || session?.plan || (organizationType === "personal" ? "personal_free" : "club_essentials");
  const isPersonalAccount = organizationType === "personal";
  const historyLimit = organization.history_limit;
  const historyTitle = isPersonalAccount ? "Match History" : "Recent Matches";
  const historyHelper = isPersonalAccount
    ? `Showing the latest ${historyLimit || (organizationPlan === "personal_plus" ? 100 : 3)} completed matches for your plan.`
    : "Completed matches for this organisation.";
  const dashboardSubtitle = isPersonalAccount
    ? "Score matches, resume active games, and review your personal match history."
    : "Manage live scoring, keep an eye on active courts, and review recent matches.";
  const dashboardActions = [
    {
      label: "Start New Match",
      onClick: () => navigate("/match/new"),
    },
  ];

  if (!isPersonalAccount) {
    dashboardActions.push({
      label: "Match History",
      onClick: () => {
        document.getElementById("match-history-section")?.scrollIntoView({
          behavior: "smooth",
          block: "start",
        });
      },
    });
  }

  if (session?.role === "admin" || isPersonalAccount) {
    dashboardActions.push({
      label: "Settings",
      onClick: () => navigate("/settings"),
    });
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        actions={dashboardActions}
        subtitle={dashboardSubtitle}
        title={isPersonalAccount ? "" : organization.name || session?.organization_name || "Club Dashboard"}
      />

      <button
        className="dashboard-start-hero"
        type="button"
        onClick={() => navigate("/match/new")}
      >
        <span className="dashboard-start-hero__tile" aria-hidden="true">
          +
        </span>
        <span className="dashboard-start-hero__copy">
          <strong>Start New Match</strong>
        </span>
        <span className="dashboard-start-hero__chevron" aria-hidden="true">
          ›
        </span>
      </button>

      {loading ? <div className="notice">Loading dashboard...</div> : null}
      {actionError ? <div className="notice error">{actionError}</div> : null}

      <section className="dashboard-grid">
        <section className="panel stack" id="active-matches-section">
          <div className="panel-heading">
            <h2 className="dashboard-active-heading">
              <span className="dashboard-active-heading__icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <circle cx="12" cy="12" r="1.8" fill="currentColor" />
                  <path d="M7.75 16.25C5.40279 13.9028 5.40279 10.0972 7.75 7.75" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
                  <path d="M16.25 7.75C18.5972 10.0972 18.5972 13.9028 16.25 16.25" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
                  <path d="M4.75 19.25C0.75 15.25 0.75 8.75 4.75 4.75" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
                  <path d="M19.25 4.75C23.25 8.75 23.25 15.25 19.25 19.25" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
                </svg>
              </span>
              Active Matches
            </h2>
          </div>

          {activeMatches.length === 0 ? (
            <div className="dashboard-empty">No active matches right now.</div>
          ) : (
            <div className="dashboard-card-grid">
              {activeMatches.map((match) => (
                <article className="dashboard-item dashboard-active-card" key={match.id}>
                  <div className="dashboard-active-card__top">
                    <span className="dashboard-active-card__court">{match.court_name || "Unassigned Court"}</span>
                    <span className="dashboard-active-card__status">
                      <span className="dashboard-status-dot status-pill--active" aria-hidden="true" />
                      In Progress
                    </span>
                  </div>

                  <div className="dashboard-active-card__main">
                    <div className="dashboard-active-card__player">
                      <strong>{splitPlayerName(match.player1_name, match.player1_surname).firstName}</strong>
                      <span>{splitPlayerName(match.player1_name, match.player1_surname).surname || "Player 1"}</span>
                    </div>

                    <div className="dashboard-active-card__score">
                      <div className="dashboard-active-card__score-line">
                        <span className="dashboard-active-card__score-value dashboard-active-card__score-value--left">
                          {formatScore(match).player1}
                        </span>
                        <span className="dashboard-active-card__score-divider">-</span>
                        <span className="dashboard-active-card__score-value dashboard-active-card__score-value--right">
                          {formatScore(match).player2}
                        </span>
                      </div>
                      <span className="dashboard-active-card__best-of">
                        Best of {match.best_of || match?.state?.best_of || 5}
                      </span>
                    </div>

                    <div className="dashboard-active-card__player dashboard-active-card__player--right">
                      <strong>{splitPlayerName(match.player2_name, match.player2_surname).firstName}</strong>
                      <span>{splitPlayerName(match.player2_name, match.player2_surname).surname || "Player 2"}</span>
                    </div>

                    <button
                      className="dashboard-active-card__resume"
                      type="button"
                      aria-label={`Resume match on ${match.court_name || "court"}`}
                      onClick={() => navigate(`/match/${match.id}`)}
                    >
                      ›
                    </button>
                  </div>

                  <div className="dashboard-active-card__footer">
                    <div className="dashboard-active-card__meta">
                      <span>Games: {formatGameScore(match).label}</span>
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
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        {!isPersonalAccount ? (
          <section className="panel stack">
            <div className="panel-heading">
              <h2>Scheduled Matches</h2>
              <p className="helper-text">Matches created for later and ready to be started.</p>
            </div>

            {scheduledMatches.length === 0 ? (
              <div className="dashboard-empty">No scheduled matches right now.</div>
            ) : (
              <div className="dashboard-list">
                {scheduledMatches.map((match) => (
                  <article className="dashboard-item dashboard-item--history" key={match.id}>
                    <button
                      className="dashboard-history-action"
                      type="button"
                      onClick={() => handleStartScheduledMatch(match.id)}
                    >
                      Start
                    </button>
                    <div className="dashboard-history-content">
                      <div className="dashboard-item-head">
                        <strong>{formatPlayers(match)}</strong>
                        <button
                          aria-expanded={expandedScheduledMatches[match.id] ? "true" : "false"}
                          aria-label={expandedScheduledMatches[match.id] ? "Hide match details" : "Show match details"}
                          className="dashboard-match-menu-button"
                          type="button"
                          onClick={() => toggleScheduledDetails(match.id)}
                        >
                          <span aria-hidden="true">⋮</span>
                        </button>
                      </div>
                      <div className="dashboard-item-meta">
                        <span>Court: {match.court_name || "Unassigned"}</span>
                        <span>Ready to start</span>
                      </div>
                      {expandedScheduledMatches[match.id] ? (
                        <div className="dashboard-match-details">
                          <span>Scheduled: {formatDate(match.created_at)}</span>
                          <span>{match.best_of ? `Match Format: Best of ${match.best_of}` : "Match Format: Not set"}</span>
                          <span>{match.score_type ? `Game Format: ${match.score_type}` : "Game Format: Not set"}</span>
                          <span>{match.handicap_match ? "Handicap Match: Yes" : "Handicap Match: No"}</span>
                          <span>{match.referee_name ? `Referee: ${match.referee_name}` : "Referee: Not set"}</span>
                        </div>
                      ) : null}
                    </div>
                  </article>
                ))}
              </div>
            )}
          </section>
        ) : null}

        <section className="panel stack" id="match-history-section">
          <div className="panel-heading">
            <h2>{historyTitle}</h2>
            <p className="helper-text">{historyHelper}</p>
          </div>

          {recentMatches.length === 0 ? (
            <div className="dashboard-empty">Completed matches will appear here once they are ended.</div>
          ) : (
            <div className="dashboard-list">
              {recentMatches.map((match) => (
                <article className="dashboard-item dashboard-item--history" key={match.id}>
                  <button
                    className="dashboard-history-action"
                    type="button"
                    onClick={() => navigate(`/match/${match.id}`)}
                  >
                    View
                  </button>
                  <div className="dashboard-history-content">
                    <div className="dashboard-item-head">
                      <strong>{formatPlayers(match)}</strong>
                      <span>{formatDate(match.updated_at)}</span>
                    </div>
                    <div className="dashboard-item-meta">
                      <span>Winner: {formatMatchHistoryResult(match).winnerName}</span>
                      <span>Result: {formatMatchHistoryResult(match).scoreLine}</span>
                      {!isPersonalAccount ? (
                        <span>Court: {match.court_name || "Unassigned"}</span>
                      ) : null}
                    </div>
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
