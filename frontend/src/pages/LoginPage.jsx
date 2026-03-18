import React, { useState } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import { useAuth } from "../hooks/useAuth";
import { registerInterest } from "../services/api";

function createCaptchaChallenge() {
  const left = Math.floor(Math.random() * 8) + 2;
  const right = Math.floor(Math.random() * 8) + 2;

  return {
    prompt: `Human check: what is ${left} + ${right}?`,
    answer: String(left + right),
  };
}

export default function LoginPage() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [showInterestForm, setShowInterestForm] = useState(false);
  const [interestEmail, setInterestEmail] = useState("");
  const [interestCaptcha, setInterestCaptcha] = useState(() => createCaptchaChallenge());
  const [interestAnswer, setInterestAnswer] = useState("");
  const [interestHoneypot, setInterestHoneypot] = useState("");
  const [interestError, setInterestError] = useState("");
  const [interestMessage, setInterestMessage] = useState("");
  const [interestLoading, setInterestLoading] = useState(false);
  const { isAuthenticated, loading, login } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const redirectTo = location.state?.from?.pathname || "/dashboard";

  if (isAuthenticated) {
    return <Navigate replace to={redirectTo} />;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const result = await login(username, password);

    if (!result.ok) {
      setError(result.message);
      return;
    }

    navigate(redirectTo, { replace: true });
  }

  async function handleInterestSubmit(event) {
    event.preventDefault();

    if (!interestEmail.trim()) {
      setInterestError("Email address is required.");
      return;
    }

    if (interestAnswer.trim() !== interestCaptcha.answer) {
      setInterestError("Human check answer is incorrect.");
      setInterestCaptcha(createCaptchaChallenge());
      setInterestAnswer("");
      return;
    }

    setInterestLoading(true);
    setInterestError("");
    setInterestMessage("");

    try {
      await registerInterest({
        email: interestEmail.trim(),
        company: interestHoneypot,
        page_url: typeof window !== "undefined" ? window.location.href : "",
        user_agent: typeof navigator !== "undefined" ? navigator.userAgent : "",
      });
      setInterestMessage("Thanks. We have recorded your interest and will be in touch.");
      setInterestEmail("");
      setInterestAnswer("");
      setInterestHoneypot("");
      setInterestCaptcha(createCaptchaChallenge());
    } catch (requestError) {
      setInterestError(requestError.message || "Unable to submit your interest right now.");
    } finally {
      setInterestLoading(false);
    }
  }

  return (
    <main className="page-shell login-shell">
      <section className="login-panel stack">
        <span className="status-pill">RcktScore v2</span>
        <h1>Rckt Score Login</h1>

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
            <button disabled={loading} type="submit">
              {loading ? "Signing In..." : "Sign In"}
            </button>
          </div>
        </form>

        <div className="stack compact">
          <button
            className="text-link-button"
            type="button"
            onClick={() => {
              setShowInterestForm((current) => !current);
              setInterestError("");
              setInterestMessage("");
              setInterestCaptcha(createCaptchaChallenge());
              setInterestAnswer("");
            }}
          >
            Register interest
          </button>

          {showInterestForm ? (
            <form className="interest-panel stack compact" onSubmit={handleInterestSubmit}>
              <div className="field">
                <label htmlFor="interest_email">Email address</label>
                <input
                  id="interest_email"
                  name="interest_email"
                  placeholder="you@club.com"
                  type="email"
                  value={interestEmail}
                  onChange={(event) => {
                    setInterestEmail(event.target.value);
                    if (interestError) {
                      setInterestError("");
                    }
                  }}
                />
              </div>

              <div className="interest-honeypot" aria-hidden="true">
                <label htmlFor="company">Company</label>
                <input
                  autoComplete="off"
                  id="company"
                  name="company"
                  tabIndex="-1"
                  type="text"
                  value={interestHoneypot}
                  onChange={(event) => setInterestHoneypot(event.target.value)}
                />
              </div>

              <div className="field">
                <label htmlFor="interest_captcha">{interestCaptcha.prompt}</label>
                <input
                  id="interest_captcha"
                  name="interest_captcha"
                  placeholder="Enter answer"
                  inputMode="numeric"
                  value={interestAnswer}
                  onChange={(event) => {
                    setInterestAnswer(event.target.value);
                    if (interestError) {
                      setInterestError("");
                    }
                  }}
                />
              </div>

              {interestError ? <div className="notice error">{interestError}</div> : null}
              {interestMessage ? <div className="notice settings-success">{interestMessage}</div> : null}

              <div className="button-row">
                <button disabled={interestLoading} type="submit">
                  {interestLoading ? "Sending..." : "Send Register Interest"}
                </button>
              </div>
            </form>
          ) : null}
        </div>
      </section>
      <div className="login-footer-wrap">
        <AppFooter />
      </div>
    </main>
  );
}
