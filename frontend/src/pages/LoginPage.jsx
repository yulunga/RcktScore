import React, { useEffect, useRef, useState } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";

import { useAuth } from "../hooks/useAuth";
import { getRegistrationStatus, registerInterest, submitRegistrationInterest } from "../services/api";
import { clubRoleLabel } from "../utils/accessControl";
import SessionLoadingScreen from "../components/SessionLoadingScreen";

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
  const [showHelpOptions, setShowHelpOptions] = useState(false);
  const [registration, setRegistration] = useState(null);
  const [registrationError, setRegistrationError] = useState("");
  const [registrationRefresh, setRegistrationRefresh] = useState(0);
  const registrationPaused = registration?.enabled === false;
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
  const [interestAccountExists, setInterestAccountExists] = useState(false);
  const [sessionConflictPrompt, setSessionConflictPrompt] = useState(null);
  const interestPanelRef = useRef(null);
  const {
    isAuthenticated,
    loading,
    restoringSession,
    login,
    pendingSelection,
    requiresOrganizationSelection,
    selectOrganization,
    cancelOrganizationSelection,
  } = useAuth();
  const profileMessage = !isAuthenticated && typeof window !== "undefined"
    ? window.sessionStorage.getItem("rcktscore.session-message")
      || window.sessionStorage.getItem("rcktscore.profile-message")
      || ""
    : "";
  const location = useLocation();
  const navigate = useNavigate();
  const redirectTo = location.state?.from?.pathname || "/dashboard";
  const shouldOpenInterestFormFromUrl = new URLSearchParams(location.search).get("interest") === "1"
    || location.hash === "#want-in";
  const signupParameters = new URLSearchParams(location.search);
  const requestedPersonalPlan = signupParameters.get("plan") === "personal_plus" ? "personal_plus" : "personal_free";
  const hasInterestDraft = Boolean(
    interestFirstName.trim()
    || interestSurname.trim()
    || interestEmail.trim()
    || interestClubName.trim()
    || interestAnswer.trim()
    || interestUseType !== "personal",
  );

  useEffect(() => {
    if (profileMessage) {
      window.sessionStorage.removeItem("rcktscore.profile-message");
      window.sessionStorage.removeItem("rcktscore.session-message");
    }
  }, [profileMessage]);

  useEffect(() => {
    if (!shouldOpenInterestFormFromUrl) {
      return;
    }

    setShowInterestForm(true);
    setInterestError("");
    setInterestAccountExists(false);
    setInterestMessage("");
    setInterestCaptcha(createCaptchaChallenge());
    setInterestAnswer("");
    setInterestFirstName(signupParameters.get("first_name") || "");
    setInterestSurname(signupParameters.get("surname") || "");
    setInterestEmail(signupParameters.get("email") || "");
    setInterestUseType("personal");
  }, [shouldOpenInterestFormFromUrl]);

  useEffect(() => {
    if (!showInterestForm || isAuthenticated || restoringSession) return undefined;

    const controller = new AbortController();
    setRegistrationError("");
    getRegistrationStatus({ challenge: true, signal: controller.signal })
      .then((settings) => {
        if (!controller.signal.aborted) setRegistration(settings);
      })
      .catch(() => {
        if (!controller.signal.aborted) {
          setRegistrationError("Unable to check registration availability. Please try again.");
        }
      });
    return () => controller.abort();
  }, [showInterestForm, isAuthenticated, restoringSession, registrationRefresh]);

  function refreshRegistration() {
    setRegistration(null);
    setRegistrationError("");
    setRegistrationRefresh((revision) => revision + 1);
  }

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
    if (!showInterestForm || hasInterestDraft || registration?.enabled !== true) {
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
  }, [hasInterestDraft, registration?.enabled, showInterestForm, shouldOpenInterestFormFromUrl]);

  useEffect(() => {
    if (!showHelpOptions) return undefined;
    const timeoutId = window.setTimeout(() => setShowHelpOptions(false), 15000);
    return () => window.clearTimeout(timeoutId);
  }, [showHelpOptions]);

  if (restoringSession) {
    return <SessionLoadingScreen />;
  }

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

  function closeInterestForm() {
    setShowInterestForm(false);
    setInterestError("");
    setInterestMessage("");
    setInterestCaptcha(createCaptchaChallenge());
    setInterestAnswer("");
    if (shouldOpenInterestFormFromUrl) navigate("/", { replace: true });
  }

  function openInterestForm() {
    setShowHelpOptions(false);
    if (!showInterestForm) refreshRegistration();
    setShowInterestForm(true);
    setInterestError("");
    setInterestMessage("");
    setInterestCaptcha(createCaptchaChallenge());
    setInterestAnswer("");
  }

  function openHelpOptions() {
    setShowInterestForm(false);
    setShowHelpOptions(true);
  }

  async function handleInterestSubmit(event) {
    event.preventDefault();
    if (!registration) return;
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

    if (!registrationPaused && requestedUseType === "club" && !interestClubName.trim()) {
      setInterestError("Club name is required for club use.");
      return;
    }

    if (!registrationPaused && interestAnswer.trim() !== interestCaptcha.answer) {
      setInterestError("Human check answer is incorrect.");
      setInterestCaptcha(createCaptchaChallenge());
      setInterestAnswer("");
      return;
    }

    setInterestLoading(true);
    setInterestError("");
    setInterestAccountExists(false);
    setInterestMessage("");

    try {
      const details = {
        first_name: interestFirstName.trim(),
        surname: interestSurname.trim(),
        email: interestEmail.trim(),
        use_type: requestedUseType,
        company: interestHoneypot,
      };
      if (registrationPaused) {
        await submitRegistrationInterest({
          ...details,
          challenge_token: registration.challenge.token,
          challenge_answer: interestAnswer.trim(),
        });
      } else {
        await registerInterest({
          ...details,
          club_name: requestedUseType === "club" ? interestClubName.trim() : "",
          page_url: typeof window !== "undefined" ? window.location.href : "",
          user_agent: typeof navigator !== "undefined" ? navigator.userAgent : "",
        });
      }
      setInterestMessage(
        registrationPaused
          ? "Thanks for registering your interest. We’ll be in touch."
          : (requestedUseType === "personal"
            ? "Your personal account has been created. Check your email to verify your address and choose your password."
            : "Thanks. We have received your club enquiry and will be in touch."),
      );
      setInterestFirstName("");
      setInterestSurname("");
      setInterestEmail("");
      setInterestUseType("personal");
      setInterestClubName("");
      setInterestAnswer("");
      setInterestHoneypot("");
      setInterestCaptcha(createCaptchaChallenge());
      if (registrationPaused) return;
      window.setTimeout(() => {
        setShowInterestForm(false);
        setInterestMessage("");
        setInterestError("");
      }, 5000);
    } catch (requestError) {
      if (["REGISTRATION_PAUSED", "REGISTRATION_OPEN", "INVALID_HUMAN_CHECK"].includes(requestError.code)) {
        setInterestAnswer("");
        refreshRegistration();
      }
      setInterestAccountExists(requestError.code === "ACCOUNT_ALREADY_REGISTERED");
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
              <a className="login-branding" href="https://www.hitnscore.com/" aria-label="HitnScore landing page">
                <img
                  className="login-branding__logo"
                  src="/branding/logo/brand-logo.png"
                  alt=""
                />
                <h1 className="login-title login-title--wordmark" aria-hidden="true">
                  <span className="login-title__hit">Hit</span>
                  <span className="login-title__n">n</span>
                  <span className="login-title__score">Score</span>
                </h1>
              </a>
            </div>
            {profileMessage ? (
              <div className="notice settings-success">{profileMessage}</div>
            ) : null}
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
                        <span>{clubRoleLabel(membership.role)}</span>
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
                </div>
              </form>
            )}

            <div className="stack compact">
              {showInterestForm && !registration ? (
                <div ref={interestPanelRef} className="interest-panel login-panel-overlay stack compact" role="dialog" aria-modal="true" aria-label="Want In">
                  <button aria-label="Close Want In" className="help-close-button login-panel-overlay__close" type="button" onClick={closeInterestForm}>&times;</button>
                  {registrationError ? (
                    <>
                      <p role="alert">{registrationError}</p>
                      <button type="button" onClick={refreshRegistration}>Try again</button>
                    </>
                  ) : <p role="status">Checking registration availability…</p>}
                </div>
              ) : null}
              {showInterestForm && registration ? (
                <form ref={interestPanelRef} className="interest-panel login-panel-overlay stack compact" role="dialog" aria-modal="true" aria-label="Want In" onSubmit={handleInterestSubmit}>
                  <div className="interest-panel__header">
                    <h2 className="interest-panel__heading">
                      {registrationPaused ? "Register your interest" : "Join Hit n Score"}
                    </h2>
                    <button aria-label="Close Want In" className="help-close-button login-panel-overlay__close" type="button" onClick={closeInterestForm}>&times;</button>
                  </div>
                  {registrationPaused ? (
                    <p className="helper-text interest-copy registration-message">{registration.message}</p>
                  ) : <p className="helper-text interest-copy">
                    Welcome to HitnScore the racket sport scoring app. Create a free personal account to start scoring
                    matches. We also offer multi-user accounts for Rackets Sports Clubs. Register your interest for a
                    club account and we will be in touch.
                  </p>}
                  {!registrationPaused && requestedPersonalPlan === "personal_plus" ? (
                    <div className="notice">
                      Create your Personal account first, then choose Personal Plus from Subscription after signing in.
                    </div>
                  ) : null}

                  <fieldset className="registration-fields" disabled={interestLoading || (registrationPaused && Boolean(interestMessage))}>
                    <div className="field-grid">
                      <div className="field">
                        <label htmlFor="interest_first_name">{registrationPaused ? "First name" : "Name"}</label>
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

                    {!registrationPaused && interestUseType === "club" ? (
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
                      <label htmlFor="interest_captcha">{registrationPaused ? registration.challenge.prompt : interestCaptcha.prompt}</label>
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
                  </fieldset>

                  {interestError ? (
                    <div className="notice error">
                      {interestError}
                      {interestAccountExists ? (
                        <> <Link to="/help?mode=reset">Reset your password</Link>.</>
                      ) : null}
                    </div>
                  ) : null}
                  {interestMessage ? <div className="notice settings-success" role="status">{interestMessage}</div> : null}

                  <div className="button-row">
                    <button disabled={interestLoading || (registrationPaused && Boolean(interestMessage))} type="submit">
                      {interestLoading
                        ? "Sending..."
                        : registrationPaused ? "Register interest"
                        : (interestUseType === "personal" ? "Create Personal Account" : "Register Club Interest")}
                    </button>
                  </div>
                </form>
              ) : null}
              {showHelpOptions ? (
                <section className="login-panel-overlay login-help-options stack compact" role="dialog" aria-modal="true" aria-labelledby="login-help-options-title">
                  <div className="interest-panel__header">
                    <h2 id="login-help-options-title">Need Help?</h2>
                    <button aria-label="Close Need Help" className="help-close-button login-panel-overlay__close" type="button" onClick={() => setShowHelpOptions(false)}>&times;</button>
                  </div>
                  <p className="helper-text">Choose an option below.</p>
                  <div className="login-help-options__actions">
                    <button type="button" onClick={() => navigate("/ping")}>Ping Us</button>
                    <button className="secondary" type="button" onClick={() => navigate("/help")}>Guides</button>
                    <button className="secondary" type="button" onClick={() => navigate("/help?mode=reset")}>Password Reset</button>
                  </div>
                </section>
              ) : null}
            </div>

            <div className="login-help-link">
              <button type="button" onClick={openInterestForm}>Want In</button>
              <span aria-hidden="true">|</span>
              <button type="button" onClick={openHelpOptions}>Need Help</button>
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
    </main>
  );
}
