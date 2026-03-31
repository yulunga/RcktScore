import React, { useState } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import { useRootAdmin } from "../hooks/useRootAdmin";

function createCaptchaChallenge() {
  const left = Math.floor(Math.random() * 8) + 2;
  const right = Math.floor(Math.random() * 8) + 2;

  return {
    prompt: `Human check: what is ${left} + ${right}?`,
    answer: String(left + right),
  };
}

export default function RootAdminLoginPage() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [captcha, setCaptcha] = useState(() => createCaptchaChallenge());
  const [captchaAnswer, setCaptchaAnswer] = useState("");
  const [honeypot, setHoneypot] = useState("");
  const [error, setError] = useState("");
  const { isAuthenticated, loading, login } = useRootAdmin();
  const location = useLocation();
  const navigate = useNavigate();
  const redirectTo = location.state?.from?.pathname || "/rckscoreAdmin/dashboard";

  if (isAuthenticated) {
    return <Navigate replace to={redirectTo} />;
  }

  async function handleSubmit(event) {
    event.preventDefault();

    if (honeypot.trim()) {
      setError("Unable to sign in.");
      return;
    }

    if (captchaAnswer.trim() !== captcha.answer) {
      setError("Human check answer is incorrect.");
      setCaptcha(createCaptchaChallenge());
      setCaptchaAnswer("");
      return;
    }

    const result = await login(username, password);
    if (!result.ok) {
      setError(result.message);
      setCaptcha(createCaptchaChallenge());
      setCaptchaAnswer("");
      return;
    }

    navigate(redirectTo, { replace: true });
  }

  return (
    <main className="page-shell login-shell">
      <section className="login-panel stack">
        <div className="login-panel__top">
          <h1 className="login-title">RcktScore Root Admin</h1>
          <span className="beta-badge">Beta</span>
        </div>
        <p className="helper-text root-admin-login-note">
          Root administration access for tenant and user management. IP restrictions can be added later.
        </p>

        <form className="stack" onSubmit={handleSubmit}>
          <div className="field">
            <label htmlFor="root_admin_username">Root Username</label>
            <input
              autoComplete="username"
              id="root_admin_username"
              name="root_admin_username"
              placeholder="Enter root username"
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
            <label htmlFor="root_admin_password">Password</label>
            <input
              autoComplete="current-password"
              id="root_admin_password"
              name="root_admin_password"
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

          <div className="interest-honeypot" aria-hidden="true">
            <label htmlFor="root_admin_company">Company</label>
            <input
              autoComplete="off"
              id="root_admin_company"
              name="root_admin_company"
              tabIndex="-1"
              type="text"
              value={honeypot}
              onChange={(event) => setHoneypot(event.target.value)}
            />
          </div>

          <div className="field">
            <label htmlFor="root_admin_captcha">{captcha.prompt}</label>
            <input
              id="root_admin_captcha"
              name="root_admin_captcha"
              placeholder="Enter answer"
              inputMode="numeric"
              value={captchaAnswer}
              onChange={(event) => {
                setCaptchaAnswer(event.target.value);
                if (error) {
                  setError("");
                }
              }}
            />
          </div>

          {error ? <div className="notice error">{error}</div> : null}

          <div className="button-row">
            <button disabled={loading} type="submit">
              {loading ? "Signing In..." : "Sign In"}
            </button>
          </div>
        </form>
      </section>
      <div className="login-footer-wrap">
        <AppFooter />
      </div>
    </main>
  );
}
