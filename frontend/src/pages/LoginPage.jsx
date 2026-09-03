import React, { useEffect, useRef, useState } from "react";
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
  const [sessionConflictPrompt, setSessionConflictPrompt] = useState(null);
  const interestPanelRef = useRef(null);
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
  const shouldOpenInterestFormFromUrl = new URLSearchParams(location.search).get("interest") === "1"
    || location.hash === "#want-in";
  const hasInterestDraft = Boolean(
    interestFirstName.trim()
    || interestSurname.trim()
    || interestEmail.trim()
    || interestClubName.trim()
    || interestAnswer.trim()
    || interestUseType !== "personal",
  );

  useEffect(() => {
    if (!shouldOpenInterestFormFromUrl) {
      return;
    }

    setShowInterestForm(true);
    setInterestError("");
    setInterestMessage("");
    setInterestCaptcha(createCaptchaChallenge());
    setInterestAnswer("");
  }, [shouldOpenInterestFormFromUrl]);

  useEffect(() => {
    if (!showInterestForm || !shouldOpenInterestFormFromUrl) {
      return;
    }

    window.setTimeout(() => {
      interestPanelRef.current?.scrollIntoView({
        behavior: "smooth",
        block: "start",
      });
    }, 0);
  }, [showInterestForm, shouldOpenInterestFormFromUrl]);

  useEffect(() => {
    if (!showInterestForm || hasInterestDraft) {
      return undefined;
    }

    if (shouldOpenInterestFormFromUrl) {
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
  }, [hasInterestDraft, showInterestForm, shouldOpenInterestFormFromUrl]);

  if (isAuthenticated) {
    return <Navigate replace to={redirectTo} />;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const result = await login(username, password);

    if (!result.ok) {
      if (result.requiresSessionReplacement) {
        setError("");
        setSessionConflictPrompt({
          clientLabel: result.clientLabel || "web app",
          message: result.message,
        });
        return;
      }
      setError(result.message);
      return;
    }

    if (result.requiresOrganizationSelection) {
      setError("");
      return;
    }

    navigate(redirectTo, { replace: true });
  }

  async function handleConfirmReplaceSession() {
    const result = await login(username, password, { forceLogoutOther: true });
    if (!result.ok) {
      setSessionConflictPrompt(null);
      setError(result.message);
      return;
    }

    setSessionConflictPrompt(null);
    if (result.requiresOrganizationSelection) {
      setError("");
      return;
    }

    navigate(redirectTo, { replace: true });
  }

  async function handleInterestSubmit(event) {
    event.preventDefault();
    const requestedUseType = interestUseType;

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

    if (requestedUseType === "club" && !interestClubName.trim()) {
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
        use_type: requestedUseType,
        club_name: requestedUseType === "club" ? interestClubName.trim() : "",
        company: interestHoneypot,
        page_url: typeof window !== "undefined" ? window.location.href : "",
        user_agent: typeof navigator !== "undefined" ? navigator.userAgent : "",
      });
      setInterestMessage(
        requestedUseType === "personal"
          ? "Your personal account has been created. Check your email to verify your address and choose your password."
          : "Thanks. We have received your club enquiry and will be in touch.",
      );
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
      setInterestError(
        requestError.message
          || (requestedUseType === "personal"
            ? "Unable to create your personal account right now."
            : "Unable to submit your club enquiry right now."),
      );
    } finally {
      setInterestLoading(false);
    }
  }

  return (
    <main className="page-shell login-shell">
      <div className="login-shell__content">
        <div className="login-panel-wrap">
          <section className="login-panel stack">
            <div className="login-panel__top">
              <div className="login-branding">
                <img
                  className="login-branding__logo"
                  src="/branding/logo/brand-logo.png"
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
                      setSessionConflictPrompt(null);
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
                      setSessionConflictPrompt(null);
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
                <form ref={interestPanelRef} className="interest-panel stack compact" onSubmit={handleInterestSubmit}>
                  <h2 className="interest-panel__heading">Join Hit n Score</h2>
                  <p className="helper-text interest-copy">
                    Welcome to Hit n Score — the racket-sport scoring app.
                    <br />
                    <br />
                    Create a free personal account to start scoring matches. Registered users can access additional
                    features, with the option to upgrade for more advanced tools.
                    <br />
                    <br />
                    Looking for a multi-user account for a racket club? Club accounts are currently set up with our
                    team. Register your interest and we’ll be in touch.
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
                      {interestLoading
                        ? "Sending..."
                        : (interestUseType === "personal" ? "Create Personal Account" : "Register Club Interest")}
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
      {sessionConflictPrompt ? (
        <div className="overlay-backdrop">
          <div className="overlay-panel overlay-panel--match-confirm stack">
            <div className="panel-heading">
              <h2>Already Signed In</h2>
              <p className="helper-text">
                {sessionConflictPrompt.message
                  || `This account is already signed in on the ${sessionConflictPrompt.clientLabel}.`}
              </p>
            </div>
            <div className="button-row">
              <button
                className="secondary"
                type="button"
                onClick={() => setSessionConflictPrompt(null)}
              >
                Cancel
              </button>
              <button type="button" onClick={handleConfirmReplaceSession}>
                Log Out Other {sessionConflictPrompt.clientLabel === "mobile app" ? "Mobile" : "Web"} Session
              </button>
            </div>
          </div>
        </div>
      ) : null}
      <div className="login-footer-wrap">
        <AppFooter />
      </div>
    </main>
  );
}
