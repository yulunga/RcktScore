import React from "react";
import { useNavigate } from "react-router-dom";

import { useAuth } from "../hooks/useAuth";

export default function ClubPageHeader({ title, subtitle, actions = [], className = "" }) {
  const navigate = useNavigate();
  const { session, logout } = useAuth();
  const organizationName = session?.organization_name || "";
  const pageTitle = title && title !== organizationName ? title : "";

  return (
    <>
      <span className="beta-badge page-beta-badge">Beta</span>
      <section className={`hero-card club-page-header ${className}`.trim()}>
        <div className="club-page-header__top">
          <div className="club-page-header__branding">
            <h1>PointPal</h1>
            {pageTitle ? <p className="club-page-header__page-title">{pageTitle}</p> : null}
          </div>
          <div className="club-page-header__account">
            <div className="club-page-header__meta">
              <button
                className="session-link-button"
                type="button"
                onClick={() => {
                  logout();
                  navigate("/", { replace: true });
                }}
              >
                Log Out
              </button>
              <span className="club-page-header__divider" aria-hidden="true">
                |
              </span>
              <span className="club-page-header__username">{session?.username || "Operator"}</span>
            </div>
            <span className="club-page-header__organization-name">{organizationName || "Club"}</span>
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
