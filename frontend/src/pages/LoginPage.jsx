import React, { useEffect, useState } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";

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
  const [interestFirstName, setInterestFirstName] = useState("");
  const [interestSurname, setInterestSurname] = useState("");
  const [interestEmail, setInterestEmail] = useState("");
  const [interestUseType, setInterestUseType] = useState("personal");
  const [interestClubName, setInterestClubName] = useState("");
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
  const hasInterestDraft = Boolean(
    interestFirstName.trim()
    || interestSurname.trim()
    || interestEmail.trim()
    || interestClubName.trim()
    || interestAnswer.trim()
    || interestUseType !== "personal",
  );

  useEffect(() => {
    if (!showInterestForm || hasInterestDraft) {
      return undefined;
    }

    const timeoutId = window.setTimeout(() => {
      setShowInterestForm(false);
      setInterestError("");
      setInterestMessage("");
      setInterestCaptcha(createCaptchaChallenge());
      setInterestAnswer("");
    }, 15000);

    return () => window.clearTimeout(timeoutId);
  }, [hasInterestDraft, showInterestForm]);

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

    if (!interestFirstName.trim()) {
      setInterestError("Name is required.");
      return;
    }

    if (!interestSurname.trim()) {
      setInterestError("Surname is required.");
      return;
    }

    if (!interestEmail.trim()) {
      setInterestError("Email address is required.");
      return;
    }

    if (interestUseType === "club" && !interestClubName.trim()) {
      setInterestError("Club name is required for club use.");
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
        first_name: interestFirstName.trim(),
        surname: interestSurname.trim(),
        email: interestEmail.trim(),
        use_type: interestUseType,
        club_name: interestUseType === "club" ? interestClubName.trim() : "",
        company: interestHoneypot,
        page_url: typeof window !== "undefined" ? window.location.href : "",
        user_agent: typeof navigator !== "undefined" ? navigator.userAgent : "",
      });
      setInterestMessage("Thanks. We have recorded your interest and will be in touch.");
      setInterestFirstName("");
      setInterestSurname("");
      setInterestEmail("");
      setInterestUseType("personal");
      setInterestClubName("");
      setInterestAnswer("");
      setInterestHoneypot("");
      setInterestCaptcha(createCaptchaChallenge());
      window.setTimeout(() => {
        setShowInterestForm(false);
        setInterestMessage("");
        setInterestError("");
      }, 5000);
    } catch (requestError) {
      setInterestError(requestError.message || "Unable to submit your interest right now.");
    } finally {
      setInterestLoading(false);
    }
  }

  return (
    <main className="page-shell login-shell">
      <div className="login-shell__content">
        <div className="login-panel-wrap">
          <span className="beta-badge page-beta-badge">Beta</span>
          <section className="login-panel stack">
            <div className="login-panel__top">
              <div className="login-branding">
                <img
                  className="login-branding__logo"
                  src="/branding/logo/test_logo_2.png"
                  alt="Hit n Score"
                />
                <h1 className="login-title login-title--wordmark" aria-label="HitnScore">
                  <span className="login-title__hit">Hit</span>
                  <span className="login-title__n">n</span>
                  <span className="login-title__score">Score</span>
                </h1>
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
                  <h2 className="interest-panel__heading">Let me in</h2>
                  <p className="helper-text interest-copy">
                    We are currently in a beta phase. Request early access by submitting your details.
                    <br />
                    <br />
                    Approved users will be granted access to the platform.
                  </p>

                  <div className="field-grid">
                    <div className="field">
                      <label htmlFor="interest_first_name">Name</label>
                      <input
                        id="interest_first_name"
                        name="interest_first_name"
                        required
                        value={interestFirstName}
                        onChange={(event) => {
                          setInterestFirstName(event.target.value);
                          if (interestError) {
                            setInterestError("");
                          }
                        }}
                      />
                    </div>

                    <div className="field">
                      <label htmlFor="interest_surname">Surname</label>
                      <input
                        id="interest_surname"
                        name="interest_surname"
                        required
                        value={interestSurname}
                        onChange={(event) => {
                          setInterestSurname(event.target.value);
                          if (interestError) {
                            setInterestError("");
                          }
                        }}
                      />
                    </div>
                  </div>

                  <div className="field">
                    <label htmlFor="interest_email">Email address</label>
                    <input
                      id="interest_email"
                      name="interest_email"
                      placeholder="you@email.com"
                      required
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

                  <div className="field">
                    <label htmlFor="interest_use_type">App Use</label>
                    <select
                      id="interest_use_type"
                      name="interest_use_type"
                      value={interestUseType}
                      onChange={(event) => {
                        setInterestUseType(event.target.value);
                        if (interestError) {
                          setInterestError("");
                        }
                      }}
                    >
                      <option value="personal">Personal use</option>
                      <option value="club">Club use</option>
                    </select>
                  </div>

                  {interestUseType === "club" ? (
                    <div className="field">
                      <label htmlFor="interest_club_name">Club name</label>
                      <input
                        id="interest_club_name"
                        name="interest_club_name"
                        required
                        value={interestClubName}
                        onChange={(event) => {
                          setInterestClubName(event.target.value);
                          if (interestError) {
                            setInterestError("");
                          }
                        }}
                      />
                    </div>
                  ) : null}

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

            <div className="login-help-link">
              <Link to="/help">Need help?</Link>
            </div>
          </section>
        </div>
      </div>
      <div className="login-footer-wrap">
        <AppFooter />
      </div>
    </main>
  );
}
