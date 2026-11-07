import React from "react";
import { useNavigate } from "react-router-dom";

import { useRootAdmin } from "../hooks/useRootAdmin";

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
        <button
          className="session-link-button root-admin-dashboard-link"
          type="button"
          aria-label="Control Panel dashboard"
          title="Control Panel dashboard"
          onClick={() => navigate("/rckscoreAdmin/dashboard")}
        >
          <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="m3 10 9-7 9 7v10h-6v-6H9v6H3z" />
          </svg>
        </button>
      </div>
    </section>
  );
}
