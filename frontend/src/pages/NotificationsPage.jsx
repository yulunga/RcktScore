import React, { useCallback, useEffect, useState } from "react";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import { getNotifications, markNotificationRead } from "../services/api";

function displayDate(value) {
  if (!value) return "";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "" : date.toLocaleString();
}

export default function NotificationsPage() {
  const { session } = useAuth();
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!session?.organization_id) return;
    setLoading(true);
    try {
      const response = await getNotifications(session.organization_id);
      setNotifications(response.notifications || []);
      setError("");
    } catch (requestError) {
      setError(requestError.message || "Unable to load notifications.");
    } finally {
      setLoading(false);
    }
  }, [session?.organization_id]);

  useEffect(() => { load(); }, [load]);

  async function markRead(notification) {
    if (notification.is_read) return;
    try {
      await markNotificationRead(notification.id, session.organization_id);
      setNotifications((current) => current.map((item) => (
        item.id === notification.id ? { ...item, is_read: true, read_at: new Date().toISOString() } : item
      )));
      window.dispatchEvent(new CustomEvent("rcktscore:notifications-changed"));
    } catch (requestError) {
      setError(requestError.message || "Unable to mark this notification as read.");
    }
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader title="Notifications" />
      {loading ? <div className="notice">Loading notifications...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}
      {!loading && !notifications.length ? <section className="panel dashboard-empty">You have no notifications.</section> : null}
      {notifications.length ? (
        <section className="panel stack">
          <div className="panel-heading"><h2>Your Notifications</h2></div>
          {notifications.map((notification) => (
            <article className={`notification-card${notification.is_read ? "" : " notification-card--unread"}`} key={notification.id}>
              <div className="notification-card__copy">
                <strong>{notification.title}</strong>
                <p>{notification.message}</p>
                <span className="helper-text">{displayDate(notification.created_at)}</span>
              </div>
              {notification.is_read ? (
                <span className="status-pill">Read</span>
              ) : (
                <button type="button" onClick={() => markRead(notification)}>Mark as read</button>
              )}
            </article>
          ))}
        </section>
      ) : null}
      <AppFooter />
    </main>
  );
}
