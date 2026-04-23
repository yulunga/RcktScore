import React, { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import packageJson from "../../package.json";
import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import { getOrganizationSettings, submitFeedback } from "../services/api";

const BUILD_ID = String(import.meta.env.VITE_BUILD_ID || "local").replace(/^0+(?=\d)/, "");
const APP_VERSION = `v${packageJson.version}`;
const CLUB_SUBSCRIPTION_CATEGORY = "Club Subscription";
const FEEDBACK_CATEGORIES = [
  "Feedback",
  "Club Account",
  "Feature Request",
  "UI/Design",
  "Performance",
  "Bug",
  "Other",
];

export default function PingUsPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { session } = useAuth();
  const subjectParam = searchParams.get("subject") || "";
  const requestedCategory = subjectParam.toLowerCase().replace(/\s+/g, "-") === "club-subscription"
    ? CLUB_SUBSCRIPTION_CATEGORY
    : "";
  const feedbackCategories = requestedCategory
    ? [requestedCategory, ...FEEDBACK_CATEGORIES]
    : FEEDBACK_CATEGORIES;
  const isLoggedIn = Boolean(session?.username);
  const [profileName, setProfileName] = useState("");
  const [profileEmail, setProfileEmail] = useState("");
  const fallbackName = useMemo(() => {
    if (session?.full_name) {
      return session.full_name;
    }

    const combined = [session?.first_name, session?.surname].filter(Boolean).join(" ").trim();
    return combined || session?.username || "";
  }, [session?.first_name, session?.full_name, session?.surname, session?.username]);
  const autoFilledName = profileName || fallbackName;
  const lockedEmail = profileEmail || session?.email || session?.username || "";
  const autoFilledNameRef = useRef(autoFilledName);

  const [form, setForm] = useState({
    name: autoFilledName,
    email: session?.email || "",
    category: requestedCategory || FEEDBACK_CATEGORIES[0],
    message: "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    async function loadCurrentUserProfile() {
      if (!session?.organization_id || !session?.username) {
        setProfileName("");
        setProfileEmail(session?.email || "");
        return;
      }

      try {
        const response = await getOrganizationSettings(session.organization_id);
        const matchedUser = (response?.organizationSettings?.users || []).find(
          (user) => user.username?.toLowerCase() === session.username?.toLowerCase(),
        );
        const combinedName = [matchedUser?.first_name, matchedUser?.surname].filter(Boolean).join(" ").trim();
        setProfileName(combinedName || "");
        setProfileEmail(matchedUser?.username || session?.email || session?.username || "");
      } catch {
        setProfileName("");
        setProfileEmail(session?.email || session?.username || "");
      }
    }

    loadCurrentUserProfile();
  }, [session?.email, session?.organization_id, session?.username]);

  useEffect(() => {
    setForm((current) => {
      if (current.name && current.name !== autoFilledNameRef.current) {
        autoFilledNameRef.current = autoFilledName;
        return current;
      }

      autoFilledNameRef.current = autoFilledName;
      return {
        ...current,
        name: autoFilledName,
      };
    });
  }, [autoFilledName]);

  useEffect(() => {
    if (!isLoggedIn) {
      return;
    }

    setForm((current) => ({
      ...current,
      email: lockedEmail,
    }));
  }, [isLoggedIn, lockedEmail]);

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);
    setNotice("");
    setError("");

    try {
      await submitFeedback({
        ...form,
        email: isLoggedIn ? lockedEmail : form.email,
        username: session?.username || "",
        organization_name: session?.organization_name || "",
        version: APP_VERSION,
        build: BUILD_ID,
        page_url: window.location.href,
        user_agent: window.navigator.userAgent,
      });
      setNotice("Thanks. Your message has been sent.");
      setForm((current) => ({ ...current, message: "", category: feedbackCategories[0] }));
    } catch (requestError) {
      setError(requestError.message || "Unable to send your message.");
    } finally {
      setSubmitting(false);
    }
  }

  function goBack() {
    if (window.history.length > 1) {
      navigate(-1);
      return;
    }

    navigate("/dashboard");
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        title={session?.organization_name || "RcktScore"}
        subtitle="Send feedback, report issues, or request improvements."
      />

      <section className="panel stack ping-page-panel">
        <button className="page-close-button" type="button" aria-label="Back" onClick={goBack}>
          ×
        </button>
        <div className="ping-page-header">
          <h2>Ping Us</h2>
          <p className="helper-text">
            Tell us what is working, what is broken, or what you want to improve.
          </p>
        </div>

        {notice ? <div className="notice">{notice}</div> : null}
        {error ? <div className="notice error">{error}</div> : null}

        <form className="stack" onSubmit={handleSubmit}>
          <div className="field-grid">
            <label>
              Your name
              <input
                type="text"
                value={form.name}
                onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
              />
            </label>

            <label>
              Your email
              <input
                disabled={isLoggedIn}
                readOnly={isLoggedIn}
                type="email"
                value={form.email}
                onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))}
              />
              {isLoggedIn ? <span className="helper-text">Using your account email.</span> : null}
            </label>
          </div>

          <label>
            Subject
            <select
              value={form.category}
              onChange={(event) => setForm((current) => ({ ...current, category: event.target.value }))}
            >
              {feedbackCategories.map((category) => (
                <option key={category} value={category}>
                  {category}
                </option>
              ))}
            </select>
          </label>

          <label>
            Tell us more
            <textarea
              className="ping-textarea"
              value={form.message}
              onChange={(event) => setForm((current) => ({ ...current, message: event.target.value }))}
              rows={6}
            />
          </label>

          <div className="ping-submit-row">
            <button type="submit" disabled={submitting}>
              {submitting ? "Sending..." : "Send"}
            </button>
          </div>
        </form>

        <div className="ping-back-link">
          <button type="button" onClick={goBack}>
            &lt; Back
          </button>
        </div>
      </section>

      <AppFooter />
    </main>
  );
}
