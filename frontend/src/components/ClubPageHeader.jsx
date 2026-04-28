import React, { useEffect, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import { useAuth } from "../hooks/useAuth";

function inferOrganizationType(session) {
  if (session?.organization_type) {
    return session.organization_type;
  }

  return Number(session?.organization_id) >= 50000 ? "personal" : "club";
}

function planLabel(plan) {
  if (plan === "personal_plus") {
    return "Personal+";
  }
  if (plan === "personal_free") {
    return "Personal Free";
  }
  if (plan === "club_pro") {
    return "Club Pro";
  }
  return "Club Essentials";
}

export default function ClubPageHeader({ title, subtitle, actions = [], className = "" }) {
  const navigate = useNavigate();
  const location = useLocation();
  const { session, logout } = useAuth();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const organizationName = session?.organization_name || "";
  const organizationType = inferOrganizationType(session);
  const accountSubline = organizationType === "personal"
    ? planLabel(session?.plan || "personal_free")
    : organizationName || "Club";
  const pageTitle = title && title !== organizationName ? title : "";
  const mobileMenuItems = [
    { label: "Home", onClick: () => navigate("/dashboard") },
    { label: "Matches", onClick: () => navigate("/dashboard#active-matches-section") },
    { label: "History", onClick: () => navigate("/dashboard#match-history-section") },
    { label: "Settings", onClick: () => navigate("/settings") },
    { label: "Need Help", onClick: () => navigate("/ping") },
  ];

  useEffect(() => {
    setMobileMenuOpen(false);
  }, [location.pathname, location.hash]);

  return (
    <>
      <span className="beta-badge page-beta-badge">Beta</span>
      <section className={`hero-card club-page-header ${className}`.trim()}>
        <div className="club-page-header__top">
          <div className="club-page-header__branding">
            <div className="club-page-header__brand-row">
              <img
                className="club-page-header__logo"
                src="/branding/logo/brand-logo.png"
                alt="Hit n Score"
              />
              <div className="club-page-header__brand-stack">
                <h1 className="club-page-header__wordmark" aria-label="HitnScore">
                  <span className="club-page-header__wordmark-hit">Hit</span>
                  <span className="club-page-header__wordmark-n">n</span>
                  <span className="club-page-header__wordmark-score">Score</span>
                </h1>
                <span className="club-page-header__mobile-username">{session?.username || "Operator"}</span>
                <span className="club-page-header__mobile-plan">{accountSubline}</span>
              </div>
            </div>
            {pageTitle ? <p className="club-page-header__page-title">{pageTitle}</p> : null}
          </div>
          <div className="club-page-header__account">
            <div className="club-page-header__meta">
              <button
                className="club-page-header__notification-button"
                type="button"
                aria-label="Notifications"
              >
                <svg
                  aria-hidden="true"
                  className="club-page-header__notification-icon"
                  viewBox="0 0 24 24"
                  fill="none"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <path
                    d="M12 4.75C9.79086 4.75 8 6.54086 8 8.75V10.6881C8 11.415 7.76918 12.1231 7.3406 12.7102L6.27218 14.1739C5.6203 15.0669 6.25792 16.3333 7.36346 16.3333H16.6365C17.7421 16.3333 18.3797 15.0669 17.7278 14.1739L16.6594 12.7102C16.2308 12.1231 16 11.415 16 10.6881V8.75C16 6.54086 14.2091 4.75 12 4.75Z"
                    stroke="currentColor"
                    strokeWidth="1.8"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  <path
                    d="M10.25 18.25C10.6124 18.8712 11.2522 19.25 12 19.25C12.7478 19.25 13.3876 18.8712 13.75 18.25"
                    stroke="currentColor"
                    strokeWidth="1.8"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </button>
              <button
                className="session-link-button"
                type="button"
                onClick={() => {
                  logout();
                  navigate("/", { replace: true });
                }}
              >
                Logout
              </button>
              <span className="club-page-header__divider" aria-hidden="true">
                |
              </span>
              <span className="club-page-header__username">{session?.username || "Operator"}</span>
            </div>
            <span className="club-page-header__organization-name">{accountSubline}</span>
          </div>
        </div>

        {subtitle ? (
          <div className="club-page-header__copy">
            <p className="helper-text">{subtitle}</p>
          </div>
        ) : null}
      </section>

      {actions.length ? (
        <section className="dashboard-menu-row" aria-label="Club page menu">
          {actions.map((action) => (
            <button
              key={action.label}
              className="dashboard-menu-button"
              type="button"
              onClick={action.onClick}
            >
              {action.label}
            </button>
          ))}
        </section>
      ) : null}

      <button
        className="mobile-fab-menu-button"
        type="button"
        aria-label={mobileMenuOpen ? "Close navigation menu" : "Open navigation menu"}
        aria-expanded={mobileMenuOpen ? "true" : "false"}
        onClick={() => setMobileMenuOpen((current) => !current)}
      >
        <span />
        <span />
        <span />
      </button>

      {mobileMenuOpen ? (
        <div className="mobile-fab-menu-overlay" role="presentation">
          <button
            className="mobile-fab-menu-overlay__backdrop"
            type="button"
            aria-label="Close navigation menu"
            onClick={() => setMobileMenuOpen(false)}
          />
          <div className="mobile-fab-menu-sheet" role="dialog" aria-modal="true" aria-label="Quick navigation">
            <div className="mobile-fab-menu-sheet__handle" aria-hidden="true" />
            <div className="mobile-fab-menu-sheet__items">
              {mobileMenuItems.map((item) => (
                <button
                  key={item.label}
                  className="mobile-fab-menu-sheet__item"
                  type="button"
                  onClick={item.onClick}
                >
                  {item.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
