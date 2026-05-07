import React, { useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import { endMatch, getDashboard, startScheduledMatch } from "../services/api";

const DASHBOARD_CAROUSEL_PAGE_SIZE = 3;
const SCHEDULED_DETAILS_AUTO_COLLAPSE_MS = 5 * 60 * 1000;

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

function chunkItems(items, pageSize = DASHBOARD_CAROUSEL_PAGE_SIZE) {
  const pages = [];
  for (let index = 0; index < items.length; index += pageSize) {
    pages.push(items.slice(index, index + pageSize));
  }
  return pages;
}

function clampPageIndex(index, totalPages) {
  if (totalPages <= 0) {
    return 0;
  }

  return Math.min(index, totalPages - 1);
}

export default function DashboardPage({ screenMode = "dashboard" }) {
  const navigate = useNavigate();
  const location = useLocation();
  const { session } = useAuth();
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [actionError, setActionError] = useState("");
  const [minuteTick, setMinuteTick] = useState(Date.now());
  const [expandedScheduledMatches, setExpandedScheduledMatches] = useState({});
  const [historyPage, setHistoryPage] = useState(0);
  const [activePage, setActivePage] = useState(0);
  const [scheduledPage, setScheduledPage] = useState(0);
  const [showAllHistory, setShowAllHistory] = useState(false);
  const [historySearch, setHistorySearch] = useState("");
  const scheduledDetailsTimeoutsRef = useRef({});

  useEffect(() => {
    async function loadDashboard() {
      if (!session?.organization_id) {
        setLoading(false);
        return;
      }

      setLoading(true);
      setActionError("");
      try {
        const response = await getDashboard(session.organization_id, {
          activeLimit: screenMode === "history" ? 0 : 200,
          recentLimit: screenMode === "history" ? 200 : (screenMode === "matches" ? 1 : 12),
        });
        setDashboard(response.dashboard || null);
      } catch (requestError) {
        setActionError(requestError.message || "Failed to load dashboard.");
      } finally {
        setLoading(false);
      }
    }

    loadDashboard();
  }, [screenMode, session?.organization_id]);

  useEffect(() => {
    const intervalId = window.setInterval(() => {
      setMinuteTick(Date.now());
    }, 60000);

    return () => window.clearInterval(intervalId);
  }, []);

  useEffect(() => () => {
    Object.values(scheduledDetailsTimeoutsRef.current).forEach((timeoutId) => {
      window.clearTimeout(timeoutId);
    });
    scheduledDetailsTimeoutsRef.current = {};
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
    setExpandedScheduledMatches((current) => {
      const isOpening = !current[matchId];
      const existingTimeout = scheduledDetailsTimeoutsRef.current[matchId];
      if (existingTimeout) {
        window.clearTimeout(existingTimeout);
        delete scheduledDetailsTimeoutsRef.current[matchId];
      }

      if (isOpening) {
        scheduledDetailsTimeoutsRef.current[matchId] = window.setTimeout(() => {
          setExpandedScheduledMatches((latest) => ({
            ...latest,
            [matchId]: false,
          }));
          delete scheduledDetailsTimeoutsRef.current[matchId];
        }, SCHEDULED_DETAILS_AUTO_COLLAPSE_MS);
      }

      return {
        ...current,
        [matchId]: isOpening,
      };
    });
  }

  const activeMatches = dashboard?.active_matches || [];
  const scheduledMatches = dashboard?.scheduled_matches || [];
  const recentMatches = dashboard?.recent_matches || [];
  const organization = dashboard?.organization || {};
  const organizationType = organization.type || inferOrganizationType(session);
  const organizationPlan = organization.plan || session?.plan || (organizationType === "personal" ? "personal_free" : "club_essentials");
  const isPersonalAccount = organizationType === "personal";
  const historyLimit = organization.history_limit;
  const historyTitle = screenMode === "history"
    ? "Recent Matches"
    : (isPersonalAccount ? "Match History" : "Recent Matches");
  const dashboardSubtitle = screenMode === "matches"
    ? "View live and scheduled matches for your organisation in one scrolling list."
    : screenMode === "history"
      ? "Search completed matches by player name, surname, or date."
      : isPersonalAccount
        ? "Score matches, resume active games, and review your personal match history."
        : "Manage live scoring, keep an eye on active courts, and review recent matches.";
  const dashboardActions = screenMode === "dashboard"
    ? [
      {
        label: "Start New Match",
        onClick: () => navigate("/match/new"),
      },
    ]
    : [];

  if (screenMode === "dashboard" && !isPersonalAccount) {
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

  if (screenMode === "dashboard" && (session?.role === "admin" || isPersonalAccount)) {
    dashboardActions.push({
      label: "Settings",
      onClick: () => navigate("/settings"),
    });
  }

  const historyPreviewLimit = organizationPlan === "personal_free" ? 3 : Math.min(historyLimit || 12, 12);
  const historyMatches = recentMatches.slice(0, historyPreviewLimit);
  const normalizedHistorySearch = historySearch.trim().toLowerCase();
  const historyCollection = screenMode === "history" ? recentMatches : historyMatches;
  const filteredHistoryMatches = useMemo(() => {
    if (!normalizedHistorySearch) {
      return historyCollection;
    }

    return historyCollection.filter((match) => {
      const player1 = `${match.player1_name || ""} ${match.player1_surname || ""}`.trim().toLowerCase();
      const player2 = `${match.player2_name || ""} ${match.player2_surname || ""}`.trim().toLowerCase();
      const dateText = formatDate(match.updated_at).toLowerCase();
      const winner = (match?.winner_name || match?.state?.winner_name || "").toLowerCase();
      return [player1, player2, dateText, winner].some((value) => value.includes(normalizedHistorySearch));
    });
  }, [historyCollection, normalizedHistorySearch]);
  const historyPages = chunkItems(filteredHistoryMatches);
  const visibleHistoryPage = historyPages[clampPageIndex(historyPage, historyPages.length)] || [];
  const hasHistoryCarousel = historyPages.length > 1;
  const showHistoryViewAll = screenMode !== "history" && filteredHistoryMatches.length > DASHBOARD_CAROUSEL_PAGE_SIZE;

  const activePages = chunkItems(activeMatches);
  const visibleActivePage = activePages[clampPageIndex(activePage, activePages.length)] || [];
  const hasActiveCarousel = screenMode === "dashboard" && !isPersonalAccount && activePages.length > 1;

  const scheduledPages = chunkItems(scheduledMatches);
  const visibleScheduledPage = scheduledPages[clampPageIndex(scheduledPage, scheduledPages.length)] || [];
  const hasScheduledCarousel = screenMode === "dashboard" && !isPersonalAccount && scheduledPages.length > 1;

  const showMatchesOnly = screenMode === "matches";
  const showHistoryOnly = screenMode === "history";

  useEffect(() => {
    setHistoryPage((current) => clampPageIndex(current, historyPages.length));
  }, [historyPages.length]);

  useEffect(() => {
    setActivePage((current) => clampPageIndex(current, activePages.length));
  }, [activePages.length]);

  useEffect(() => {
    setScheduledPage((current) => clampPageIndex(current, scheduledPages.length));
  }, [scheduledPages.length]);

  useEffect(() => {
    if (!showHistoryViewAll) {
      setShowAllHistory(false);
    }
  }, [showHistoryViewAll]);

  function renderPagerDots(totalPages, currentPage, onSelectPage, label) {
    if (totalPages <= 1) {
      return null;
    }

    return (
      <div className="dashboard-carousel-dots" aria-label={label} role="tablist">
        {Array.from({ length: totalPages }, (_, index) => (
          <button
            key={`${label}-${index}`}
            aria-label={`Show page ${index + 1}`}
            aria-selected={currentPage === index ? "true" : "false"}
            className={`dashboard-carousel-dots__dot${currentPage === index ? " dashboard-carousel-dots__dot--active" : ""}`}
            role="tab"
            type="button"
            onClick={() => onSelectPage(index)}
          />
        ))}
      </div>
    );
  }

  function renderActiveMatchCard(match) {
    return (
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
    );
  }

  function renderScheduledMatchCard(match) {
    return (
      <article className="dashboard-item dashboard-scheduled-card" key={match.id}>
        <div className="dashboard-scheduled-card__top">
          <span className="dashboard-scheduled-card__top-spacer" aria-hidden="true" />
          <span className="dashboard-scheduled-card__status">Ready to start</span>
        </div>

        <div className="dashboard-scheduled-card__main">
          <div className="dashboard-scheduled-card__player">
            <strong>{splitPlayerName(match.player1_name, match.player1_surname).firstName}</strong>
            <span>{splitPlayerName(match.player1_name, match.player1_surname).surname || "Player 1"}</span>
          </div>

          <div className="dashboard-scheduled-card__center">
            <span className="dashboard-scheduled-card__court-detail">
              {match.court_alias || match.court_name || "Unassigned Court"}
            </span>
          </div>

          <div className="dashboard-scheduled-card__player dashboard-scheduled-card__player--right">
            <strong>{splitPlayerName(match.player2_name, match.player2_surname).firstName}</strong>
            <span>{splitPlayerName(match.player2_name, match.player2_surname).surname || "Player 2"}</span>
          </div>

          <button
            className="dashboard-scheduled-card__start"
            type="button"
            onClick={() => handleStartScheduledMatch(match.id)}
          >
            Start
          </button>
        </div>

        <div className="dashboard-scheduled-card__footer">
          <button
            aria-expanded={expandedScheduledMatches[match.id] ? "true" : "false"}
            aria-label={expandedScheduledMatches[match.id] ? "Hide match details" : "Show match details"}
            className="dashboard-scheduled-card__details-toggle"
            type="button"
            onClick={() => toggleScheduledDetails(match.id)}
          >
            {expandedScheduledMatches[match.id] ? "Hide details" : "More details"}
          </button>
          {expandedScheduledMatches[match.id] ? (
            <div className="dashboard-match-details dashboard-match-details--scheduled">
              <span>{match.best_of ? `Match Format: Best of ${match.best_of}` : "Match Format: Not set"}</span>
              <span>{`Scheduled: ${formatDate(match.created_at)}`}</span>
              <span>{match.score_type ? `Game Format: ${match.score_type}` : "Game Format: Not set"}</span>
              <span>{match.handicap_match ? "Handicap Match: Yes" : "Handicap Match: No"}</span>
              <span>{match.referee_name ? `Referee: ${match.referee_name}` : "Referee: Not set"}</span>
              <div className="dashboard-scheduled-card__detail-actions">
                <button
                  className="dashboard-scheduled-card__edit"
                  type="button"
                  onClick={() => navigate(`/match/${match.id}?settings=1`)}
                >
                  Edit Game
                </button>
              </div>
            </div>
          ) : null}
        </div>
      </article>
    );
  }

  function renderHistoryMatchCard(match) {
    return (
      <article className="dashboard-item dashboard-history-card" key={match.id}>
        <div className="dashboard-history-card__top">
          <strong className="dashboard-history-card__title">{formatPlayers(match)}</strong>
          <span className="dashboard-history-card__date">{formatDate(match.updated_at)}</span>
        </div>
        <div className="dashboard-history-card__meta">
          <span className="dashboard-history-card__winner">{formatMatchHistoryResult(match).winnerName}</span>
          <span className="dashboard-history-card__result">{formatMatchHistoryResult(match).scoreLine}</span>
          {!isPersonalAccount ? (
            <span className="dashboard-history-card__court">{match.court_name || "Unassigned"}</span>
          ) : null}
        </div>
        <button
          className="dashboard-history-card__view"
          type="button"
          onClick={() => navigate(`/match/${match.id}`)}
          aria-label={`View completed match ${formatPlayers(match)}`}
        >
          ›
        </button>
      </article>
    );
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        actions={dashboardActions}
        subtitle={dashboardSubtitle}
        title={
          showMatchesOnly
            ? "Matches"
            : showHistoryOnly
              ? "History"
              : (isPersonalAccount ? "" : organization.name || session?.organization_name || "Club Dashboard")
        }
      />

      {screenMode === "dashboard" ? (
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
      ) : null}

      {loading ? <div className="notice">Loading dashboard...</div> : null}
      {actionError ? <div className="notice error">{actionError}</div> : null}

      <section className="dashboard-grid">
        {!showHistoryOnly ? (
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
            <>
              <div className="dashboard-card-grid dashboard-card-grid--desktop">
                {activeMatches.map((match) => renderActiveMatchCard(match))}
              </div>
              {hasActiveCarousel ? (
                <div className="dashboard-carousel dashboard-carousel--mobile">
                  <div className="dashboard-carousel__page">
                    <div className="dashboard-card-grid dashboard-card-grid--mobile">
                      {visibleActivePage.map((match) => renderActiveMatchCard(match))}
                    </div>
                  </div>
                  {renderPagerDots(activePages.length, activePage, setActivePage, "Active match pages")}
                </div>
              ) : showMatchesOnly ? (
                <div className="dashboard-card-grid dashboard-carousel--mobile dashboard-card-grid--mobile">
                  {activeMatches.map((match) => renderActiveMatchCard(match))}
                </div>
              ) : null}
            </>
          )}
        </section>
        ) : null}

        {!isPersonalAccount && !showHistoryOnly ? (
          <section className="panel stack">
            <div className="panel-heading">
              <h2 className="dashboard-scheduled-heading">
                <span className="dashboard-scheduled-heading__icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <rect x="5.75" y="6.75" width="12.5" height="11.5" rx="2.25" stroke="currentColor" strokeWidth="1.9" />
                    <path d="M8.5 4.75V8" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
                    <path d="M15.5 4.75V8" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
                    <path d="M8.75 11.25H15.25" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
                    <path d="M12 11.25V15.25" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
                  </svg>
                </span>
                Scheduled Matches
              </h2>
            </div>

            {scheduledMatches.length === 0 ? (
              <div className="dashboard-empty">No scheduled matches right now.</div>
            ) : (
              <>
                <div className="dashboard-list dashboard-list--desktop">
                  {scheduledMatches.map((match) => renderScheduledMatchCard(match))}
                </div>
                {hasScheduledCarousel ? (
                <div className="dashboard-carousel dashboard-carousel--mobile">
                  <div className="dashboard-carousel__page">
                    <div className="dashboard-list">
                      {visibleScheduledPage.map((match) => renderScheduledMatchCard(match))}
                    </div>
                  </div>
                  {renderPagerDots(scheduledPages.length, scheduledPage, setScheduledPage, "Scheduled match pages")}
                </div>
                ) : (
                  <div className="dashboard-list dashboard-carousel--mobile">
                    {scheduledMatches.map((match) => renderScheduledMatchCard(match))}
                  </div>
                )}
              </>
            )}
          </section>
        ) : null}

        {!showMatchesOnly ? (
        <section className="panel stack" id="match-history-section">
          <div className="panel-heading panel-heading--with-action">
            <h2 className="dashboard-history-heading">
              <span className="dashboard-history-heading__icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M5.75 12C5.75 8.54822 8.54822 5.75 12 5.75C15.4518 5.75 18.25 8.54822 18.25 12C18.25 15.4518 15.4518 18.25 12 18.25C9.58996 18.25 7.49872 16.887 6.45091 14.8889" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />
                  <path d="M5.75 8.25V5.75H8.25" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />
                  <path d="M12 8.5V12.25L14.5 13.75" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </span>
              {historyTitle}
            </h2>
            {showHistoryViewAll ? (
              <button
                className="dashboard-section-link"
                type="button"
                onClick={() => setShowAllHistory((current) => !current)}
              >
                {showAllHistory ? "Show less" : "View all"}
              </button>
            ) : null}
          </div>

          {showHistoryOnly ? (
            <div className="dashboard-history-search">
              <input
                type="search"
                placeholder="Search player name, surname, or date"
                value={historySearch}
                onChange={(event) => setHistorySearch(event.target.value)}
              />
            </div>
          ) : null}

          {filteredHistoryMatches.length === 0 ? (
            <div className="dashboard-empty">Completed matches will appear here once they are ended.</div>
          ) : (
            <>
              <div className="dashboard-list dashboard-list--desktop">
                {(showHistoryOnly
                  ? filteredHistoryMatches
                  : (showAllHistory ? filteredHistoryMatches : filteredHistoryMatches.slice(0, DASHBOARD_CAROUSEL_PAGE_SIZE))
                ).map((match) => renderHistoryMatchCard(match))}
              </div>
              <div className="dashboard-carousel dashboard-carousel--mobile">
                {showHistoryOnly || showAllHistory ? (
                  <div className="dashboard-list">
                    {filteredHistoryMatches.map((match) => renderHistoryMatchCard(match))}
                  </div>
                ) : (
                  <>
                    <div className="dashboard-carousel__page">
                      <div className="dashboard-list">
                        {visibleHistoryPage.map((match) => renderHistoryMatchCard(match))}
                      </div>
                    </div>
                    {hasHistoryCarousel ? renderPagerDots(historyPages.length, historyPage, setHistoryPage, "History pages") : null}
                  </>
                )}
              </div>
            </>
          )}
        </section>
        ) : null}

      </section>

      <AppFooter />
    </main>
  );
}
