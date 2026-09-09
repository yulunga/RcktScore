import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";

import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { getRootAdminSubscriptions } from "../services/api";


function formatDate(value) {
  if (!value) return "—";
  return new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}


export default function RootAdminSubscriptionsPage() {
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [status, setStatus] = useState("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    getRootAdminSubscriptions()
      .then((response) => setData(response.rootAdminSubscriptions))
      .catch((requestError) => setError(requestError.message || "Failed to load subscriptions."))
      .finally(() => setLoading(false));
  }, []);

  const subscriptions = useMemo(() => {
    const rows = data?.subscriptions || [];
    return status === "all" ? rows : rows.filter((row) => row.status === status);
  }, [data, status]);

  const summary = data?.summary || {};
  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />
      <section className="hero-card stack compact">
        <div className="root-admin-section-header">
          <div><h1>Apple Subscriptions</h1><p>Current state, notification processing and append-only entitlement history.</p></div>
          <button type="button" className="secondary" onClick={() => navigate("/rckscoreAdmin/dashboard")}>Back</button>
        </div>
        <div className="meta-grid">
          {[
            ["Total", "total"], ["Active", "active"], ["Grace", "grace_period"],
            ["Billing retry", "billing_retry"], ["Expired", "expired"], ["Revoked", "revoked"],
          ].map(([label, key]) => <button key={key} type="button" className={`meta-item root-admin-filter-card ${status === key ? "active" : ""}`} onClick={() => setStatus(key === "total" ? "all" : key)}><strong>{label}</strong><div>{summary[key] || 0}</div></button>)}
        </div>
      </section>

      {loading ? <div className="notice">Loading subscription activity…</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      <section className="panel stack">
        <h2>Current subscriptions</h2>
        <div className="subscription-admin-list">
          {subscriptions.length === 0 ? <div className="dashboard-empty">No subscriptions match this status.</div> : subscriptions.map((row) => (
            <article className="subscription-admin-row" key={row.id}>
              <div><strong>{row.organization_name || `Account ${row.organization_id}`}</strong><span>{row.username}</span></div>
              <div><strong>{row.status.replaceAll("_", " ")}</strong><span>{row.plan}</span></div>
              <div><strong>{row.auto_renew_enabled === false ? "Ends at expiry" : row.auto_renew_enabled === true ? "Auto-renewing" : "Renewal status pending"}</strong><span>{row.product_id}</span></div>
              <div><strong>Expires</strong><span>{formatDate(row.expires_at)}</span></div>
              <div><strong>Reconciled</strong><span>{formatDate(row.last_reconciled_at)}</span></div>
              {row.reconciliation_error ? <div className="notice error">{row.reconciliation_error}</div> : null}
            </article>
          ))}
        </div>
      </section>

      <section className="panel stack">
        <h2>Entitlement audit</h2>
        <div className="subscription-admin-list">
          {(data?.audit || []).map((row) => (
            <article className="subscription-admin-row compact" key={row.id}>
              <div><strong>{row.organization_name || `Account ${row.organization_id}`}</strong><span>{row.account_username}</span></div>
              <div><strong>{row.previous_plan} → {row.new_plan}</strong><span>{row.source}: {row.reason}</span></div>
              <div><strong>{formatDate(row.effective_at)}</strong><span>{row.transaction_id || "No transaction ID"}</span></div>
            </article>
          ))}
        </div>
      </section>

      <section className="panel stack">
        <h2>Server notification activity</h2>
        <div className="subscription-admin-list">
          {(data?.events || []).map((row) => (
            <article className="subscription-admin-row compact" key={row.id}>
              <div><strong>{row.notification_type}{row.subtype ? ` · ${row.subtype}` : ""}</strong><span>{row.environment} · {row.notification_uuid}</span></div>
              <div><strong>{row.status_before || "—"} → {row.status_after || "—"}</strong><span>Attempts: {row.attempts}</span></div>
              <div><strong>{formatDate(row.verified_at)}</strong><span>{row.processing_error || "Processed successfully"}</span></div>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
