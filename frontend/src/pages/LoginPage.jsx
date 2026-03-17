import { useState } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";

import { useAuth } from "../hooks/useAuth";

export default function LoginPage() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const { isAuthenticated, login } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const redirectTo = location.state?.from?.pathname || "/match/new";

  if (isAuthenticated) {
    return <Navigate replace to={redirectTo} />;
  }

  function handleSubmit(event) {
    event.preventDefault();
    const result = login(username, password);

    if (!result.ok) {
      setError(result.message);
      return;
    }

    navigate(redirectTo, { replace: true });
  }

  return (
    <main className="page-shell login-shell">
      <section className="login-panel stack">
        <span className="status-pill">RcktScore v2</span>
        <h1>Operator Login</h1>
        <p className="helper-text">
          Sign in before opening the live scoring console for a court.
        </p>

        <form className="stack" onSubmit={handleSubmit}>
          <div className="field">
            <label htmlFor="username">Username</label>
            <input
              autoComplete="username"
              id="username"
              name="username"
              placeholder="Enter username"
              value={username}
              onChange={(event) => {
                setUsername(event.target.value);
                if (error) {
                  setError("");
                }
              }}
            />
          </div>

          <div className="field">
            <label htmlFor="password">Password</label>
            <input
              autoComplete="current-password"
              id="password"
              name="password"
              placeholder="Enter password"
              type="password"
              value={password}
              onChange={(event) => {
                setPassword(event.target.value);
                if (error) {
                  setError("");
                }
              }}
            />
          </div>

          {error ? <div className="notice error">{error}</div> : null}

          <div className="button-row">
            <button type="submit">Sign In</button>
          </div>
        </form>
      </section>
    </main>
  );
}
