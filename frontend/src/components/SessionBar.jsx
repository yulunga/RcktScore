import React from "react";
import { useNavigate } from "react-router-dom";

import { useAuth } from "../hooks/useAuth";

export default function SessionBar() {
  const navigate = useNavigate();
  const { session, logout } = useAuth();

  return (
    <section className="session-bar">
      <div>
        <strong>{session?.organization_name || "Club"}</strong>
        <span>
          {(session?.username || "Operator")}
          {session?.role ? ` • ${session.role}` : ""}
        </span>
      </div>
      <button
        className="secondary"
        type="button"
        onClick={() => {
          logout();
          navigate("/", { replace: true });
        }}
      >
        Log Out
      </button>
    </section>
  );
}
