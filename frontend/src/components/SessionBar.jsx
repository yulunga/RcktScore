import { useNavigate } from "react-router-dom";

import { useAuth } from "../hooks/useAuth";

export default function SessionBar() {
  const navigate = useNavigate();
  const { session, logout } = useAuth();

  return (
    <section className="session-bar">
      <div>
        <strong>Signed in</strong>
        <span>{session?.username || "Operator"}</span>
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
