import React from "react";
import { useNavigate } from "react-router-dom";

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
  const { session, logout } = useAuth();
  const organizationName = session?.organization_name || "";
  const organizationType = inferOrganizationType(session);
  const accountSubline = organizationType === "personal"
    ? planLabel(session?.plan || "personal_free")
    : organizationName || "Club";
  const pageTitle = title && title !== organizationName ? title : "";

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
                <span aria-hidden="true">🔔</span>
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
    </>
  );
}
