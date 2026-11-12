import React, { useEffect, useState } from "react";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { getRegistrationStatus, updateRegistrationSettings } from "../services/api";

export default function RootAdminRegistrationPage() {
  const [savedSettings, setSavedSettings] = useState(null);
  const [draft, setDraft] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    const controller = new AbortController();
    getRegistrationStatus({ signal: controller.signal }).then((settings) => {
      setSavedSettings(settings);
      setDraft(settings);
    }).catch((requestError) => {
      if (!controller.signal.aborted) setError(requestError.message);
    });
    return () => controller.abort();
  }, []);

  async function save(event) {
    event.preventDefault();
    setSaving(true);
    setError("");
    setMessage("");
    try {
      const settings = await updateRegistrationSettings(draft);
      setSavedSettings(settings);
      setDraft(settings);
      setMessage("Registration settings saved.");
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar registrationEnabled={savedSettings?.enabled ?? null} />
      <section className="panel stack">
        <h1>Public Registration</h1>
        {error && <div className="notice error" role="alert">{error}</div>}
        {message && <div className="notice settings-success" role="status">{message}</div>}
        {draft ? (
          <form className="stack" onSubmit={save}>
            <label className="registration-switch">
              <input
                type="checkbox"
                role="switch"
                checked={draft.enabled}
                disabled={saving}
                onChange={(event) => setDraft({ ...draft, enabled: event.target.checked })}
              />
              Enable new users
            </label>
            <div className="field">
              <label htmlFor="registration-message">Message when registration is paused</label>
              <textarea
                id="registration-message"
                value={draft.message}
                maxLength={1000}
                rows={4}
                required
                disabled={saving}
                onChange={(event) => setDraft({ ...draft, message: event.target.value })}
              />
            </div>
            <div className="button-row">
              <button type="submit" disabled={saving || !draft.message.trim()}>
                {saving ? "Saving…" : "Save"}
              </button>
            </div>
          </form>
        ) : !error && <p role="status">Loading registration settings…</p>}
      </section>
    </main>
  );
}
