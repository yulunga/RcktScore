import React from "react";
import { NavLink, useNavigate } from "react-router-dom";

import { useRootAdmin } from "../hooks/useRootAdmin";

const CONTROL_PANEL_LINKS = [
  { route: "dashboard", label: "Home", icon: "m3 10 9-7 9 7v10h-6v-6H9v6H3z" },
  { route: "users", label: "Users", icon: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2m20 0v-2a4 4 0 0 0-3-4m-3-12a4 4 0 0 1 0 8M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0Z" },
  { route: "racket-sports", label: "Settings", icon: "M9.7 3.1h4.6l.6 2.2 1.3.7 2.1-.6 2.3 4-1.6 1.6v2l1.6 1.6-2.3 4-2.1-.6-1.3.7-.6 2.2H9.7l-.6-2.2-1.3-.7-2.1.6-2.3-4L5 13v-2L3.4 9.4l2.3-4 2.1.6 1.3-.7zM15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" },
];

export default function RootAdminSessionBar() {
  const navigate = useNavigate();
  const { session, logout } = useRootAdmin();

  return (
    <section className="session-bar">
      <div className="root-admin-session-brand">
        <img src="/branding/logo/brand-logo.png" alt="HitnScore" width="44" height="44" />
        <div>
          <strong><span>HitnScore</span> Control Panel</strong>
          <span>
            {(session?.username || "Root Admin")}
          </span>
        </div>
      </div>
      <div className="club-page-header__meta root-admin-session-actions">
        <button
          className="session-link-button"
          type="button"
          onClick={() => {
            logout();
            navigate("/rckscoreAdmin", { replace: true });
          }}
        >
          Log Out
        </button>
        <nav className="root-admin-session-nav" aria-label="Control Panel">
          {CONTROL_PANEL_LINKS.map(({ route, label, icon }) => (
            <NavLink
              key={route}
              to={`/rckscoreAdmin/${route}`}
              className="session-link-button root-admin-dashboard-link"
              aria-label={label}
              title={label}
            >
              <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d={icon} />
              </svg>
            </NavLink>
          ))}
        </nav>
      </div>
    </section>
  );
}
