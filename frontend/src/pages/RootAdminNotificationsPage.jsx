import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { createRootAdminNotification, getRootAdminNotifications } from "../services/api";

const audiences = [
  ["all", "All users"],
  ["personal_free", "Personal Free"],
  ["personal_plus", "Personal Plus"],
  ["club_essentials", "Club Essentials"],
  ["club_pro", "Club Pro"],
];

export default function RootAdminNotificationsPage() {
  const navigate = useNavigate();
  const [items, setItems] = useState([]);
  const [form, setForm] = useState({ title: "", message: "", audience: "all" });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  async function load() {
    try {
      const response = await getRootAdminNotifications();
      setItems(response.notifications || []);
    } catch (requestError) {
      setError(requestError.message || "Unable to load notifications.");
    }
  }

  useEffect(() => { load(); }, []);

  async function submit(event) {
    event.preventDefault();
    setSaving(true); setError(""); setMessage("");
    try {
      await createRootAdminNotification(form);
      setForm({ title: "", message: "", audience: "all" });
      setMessage("Notification published.");
      await load();
    } catch (requestError) {
      setError(requestError.message || "Unable to publish notification.");
    } finally { setSaving(false); }
  }

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />
      <section className="hero-card compact panel-heading panel-heading--with-action">
        <div><h1>Notifications</h1><p>Publish in-app messages to everyone or a subscription group.</p></div>
        <button type="button" onClick={() => navigate("/rckscoreAdmin/dashboard")}>Back to Dashboard</button>
      </section>
      {error ? <div className="notice error">{error}</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      <section className="panel stack">
        <h2>New Notification</h2>
        <form className="stack" onSubmit={submit}>
          <div className="field"><label htmlFor="notification-title">Title</label><input id="notification-title" required maxLength="120" value={form.title} onChange={(event) => setForm({ ...form, title: event.target.value })} /></div>
          <div className="field"><label htmlFor="notification-audience">Recipients</label><select id="notification-audience" value={form.audience} onChange={(event) => setForm({ ...form, audience: event.target.value })}>{audiences.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>
          <div className="field"><label htmlFor="notification-message">Message</label><textarea id="notification-message" required rows="6" maxLength="4000" value={form.message} onChange={(event) => setForm({ ...form, message: event.target.value })} /></div>
          <div className="button-row"><button disabled={saving} type="submit">{saving ? "Publishing..." : "Publish Notification"}</button></div>
        </form>
      </section>
      <section className="panel stack"><h2>Published Notifications</h2>{items.length ? items.map((item) => <article className="dashboard-item" key={item.id}><div className="dashboard-item-head"><strong>{item.title}</strong><span className="status-pill">{audiences.find(([value]) => value === item.audience)?.[1] || item.audience}</span></div><p>{item.message}</p><span className="helper-text">Read by {item.read_count || 0} users</span></article>) : <div className="dashboard-empty">No notifications published.</div>}</section>
      <AppFooter />
    </main>
  );
}
