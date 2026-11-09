import React, { useEffect, useState } from "react";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { getRootAdminOnlineUsers } from "../services/api";

const METRICS = [
  ["online_now", "Online now", "Unique users seen in the last 5 minutes."],
  ["active_today", "Active today", "Unique users seen in the last 24 hours."],
  ["signed_in", "Signed in", "Sessions that have neither ended nor expired. Default lifetime is 30 days."],
  ["sign_ins_today", "Sign-ins today", "New sessions since midnight UK time. Repeat sign-ins count separately."],
];

const PLATFORMS = [
  ["web", "Web client"],
  ["ios", "iOS"],
  ["android", "Android"],
  ["unknown", "Unattributed"],
];

export default function RootAdminOnlineUsersPage() {
  const [activity, setActivity] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    let timer;
    async function refresh() {
      try {
        const response = await getRootAdminOnlineUsers();
        if (!cancelled) {
          setActivity(response.activity);
          setError("");
        }
      } catch (failure) {
        if (!cancelled) setError(failure.message);
      } finally {
        if (!cancelled) timer = window.setTimeout(refresh, 30000);
      }
    }
    refresh();
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, []);

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />
      <section className="panel stack">
        <h1>Online Users</h1>
        {error ? <div className="notice error" role="alert">{error}</div> : null}
        {!activity && !error ? <div className="notice">Loading user activity…</div> : null}
        {activity ? (
          <>
            <div className="meta-grid">
              {METRICS.map(([key, label, description]) => (
                <div className="meta-item" key={key}>
                  <strong>{label}</strong>
                  <div>{activity.total[key]}</div>
                  <span className="helper-text">{description}</span>
                </div>
              ))}
            </div>
            <h2>By client</h2>
            <div style={{ overflowX: "auto" }}>
              <table className="root-admin-activity-table">
                <thead>
                  <tr>
                    <th scope="col">Client</th>
                    {METRICS.map(([key, label]) => <th scope="col" key={key}>{label}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {PLATFORMS.map(([platform, label]) => (
                    <tr key={platform}>
                      <th scope="row">{label}</th>
                      {METRICS.map(([key]) => <td key={key}>{activity[platform]?.[key] ?? 0}</td>)}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="helper-text">Activity is based on authenticated requests. A person can appear under multiple clients, while the overall activity totals count them once. Older mobile sessions may appear as unattributed.</p>
          </>
        ) : null}
      </section>
      <AppFooter />
    </main>
  );
}
