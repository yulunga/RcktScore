import React, { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import packageJson from "../../package.json";
import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import { submitFeedback } from "../services/api";

const BUILD_ID = String(import.meta.env.VITE_BUILD_ID || "local").replace(/^0+(?=\d)/, "");
const APP_VERSION = `v${packageJson.version}`;
const FEEDBACK_CATEGORIES = [
  "Bug / Something not working",
  "Feature Request",
  "General Feedback",
  "UI / Design Suggestion",
  "Performance Issue",
  "Other",
];

export default function PingUsPage() {
  const navigate = useNavigate();
  const { session } = useAuth();
  const fallbackName = useMemo(() => {
    if (session?.full_name) {
      return session.full_name;
    }

    const combined = [session?.first_name, session?.surname].filter(Boolean).join(" ").trim();
    return combined || session?.username || "";
  }, [session?.first_name, session?.full_name, session?.surname, session?.username]);

  const [form, setForm] = useState({
    name: fallbackName,
    email: session?.email || "",
    category: FEEDBACK_CATEGORIES[0],
    message: "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);
    setNotice("");
    setError("");

    try {
      await submitFeedback({
        ...form,
        username: session?.username || "",
        organization_name: session?.organization_name || "",
        version: APP_VERSION,
        build: BUILD_ID,
        page_url: window.location.href,
        user_agent: window.navigator.userAgent,
      });
      setNotice("Thanks. Your message has been sent.");
      setForm((current) => ({ ...current, message: "", category: FEEDBACK_CATEGORIES[0] }));
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
                type="email"
                value={form.email}
                onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))}
              />
            </label>
          </div>

          <label>
            Subject
            <select
              value={form.category}
              onChange={(event) => setForm((current) => ({ ...current, category: event.target.value }))}
            >
              {FEEDBACK_CATEGORIES.map((category) => (
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
