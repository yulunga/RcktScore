import React from "react";
import { useNavigate } from "react-router-dom";

import { useRootAdmin } from "../hooks/useRootAdmin";

export default function RootAdminSessionBar() {
  const navigate = useNavigate();
  const { session, logout } = useRootAdmin();

  return (
    <section className="session-bar">
      <div>
        <strong>RcktScore Root Admin</strong>
        <span>
          {(session?.username || "Root Admin")}
          {session?.role ? ` • ${session.role}` : ""}
        </span>
      </div>
      <div className="club-page-header__meta">
        <span className="beta-badge">Beta</span>
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
      </div>
    </section>
  );
}
