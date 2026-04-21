import React, { useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import { confirmPasswordReset, requestPasswordReset } from "../services/api";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function HelpPage() {
  const [searchParams] = useSearchParams();
  const resetToken = searchParams.get("token") || "";
  const defaultMode = searchParams.get("mode") === "reset" || resetToken ? "reset" : "overview";
  const [activeSection, setActiveSection] = useState(defaultMode);
  const [resetEmail, setResetEmail] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const resetIntro = useMemo(() => {
    if (resetToken) {
      return "Choose a new password for your HitnScore account.";
    }

    return "Enter the email address used for your account. If it is registered, we will send a reset link.";
  }, [resetToken]);

  async function handleResetRequest(event) {
    event.preventDefault();
    const email = resetEmail.trim().toLowerCase();

    if (!EMAIL_PATTERN.test(email)) {
      setError("Enter a valid email address.");
      setMessage("");
      return;
    }

    setLoading(true);
    setError("");
    setMessage("");

    try {
      await requestPasswordReset({ email });
      setMessage("If that email is registered, a password reset link has been sent.");
      setResetEmail("");
    } catch (requestError) {
      setError(requestError.message || "Unable to request password reset right now.");
    } finally {
      setLoading(false);
    }
  }

  async function handleResetConfirm(event) {
    event.preventDefault();

    if (newPassword.length < 8) {
      setError("Password must be at least 8 characters.");
      setMessage("");
      return;
    }

    if (newPassword !== confirmPassword) {
      setError("Passwords do not match.");
      setMessage("");
      return;
    }

    setLoading(true);
    setError("");
    setMessage("");

    try {
      await confirmPasswordReset({
        token: resetToken,
        password: newPassword,
      });
      setMessage("Password updated. You can now sign in with your new password.");
      setNewPassword("");
      setConfirmPassword("");
    } catch (requestError) {
      setError(requestError.message || "Unable to reset password right now.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="page-shell login-shell help-shell">
      <div className="login-shell__content">
        <section className="login-panel help-panel stack">
          <div className="login-panel__top">
            <div className="login-branding">
              <img
                className="login-branding__logo help-branding__logo"
                src="/branding/logo/test_logo_2.png"
                alt="Hit n Score"
              />
              <h1 className="login-title login-title--wordmark" aria-label="HitnScore Help">
                <span className="login-title__hit">Hit</span>
                <span className="login-title__n">n</span>
                <span className="login-title__score">Score</span>
              </h1>
            </div>
          </div>

          <div className="help-nav" aria-label="Help sections">
            <button
              className={activeSection === "reset" ? "active" : ""}
              type="button"
              onClick={() => setActiveSection("reset")}
            >
              Reset Password
            </button>
            <button
              className={activeSection === "terms" ? "active" : ""}
              type="button"
              onClick={() => setActiveSection("terms")}
            >
              Terms
            </button>
            <button
              className={activeSection === "privacy" ? "active" : ""}
              type="button"
              onClick={() => setActiveSection("privacy")}
            >
              Privacy
            </button>
          </div>

          {activeSection === "reset" ? (
            <section className="stack compact">
              <div className="panel-heading">
                <h2>Password Reset</h2>
                <p className="helper-text">{resetIntro}</p>
              </div>

              {resetToken ? (
                <form className="stack compact" onSubmit={handleResetConfirm}>
                  <div className="field">
                    <label htmlFor="new_password">New password</label>
                    <input
                      id="new_password"
                      minLength="8"
                      type="password"
                      value={newPassword}
                      onChange={(event) => setNewPassword(event.target.value)}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="confirm_password">Confirm password</label>
                    <input
                      id="confirm_password"
                      minLength="8"
                      type="password"
                      value={confirmPassword}
                      onChange={(event) => setConfirmPassword(event.target.value)}
                    />
                  </div>
                  {error ? <div className="notice error">{error}</div> : null}
                  {message ? <div className="notice settings-success">{message}</div> : null}
                  <div className="button-row">
                    <button disabled={loading} type="submit">
                      {loading ? "Saving..." : "Set New Password"}
                    </button>
                  </div>
                </form>
              ) : (
                <form className="stack compact" onSubmit={handleResetRequest}>
                  <div className="field">
                    <label htmlFor="reset_email">Account email</label>
                    <input
                      id="reset_email"
                      placeholder="you@club.com"
                      type="email"
                      value={resetEmail}
                      onChange={(event) => setResetEmail(event.target.value)}
                    />
                  </div>
                  {error ? <div className="notice error">{error}</div> : null}
                  {message ? <div className="notice settings-success">{message}</div> : null}
                  <div className="button-row">
                    <button disabled={loading} type="submit">
                      {loading ? "Sending..." : "Send Reset Email"}
                    </button>
                  </div>
                </form>
              )}
            </section>
          ) : null}

          {activeSection === "terms" ? (
            <section className="help-copy stack compact">
              <h2>Terms and Conditions</h2>
              <p>
                HitnScore is currently provided as a beta scoring platform for clubs and approved users.
                Users should only enter match and organisation information they are authorised to manage.
              </p>
              <p>
                During beta, features may change as we improve scoring, scheduling, display, and club
                administration tools. Clubs remain responsible for checking match information before relying on
                it for official records.
              </p>
              <p>
                We may suspend access where accounts are misused, data is entered maliciously, or system
                security is put at risk.
              </p>
            </section>
          ) : null}

          {activeSection === "privacy" ? (
            <section className="help-copy stack compact">
              <h2>Privacy Statement</h2>
              <p>
                HitnScore stores account details such as email address, organisation membership, role, and match
                activity so clubs can run scoring sessions and manage access.
              </p>
              <p>
                We use email addresses for sign-in, invitations, password resets, and important service messages.
                We do not intend to sell user data or use club scoring data for unrelated marketing.
              </p>
              <p>
                This is starter privacy wording for beta use and will be expanded before wider release.
              </p>
            </section>
          ) : null}

          <div className="help-login-link">
            <Link to="/login">Back to Sign In</Link>
          </div>
        </section>
      </div>

      <div className="login-footer-wrap">
        <AppFooter />
      </div>
    </main>
  );
}
