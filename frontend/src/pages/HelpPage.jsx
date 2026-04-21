import React, { useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import { confirmPasswordReset, requestPasswordReset } from "../services/api";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function HelpPage() {
  const [searchParams] = useSearchParams();
  const resetToken = searchParams.get("token") || "";
  const defaultMode = searchParams.get("mode") === "reset" || resetToken ? "reset" : "overview";
  const policyYear = new Date().getFullYear();
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
              <h2>Terms & Conditions</h2>
              <p>
                <strong>Last updated:</strong> {policyYear}
              </p>
              <h3>1. Introduction</h3>
              <p>
                Welcome to <strong>HitnScore</strong> ("the App"), operated by <strong>ucingo</strong> ("we",
                "our", "us").
              </p>
              <p>
                By accessing or using HitnScore, you agree to be bound by these Terms & Conditions. If you do
                not agree, you must not use the App.
              </p>
              <h3>2. Eligibility</h3>
              <p>To use HitnScore, you must:</p>
              <ul>
                <li>Be at least 18 years old, or</li>
                <li>Have permission from a parent or guardian</li>
              </ul>
              <p>By creating an account, you confirm that the information you provide is accurate and up to date.</p>
              <h3>3. Account Registration</h3>
              <p>To use certain features, you must create an account.</p>
              <p>You agree to:</p>
              <ul>
                <li>Provide accurate and complete information</li>
                <li>Keep your login details secure</li>
                <li>Not share your account with others</li>
              </ul>
              <p>You are responsible for all activity that occurs under your account.</p>
              <h3>4. Use of the App</h3>
              <p>HitnScore is designed to support scoring and management of racket sports matches.</p>
              <p>You agree to use the App only for lawful purposes and not to:</p>
              <ul>
                <li>Misuse or attempt to disrupt the App</li>
                <li>Access data belonging to other users without permission</li>
                <li>Upload or input false, misleading, or harmful data</li>
                <li>Attempt to reverse engineer or exploit the system</li>
              </ul>
              <h3>5. User Content</h3>
              <p>You may input and manage data such as:</p>
              <ul>
                <li>Player names</li>
                <li>Match scores</li>
                <li>Club and location details</li>
              </ul>
              <p>
                You retain ownership of your data, but you grant us a limited licence to store, process, and
                display this data solely to provide the service.
              </p>
              <h3>6. Availability of Service</h3>
              <p>We aim to provide a reliable service but do not guarantee that the App will:</p>
              <ul>
                <li>Be uninterrupted</li>
                <li>Be error-free</li>
                <li>Always be available</li>
              </ul>
              <p>We may suspend or modify the App at any time without notice.</p>
              <h3>7. Account Suspension and Termination</h3>
              <p>We reserve the right to suspend or terminate your account if:</p>
              <ul>
                <li>You breach these Terms</li>
                <li>You misuse the App</li>
                <li>Your account remains inactive for 24 months</li>
              </ul>
              <p>Upon termination, your data may be deleted in accordance with our Privacy Policy.</p>
              <h3>8. Data and Privacy</h3>
              <p>Your use of the App is also governed by our Privacy Policy.</p>
              <p>
                By using HitnScore, you acknowledge that your personal data will be processed in accordance with
                that policy.
              </p>
              <h3>9. Intellectual Property</h3>
              <p>All rights, title, and interest in the App, including its:</p>
              <ul>
                <li>Design</li>
                <li>Branding</li>
                <li>Software</li>
              </ul>
              <p>are owned by <strong>ucingo</strong>.</p>
              <p>You may not copy, distribute, or reproduce any part of the App without permission.</p>
              <h3>10. Limitation of Liability</h3>
              <p>To the fullest extent permitted by law:</p>
              <ul>
                <li>HitnScore is provided "as is" and "as available"</li>
                <li>We are not liable for loss of data</li>
                <li>We are not liable for loss of business or revenue</li>
                <li>We are not liable for errors in scoring or match data</li>
                <li>We are not liable for any indirect or consequential loss</li>
              </ul>
              <p>You use the App at your own risk.</p>
              <h3>11. Accuracy of Data</h3>
              <p>While the App facilitates scoring and match tracking:</p>
              <ul>
                <li>Users are responsible for ensuring accuracy of entered data</li>
                <li>We do not guarantee the correctness of match results or records</li>
              </ul>
              <h3>12. Third-Party Services</h3>
              <p>The App may rely on third-party infrastructure or services.</p>
              <p>We are not responsible for disruptions or issues caused by third-party providers.</p>
              <h3>13. Changes to the Terms</h3>
              <p>We may update these Terms & Conditions from time to time.</p>
              <p>
                Changes will be posted within the App with an updated "Last updated" year. Continued use of the
                App constitutes acceptance of the updated Terms.
              </p>
              <h3>14. Governing Law</h3>
              <p>These Terms & Conditions are governed by the laws of <strong>England and Wales</strong>.</p>
              <p>
                Any disputes shall be subject to the exclusive jurisdiction of the courts of England and Wales.
              </p>
              <h3>15. Contact Us</h3>
              <p>
                If you have any questions regarding these Terms & Conditions, please contact{" "}
                <a href="mailto:hello@hitnscore.com">hello@hitnscore.com</a>.
              </p>
              <h3>16. Public Scoreboards and Match Display</h3>
              <p>
                HitnScore may provide features that allow match data to be displayed publicly, including but not
                limited to:
              </p>
              <ul>
                <li>Live scoreboards</li>
                <li>Match results</li>
                <li>Player names associated with matches</li>
                <li>Club or location-based displays</li>
              </ul>
              <p>By using these features, you acknowledge and agree that:</p>
              <ul>
                <li>Match data you input may be visible to other users or the public</li>
                <li>Player names and match results may be displayed in real time or stored for later viewing</li>
                <li>This display is a core function of the App and forms part of the service provided</li>
              </ul>
              <p>You are responsible for ensuring that:</p>
              <ul>
                <li>You have the right to input and share the data entered into the App</li>
                <li>Any individuals whose data is entered are aware that their name may appear on scoreboards</li>
              </ul>
              <p>
                If you do not wish for your data to be displayed publicly, you should not use features that
                enable public sharing.
              </p>
              <p>We reserve the right to:</p>
              <ul>
                <li>Modify how scoreboards are displayed</li>
                <li>Limit or restrict visibility of certain data</li>
                <li>Remove content where required for legal or operational reasons</li>
              </ul>
              <h3>17. Subscription and Pricing</h3>
              <p>
                HitnScore operates on a subscription-based model. Access to certain features of the App may
                require a paid subscription.
              </p>
              <h4>Subscription Terms</h4>
              <ul>
                <li>Subscription plans, pricing, and features will be clearly presented within the App</li>
                <li>Subscriptions may be offered on a recurring basis, such as monthly or annual</li>
                <li>By subscribing, you agree to pay the applicable fees</li>
              </ul>
              <h4>Billing and Renewal</h4>
              <ul>
                <li>Subscriptions will automatically renew unless cancelled before the renewal date</li>
                <li>
                  You are responsible for managing your subscription and cancellation through your account
                  settings or the relevant platform provider
                </li>
              </ul>
              <h4>Changes to Pricing</h4>
              <ul>
                <li>We reserve the right to change subscription pricing or features at any time</li>
                <li>Any changes will be communicated in advance where reasonably possible</li>
              </ul>
              <h4>Cancellation</h4>
              <ul>
                <li>You may cancel your subscription at any time</li>
                <li>Access to paid features will continue until the end of the current billing period</li>
                <li>No refunds will be provided for partial subscription periods unless required by law</li>
              </ul>
              <h4>Free Features</h4>
              <ul>
                <li>Certain features of the App may be available without a subscription</li>
                <li>We reserve the right to modify or remove free features at any time</li>
              </ul>
              <h3>18. League and Club Administration Controls</h3>
              <p>
                HitnScore may provide features that allow designated users, such as club administrators, league
                organisers, or captains, to manage aspects of the App on behalf of others.
              </p>
              <p>These administrative capabilities may include:</p>
              <ul>
                <li>Creating and managing matches or competitions</li>
                <li>Assigning or editing player participation</li>
                <li>Updating match results or score data</li>
                <li>Managing club or team information</li>
              </ul>
              <p>
                By participating in leagues, clubs, or competitions within the App, you acknowledge and agree
                that:
              </p>
              <ul>
                <li>Authorised administrators may manage and update data relating to you and your participation</li>
                <li>Changes made by administrators may affect displayed scores, results, and records</li>
                <li>We are not responsible for disputes arising from administrator actions</li>
              </ul>
              <p>
                It is the responsibility of clubs and leagues to ensure that administrators act appropriately and
                with consent from participants.
              </p>
              <p>We reserve the right to:</p>
              <ul>
                <li>Limit or revoke administrative privileges</li>
                <li>Intervene in cases of misuse or dispute where necessary</li>
              </ul>
              <h3>19. Content Moderation and Acceptable Use</h3>
              <p>Users are responsible for all content they input into the App, including but not limited to:</p>
              <ul>
                <li>Player names</li>
                <li>Match data</li>
                <li>Club information</li>
              </ul>
              <p>You agree not to input or share content that:</p>
              <ul>
                <li>Is offensive, abusive, defamatory, or discriminatory</li>
                <li>Is false, misleading, or intended to deceive</li>
                <li>Violates any applicable laws or regulations</li>
              </ul>
              <p>We reserve the right to:</p>
              <ul>
                <li>Remove or modify content that breaches these Terms</li>
                <li>Suspend or terminate accounts involved in misuse</li>
                <li>Restrict access to features where abuse is detected</li>
              </ul>
              <p>
                We may use automated or manual methods to monitor and review content to maintain a safe and
                appropriate environment for all users.
              </p>
              <h3>20. Beta and Early Access</h3>
              <p>
                HitnScore may offer certain features or access to the App as part of a beta or early access
                programme.
              </p>
              <p>By participating in beta access, you acknowledge that:</p>
              <ul>
                <li>The App or certain features may be incomplete, unstable, or subject to change</li>
                <li>You may encounter bugs, errors, or interruptions in service</li>
                <li>Features may be added, modified, or removed without notice</li>
              </ul>
              <p>Beta access is provided for testing and feedback purposes only.</p>
              <p>We do not guarantee:</p>
              <ul>
                <li>Availability of beta features</li>
                <li>Continuity of data generated during beta phases</li>
                <li>That beta features will be included in the final product</li>
              </ul>
              <p>We reserve the right to:</p>
              <ul>
                <li>Limit, suspend, or revoke beta access at any time</li>
                <li>Use feedback provided to improve the App without obligation or compensation</li>
              </ul>
            </section>
          ) : null}

          {activeSection === "privacy" ? (
            <section className="help-copy stack compact">
              <h2>Privacy Policy</h2>
              <p>
                <strong>Last updated:</strong> {policyYear}
              </p>
              <h3>1. Introduction</h3>
              <p>
                Welcome to <strong>HitnScore</strong> ("we", "our", "us"), operated by <strong>ucingo</strong>.
                We are committed to protecting your personal data and respecting your privacy.
              </p>
              <p>
                This Privacy Policy explains how we collect, use, and safeguard your information when you use
                our application.
              </p>
              <h3>2. Who We Are</h3>
              <p>
                <strong>Data Controller:</strong> ucingo
              </p>
              <p>
                <strong>Privacy Contact Email:</strong>{" "}
                <a href="mailto:privacy@hitnscore.com">privacy@hitnscore.com</a>
              </p>
              <h3>3. What Data We Collect</h3>
              <p>When you register and use the app, we may collect the following personal data.</p>
              <h4>Account Information</h4>
              <ul>
                <li>First name</li>
                <li>Surname</li>
                <li>Email address</li>
              </ul>
              <h4>Profile Information</h4>
              <ul>
                <li>Club affiliation</li>
                <li>Country</li>
                <li>City or town</li>
              </ul>
              <h4>Usage Data</h4>
              <ul>
                <li>Match and scoring data you create or participate in</li>
                <li>Basic technical data, such as login activity</li>
              </ul>
              <p>We only collect data necessary to provide and improve the service.</p>
              <h3>4. How We Use Your Data</h3>
              <ul>
                <li>To create and manage your account</li>
                <li>To provide scoring and match functionality</li>
                <li>To identify users within the app</li>
                <li>To associate users with clubs and locations</li>
                <li>To maintain app performance and security</li>
              </ul>
              <h4>Email Communications</h4>
              <ul>
                <li>We may send emails related to account activity.</li>
                <li>We may send app updates or important service information.</li>
                <li>We may send optional marketing emails, but only if you have opted in.</li>
              </ul>
              <p>We do not share your data with third-party organisations for marketing purposes.</p>
              <h3>5. Legal Basis for Processing</h3>
              <ul>
                <li>Contractual necessity - to provide the app and its functionality</li>
                <li>Legitimate interests - to maintain and improve the service</li>
                <li>Consent - for marketing communications, where applicable</li>
              </ul>
              <h3>6. Data Sharing</h3>
              <p>We do not sell your personal data.</p>
              <p>
                We may share your data with trusted service providers strictly to operate the app. These
                providers process data on our behalf and are GDPR compliant.
              </p>
              <h3>7. Data Retention</h3>
              <p>We retain your personal data only as long as necessary to provide the service.</p>
              <ul>
                <li>Account data is stored while your account is active.</li>
                <li>Accounts that remain inactive for 24 months will be deleted, along with all associated data.</li>
                <li>Data will not be retained for more than 5 years, unless explicitly requested by the account holder.</li>
                <li>You may request deletion of your data at any time.</li>
              </ul>
              <p>We may retain limited data where required for legal or operational reasons.</p>
              <h3>8. Your Rights</h3>
              <p>Under GDPR, you have the right to:</p>
              <ul>
                <li>Access your personal data</li>
                <li>Correct inaccurate data</li>
                <li>Request deletion of your data</li>
                <li>Restrict or object to processing</li>
                <li>Request a copy of your data through data portability</li>
              </ul>
              <p>
                To exercise these rights, contact us at{" "}
                <a href="mailto:privacy@hitnscore.com">privacy@hitnscore.com</a>.
              </p>
              <h3>9. Data Security</h3>
              <p>We take appropriate technical and organisational measures to protect your data, including:</p>
              <ul>
                <li>Secure connections through HTTPS</li>
                <li>Encrypted password storage</li>
                <li>Access controls to prevent unauthorised access</li>
              </ul>
              <h3>10. Marketing Preferences</h3>
              <p>You will have the option to:</p>
              <ul>
                <li>Opt in to receive marketing emails</li>
                <li>Opt out at any time through account settings or unsubscribe links in emails</li>
              </ul>
              <h3>11. Children's Data</h3>
              <p>
                If the app is used by individuals under 18, we recommend use under supervision of a parent or
                guardian. Where required, parental consent may be necessary.
              </p>
              <h3>12. International Data Transfers</h3>
              <p>
                Your data may be processed in locations outside your country. We ensure appropriate safeguards
                are in place to protect your data.
              </p>
              <h3>13. Changes to This Policy</h3>
              <p>
                We may update this Privacy Policy from time to time. Any changes will be posted within the app
                with an updated "Last updated" year.
              </p>
              <h3>14. Contact Us</h3>
              <p>
                <strong>General Contact Email:</strong>{" "}
                <a href="mailto:hello@hitnscore.com">hello@hitnscore.com</a>
              </p>
              <p>
                <strong>Privacy Contact Email:</strong>{" "}
                <a href="mailto:privacy@hitnscore.com">privacy@hitnscore.com</a>
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
