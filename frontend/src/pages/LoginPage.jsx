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
  const {
    isAuthenticated,
    loading,
    login,
    pendingSelection,
    requiresOrganizationSelection,
    selectOrganization,
    cancelOrganizationSelection,
  } = useAuth();
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

    if (result.requiresOrganizationSelection) {
      setError("");
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
      <span className="beta-badge page-beta-badge">Beta</span>
      <section className="login-panel stack">
        <div className="login-panel__top">
          <div className="login-branding">
            <img
              className="login-branding__logo"
              src="/branding/logo/test_logo_1024.png"
              alt="Hit n Score"
            />
            <h1 className="login-title">Hit n Score Login</h1>
          </div>
        </div>

        {requiresOrganizationSelection ? (
          <div className="stack">
            <div className="panel stack compact login-choice-panel">
              <div className="panel-heading">
                <h2>Choose Organisation</h2>
                <p className="helper-text">
                  {pendingSelection?.username || "This user"} belongs to multiple organisations. Choose one to continue.
                </p>
              </div>

              <div className="stack compact">
                {(pendingSelection?.memberships || []).map((membership) => (
                  <button
                    key={`${membership.organization_id}-${membership.id}`}
                    className="login-org-choice"
                    type="button"
                    onClick={() => {
                      selectOrganization(membership);
                      navigate(redirectTo, { replace: true });
                    }}
                  >
                    <strong>{membership.organization_name || `Organisation ${membership.organization_id}`}</strong>
                    <span>{membership.role || "user"}</span>
                  </button>
                ))}
              </div>

              <div className="button-row">
                <button className="secondary" type="button" onClick={cancelOrganizationSelection}>
                  Back to Login
                </button>
              </div>
            </div>
          </div>
        ) : (
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

            <div className="button-row login-action-row">
              <button disabled={loading} type="submit">
                {loading ? "Signing In..." : "Sign In"}
              </button>
              <button
                className="text-link-button login-inline-link"
                type="button"
                onClick={() => {
                  setShowInterestForm((current) => !current);
                  setInterestError("");
                  setInterestMessage("");
                  setInterestCaptcha(createCaptchaChallenge());
                  setInterestAnswer("");
                }}
              >
                Want In
              </button>
            </div>
          </form>
        )}

        <div className="stack compact">
          {showInterestForm ? (
            <form className="interest-panel stack compact" onSubmit={handleInterestSubmit}>
              <p className="helper-text interest-copy">
                Request early access to RcktScore. We are cuurently in a beta phase. Request early access by submitting your details—approved users will be granted access to the platform.
              </p>

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
