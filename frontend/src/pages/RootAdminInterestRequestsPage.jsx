import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { useRootAdmin } from "../hooks/useRootAdmin";
import {
  getRootAdminInterestRequests,
  updateRootAdminInterestRequestStatus,
} from "../services/api";

const STATUS_FILTERS = [
  { value: "", label: "All" },
  { value: "pending", label: "Pending" },
  { value: "approved", label: "Approved" },
  { value: "denied", label: "Denied" },
];

const STATUS_LABELS = {
  pending: "Pending",
  approved: "Approved",
  denied: "Denied",
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

function displayUseType(value) {
  return value === "club" ? "Club use" : "Personal use";
}

export default function RootAdminInterestRequestsPage() {
  const navigate = useNavigate();
  const { session } = useRootAdmin();
  const [statusFilter, setStatusFilter] = useState("pending");
  const [interestRequests, setInterestRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [savingId, setSavingId] = useState(null);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function loadInterestRequests() {
    setLoading(true);
    setError("");
    try {
      const response = await getRootAdminInterestRequests();
      setInterestRequests(response.interestRequests || []);
    } catch (requestError) {
      setError(requestError.message || "Failed to load interest requests.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadInterestRequests();
  }, []);

  const statusCounts = useMemo(() => {
    return interestRequests.reduce(
      (counts, request) => {
        const status = request.approval_status || "pending";
        counts[status] = (counts[status] || 0) + 1;
        counts.total += 1;
        return counts;
      },
      { total: 0, pending: 0, approved: 0, denied: 0 },
    );
  }, [interestRequests]);

  const visibleInterestRequests = useMemo(() => {
    if (!statusFilter) {
      return interestRequests;
    }

    return interestRequests.filter(
      (request) => (request.approval_status || "pending") === statusFilter,
    );
  }, [interestRequests, statusFilter]);

  async function updateStatus(requestId, approvalStatus) {
    setSavingId(requestId);
    setMessage("");
    setError("");
    try {
      await updateRootAdminInterestRequestStatus(requestId, {
        approval_status: approvalStatus,
        updated_by: session?.username || "Root Admin",
      });
      await loadInterestRequests();
      setMessage(`Interest request marked as ${STATUS_LABELS[approvalStatus].toLowerCase()}.`);
    } catch (requestError) {
      setError(requestError.message || "Failed to update interest request.");
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
            <h1>Interested Users</h1>
            <p className="helper-text">
              Review early access requests and keep their status clear for follow-up.
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
          <h2>Interest Queue</h2>
          <div className="root-admin-tab-row" aria-label="Filter interest requests">
            {STATUS_FILTERS.map((filter) => (
              <button
                key={filter.value || "all"}
                className={`root-admin-tab ${statusFilter === filter.value ? "active" : ""}`}
                type="button"
                onClick={() => setStatusFilter(filter.value)}
              >
                {filter.label}
              </button>
            ))}
          </div>
        </div>

        <div className="meta-grid root-admin-interest-summary">
          <div className="meta-item">
            <strong>Total In View</strong>
            <div>{statusCounts.total}</div>
          </div>
          <div className="meta-item">
            <strong>Pending</strong>
            <div>{statusCounts.pending}</div>
          </div>
          <div className="meta-item">
            <strong>Approved</strong>
            <div>{statusCounts.approved}</div>
          </div>
          <div className="meta-item">
            <strong>Denied</strong>
            <div>{statusCounts.denied}</div>
          </div>
        </div>

        {loading ? <div className="notice">Loading interested users...</div> : null}

        {!loading && visibleInterestRequests.length === 0 ? (
          <div className="dashboard-empty">No interest requests match this filter.</div>
        ) : null}

        <div className="root-admin-interest-list">
          {visibleInterestRequests.map((request) => {
            const currentStatus = request.approval_status || "pending";
            return (
              <article key={request.id} className="root-admin-interest-row">
                <div className="root-admin-interest-main">
                  <span className={`status-pill root-admin-interest-status root-admin-interest-status--${currentStatus}`}>
                    {STATUS_LABELS[currentStatus] || currentStatus}
                  </span>
                  <h3>{request.full_name || "Name not provided"}</h3>
                  <p>{request.email}</p>
                </div>

                <div className="root-admin-interest-details">
                  <span>{displayUseType(request.use_type)}</span>
                  <span>{request.club_name || "No club supplied"}</span>
                  <span>Email validated: {request.email_validated ? "Yes" : "No"}</span>
                  <span>Registered: {formatDateTime(request.created_at)}</span>
                  <span>Updated: {formatDateTime(request.updated_at)}</span>
                </div>

                <div className="button-row root-admin-interest-actions">
                  <button
                    type="button"
                    disabled={savingId === request.id || currentStatus === "approved"}
                    onClick={() => updateStatus(request.id, "approved")}
                  >
                    Approve & Email
                  </button>
                  <button
                    type="button"
                    className="secondary"
                    disabled={savingId === request.id || currentStatus === "pending"}
                    onClick={() => updateStatus(request.id, "pending")}
                  >
                    Mark Pending
                  </button>
                  <button
                    type="button"
                    className="danger"
                    disabled={savingId === request.id || currentStatus === "denied"}
                    onClick={() => updateStatus(request.id, "denied")}
                  >
                    Deny
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
