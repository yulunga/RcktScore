import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { useRootAdmin } from "../hooks/useRootAdmin";
import {
  getRootAdminPersonalAccounts,
  updateRootAdminPersonalAccount,
} from "../services/api";

const PLAN_FILTERS = [
  { value: "", label: "All" },
  { value: "personal_free", label: "Personal Free" },
  { value: "personal_plus", label: "Personal+ Paid" },
];

const PLAN_LABELS = {
  personal_free: "Personal Free",
  personal_plus: "Personal+ Paid",
};

const ACCOUNT_STATUS_LABELS = {
  pending_email_validation: "Waiting on Email Validation",
  live: "Live",
  disabled: "Disabled",
};

function formatDateTime(value) {
  if (!value) {
    return "Not set";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default function RootAdminPersonalAccountsPage() {
  const navigate = useNavigate();
  const { session } = useRootAdmin();
  const [planFilter, setPlanFilter] = useState("");
  const [personalAccounts, setPersonalAccounts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [savingId, setSavingId] = useState(null);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function loadPersonalAccounts() {
    setLoading(true);
    setError("");
    try {
      const response = await getRootAdminPersonalAccounts();
      setPersonalAccounts(response.personalAccounts || []);
    } catch (requestError) {
      setError(requestError.message || "Failed to load personal accounts.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadPersonalAccounts();
  }, []);

  const planCounts = useMemo(() => {
    return personalAccounts.reduce(
      (counts, account) => {
        const plan = account.personal_plan || "personal_free";
        counts[plan] = (counts[plan] || 0) + 1;
        counts.total += 1;
        return counts;
      },
      { total: 0, personal_free: 0, personal_plus: 0 },
    );
  }, [personalAccounts]);

  const visiblePersonalAccounts = useMemo(() => {
    if (!planFilter) {
      return personalAccounts;
    }

    return personalAccounts.filter(
      (account) => (account.personal_plan || "personal_free") === planFilter,
    );
  }, [personalAccounts, planFilter]);

  async function updatePlan(requestId, personalPlan) {
    setSavingId(requestId);
    setMessage("");
    setError("");
    try {
      await updateRootAdminPersonalAccount(requestId, {
        personal_plan: personalPlan,
        updated_by: session?.username || "Root Admin",
      });
      await loadPersonalAccounts();
      setMessage(`Personal account changed to ${PLAN_LABELS[personalPlan]}.`);
    } catch (requestError) {
      setError(requestError.message || "Failed to update personal account.");
    } finally {
      setSavingId(null);
    }
  }

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

      <section className="hero-card stack compact">
        <div className="root-admin-section-header">
          <div>
            <h1>Personal Accounts</h1>
            <p className="helper-text">
              Approved personal-use accounts that are not attached to a club workspace.
            </p>
          </div>
          <div className="button-row root-admin-actions">
            <button type="button" className="secondary" onClick={() => navigate("/rckscoreAdmin/dashboard")}>
              Back to Platform Control Centre
            </button>
          </div>
        </div>
      </section>

      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      <section className="panel stack">
        <div className="root-admin-section-header">
          <h2>Approved Personal Users</h2>
          <div className="root-admin-tab-row" aria-label="Filter personal accounts">
            {PLAN_FILTERS.map((filter) => (
              <button
                key={filter.value || "all"}
                className={`root-admin-tab ${planFilter === filter.value ? "active" : ""}`}
                type="button"
                onClick={() => setPlanFilter(filter.value)}
              >
                {filter.label}
              </button>
            ))}
          </div>
        </div>

        <div className="meta-grid root-admin-interest-summary">
          <div className="meta-item">
            <strong>Total In View</strong>
            <div>{planCounts.total}</div>
          </div>
          <div className="meta-item">
            <strong>Personal Free</strong>
            <div>{planCounts.personal_free}</div>
          </div>
          <div className="meta-item">
            <strong>Personal+ Paid</strong>
            <div>{planCounts.personal_plus}</div>
          </div>
        </div>

        {loading ? <div className="notice">Loading personal accounts...</div> : null}

        {!loading && visiblePersonalAccounts.length === 0 ? (
          <div className="dashboard-empty">No approved personal accounts match this filter.</div>
        ) : null}

        <div className="root-admin-interest-list">
          {visiblePersonalAccounts.map((account) => {
            const currentPlan = account.personal_plan || "personal_free";
            const currentStatus = account.account_status || "pending_email_validation";
            return (
              <article key={account.id} className="root-admin-interest-row">
                <div className="root-admin-interest-main">
                  <span className={`status-pill root-admin-plan-status root-admin-plan-status--${currentPlan}`}>
                    {PLAN_LABELS[currentPlan] || currentPlan}
                  </span>
                  <h3>{account.full_name || "Name not provided"}</h3>
                  <p>{account.email}</p>
                </div>

                <div className="root-admin-interest-details">
                  <span>Personal Org ID: {account.organization_id || account.id}</span>
                  <span>Status: {ACCOUNT_STATUS_LABELS[currentStatus] || currentStatus}</span>
                  <span>Email validated: {account.email_validated ? "Yes" : "No"}</span>
                  <span>Approval email sent: {formatDateTime(account.approval_email_sent_at)}</span>
                  <span>Approved: {formatDateTime(account.approved_at)}</span>
                  <span>Updated: {formatDateTime(account.updated_at)}</span>
                  <span>Approved by: {account.approved_by || "Not recorded"}</span>
                </div>

                <div className="button-row root-admin-interest-actions">
                  <button
                    type="button"
                    disabled={savingId === account.id || currentPlan === "personal_free"}
                    onClick={() => updatePlan(account.id, "personal_free")}
                  >
                    Set Personal Free
                  </button>
                  <button
                    type="button"
                    className="secondary"
                    disabled={savingId === account.id || currentPlan === "personal_plus"}
                    onClick={() => updatePlan(account.id, "personal_plus")}
                  >
                    Set Personal+ Paid
                  </button>
                </div>
              </article>
            );
          })}
        </div>
      </section>

      <AppFooter />
    </main>
  );
}
