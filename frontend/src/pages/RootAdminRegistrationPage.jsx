import React, { useEffect, useState } from "react";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { getRootAdminServices, updateRootAdminServices } from "../services/api";

export default function RootAdminRegistrationPage() {
  const [savedSettings, setSavedSettings] = useState(null);
  const [draft, setDraft] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    const controller = new AbortController();
    getRootAdminServices({ signal: controller.signal }).then((settings) => {
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
      const settings = await updateRootAdminServices(draft);
      setSavedSettings(settings);
      setDraft(settings);
      setMessage("Service settings saved.");
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar serviceStatus={savedSettings?.status} />
      <section className="panel stack">
        <h1>Services</h1>
        <p className="helper-text">Control customer-facing services across HitnScore clients. The traffic light is green when all services are enabled, orange when one is disabled and red when all are disabled.</p>
        {error && <div className="notice error" role="alert">{error}</div>}
        {message && <div className="notice settings-success" role="status">{message}</div>}
        {draft ? (
          <form className="stack services-settings" onSubmit={save}>
            <section className="settings-collapsible-card stack compact">
              <div className="panel-heading"><h2>Public Registration</h2><p className="helper-text">Allow new users to create accounts.</p></div>
              <label className="registration-switch">
              <input
                type="checkbox"
                role="switch"
                checked={draft.services.public_registration.enabled}
                disabled={saving}
                onChange={(event) => setDraft({ ...draft, services: { ...draft.services, public_registration: { ...draft.services.public_registration, enabled: event.target.checked } } })}
              />
              Enable new users
              </label>
              <div className="field">
              <label htmlFor="registration-message">Message when registration is paused</label>
              <textarea
                id="registration-message"
                value={draft.services.public_registration.message}
                maxLength={1000}
                rows={4}
                required
                disabled={saving}
                onChange={(event) => setDraft({ ...draft, services: { ...draft.services, public_registration: { ...draft.services.public_registration, message: event.target.value } } })}
              />
              </div>
            </section>
            <section className="settings-collapsible-card stack compact">
              <div className="panel-heading"><h2>Subscriptions</h2><p className="helper-text">Grey out subscription menus on web, iOS and Android while retaining access for listed test identities.</p></div>
              <label className="registration-switch">
                <input
                  type="checkbox"
                  role="switch"
                  checked={draft.services.subscriptions.enabled}
                  disabled={saving}
                  onChange={(event) => setDraft({ ...draft, services: { ...draft.services, subscriptions: { ...draft.services.subscriptions, enabled: event.target.checked } } })}
                />
                Enable subscription menus
              </label>
              <div className="field">
                <label htmlFor="subscription-exceptions">Subscription access exceptions</label>
                <textarea
                  id="subscription-exceptions"
                  rows={6}
                  disabled={saving}
                  placeholder="tester@example.com\nsecond.tester@example.com"
                  value={(draft.services.subscriptions.exceptions || []).join("\n")}
                  onChange={(event) => setDraft({ ...draft, services: { ...draft.services, subscriptions: { ...draft.services.subscriptions, exceptions: event.target.value.split(/\r?\n/) } } })}
                />
                <small>Enter one registered email address per line. Exceptions apply only while subscriptions are disabled.</small>
              </div>
            </section>
            <div className="button-row">
              <button type="submit" disabled={saving || !draft.services.public_registration.message.trim()}>
                {saving ? "Saving…" : "Save Services"}
              </button>
            </div>
          </form>
        ) : !error && <p role="status">Loading registration settings…</p>}
      </section>
    </main>
  );
}
