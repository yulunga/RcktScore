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

function MobileMenuIcon({ name }) {
  if (name === "home") {
    return (
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M4.75 10.25L12 4.75L19.25 10.25V18.25H14.75V13.75H9.25V18.25H4.75V10.25Z" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }

  if (name === "matches") {
    return (
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="5" y="4.75" width="14" height="14.5" rx="2.5" stroke="currentColor" strokeWidth="1.8" />
        <path d="M8.25 3.75V6.25" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M15.75 3.75V6.25" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M8.25 10.25H15.75" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M8.75 13.25H12.25" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      </svg>
    );
  }

  if (name === "history") {
    return (
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M5.75 12C5.75 8.54822 8.54822 5.75 12 5.75C15.4518 5.75 18.25 8.54822 18.25 12C18.25 15.4518 15.4518 18.25 12 18.25C9.58996 18.25 7.49872 16.887 6.45091 14.8889" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M5.75 8.25V5.75H8.25" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M12 8.5V12.25L14.5 13.75" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }

  if (name === "settings") {
    return (
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 9.25C10.4812 9.25 9.25 10.4812 9.25 12C9.25 13.5188 10.4812 14.75 12 14.75C13.5188 14.75 14.75 13.5188 14.75 12C14.75 10.4812 13.5188 9.25 12 9.25Z" stroke="currentColor" strokeWidth="1.8" />
        <path d="M18.25 12C18.25 11.4809 18.1891 10.9761 18.074 10.4926L20 9L18 5.5L15.7747 6.27133C14.9942 5.64352 14.0707 5.18715 13.0596 4.95545L12.5 2.75H11.5L10.9404 4.95545C9.92926 5.18715 9.00585 5.64352 8.2253 6.27133L6 5.5L4 9L5.92602 10.4926C5.81091 10.9761 5.75 11.4809 5.75 12C5.75 12.5191 5.81091 13.0239 5.92602 13.5074L4 15L6 18.5L8.2253 17.7287C9.00585 18.3565 9.92926 18.8128 10.9404 19.0446L11.5 21.25H12.5L13.0596 19.0446C14.0707 18.8128 14.9942 18.3565 15.7747 17.7287L18 18.5L20 15L18.074 13.5074C18.1891 13.0239 18.25 12.5191 18.25 12Z" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M12 18.25C15.4518 18.25 18.25 15.4518 18.25 12C18.25 8.54822 15.4518 5.75 12 5.75C8.54822 5.75 5.75 8.54822 5.75 12C5.75 15.4518 8.54822 18.25 12 18.25Z" stroke="currentColor" strokeWidth="1.8" />
      <path d="M9.75 9.75C10.25 9.25 10.9796 8.95 11.7794 8.95C13.3028 8.95 14.55 10.1418 14.55 11.65C14.55 12.6945 13.963 13.6017 13.1 14.05C12.6161 14.3013 12.25 14.7286 12.25 15.2V15.45" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <circle cx="12" cy="17.35" r="0.9" fill="currentColor" />
    </svg>
  );
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
  const navigateToDashboardSection = (sectionId) => {
    navigate(`/dashboard#${sectionId}`);
  };
  const mobileMenuItems = [
    { label: "Home", icon: "home", onClick: () => navigate("/dashboard"), isActive: location.pathname === "/dashboard" && !location.hash },
    { label: "Matches", icon: "matches", onClick: () => navigateToDashboardSection("active-matches-section"), isActive: location.pathname === "/dashboard" && location.hash === "#active-matches-section" },
    { label: "History", icon: "history", onClick: () => navigateToDashboardSection("match-history-section"), isActive: location.pathname === "/dashboard" && location.hash === "#match-history-section" },
    { label: "Settings", icon: "settings", onClick: () => navigate("/settings"), isActive: location.pathname === "/settings" },
    { label: "Need Help", icon: "help", onClick: () => navigate("/ping"), isActive: location.pathname === "/ping" },
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
        className={`mobile-fab-menu-button${mobileMenuOpen ? " mobile-fab-menu-button--open" : ""}`}
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
                  className={`mobile-fab-menu-sheet__item${item.isActive ? " mobile-fab-menu-sheet__item--active" : ""}`}
                  type="button"
                  onClick={item.onClick}
                >
                  <span className="mobile-fab-menu-sheet__icon" aria-hidden="true">
                    <MobileMenuIcon name={item.icon} />
                  </span>
                  <span className="mobile-fab-menu-sheet__label">{item.label}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
