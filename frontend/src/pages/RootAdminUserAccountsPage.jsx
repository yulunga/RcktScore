import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { getRootAdminUsers } from "../services/api";

const ACCOUNT_FILTERS = [
  { value: "", label: "All Users", countKey: "total_user_count" },
  { value: "personal_free", label: "Personal Free", countKey: "personal_free_count" },
  { value: "personal_plus", label: "Personal Plus", countKey: "personal_plus_count" },
  { value: "club", label: "Club Accounts", countKey: "club_user_count" },
  { value: "delete_pending", label: "Delete Pending", countKey: "delete_pending_count" },
  { value: "unverified", label: "Unverified Users", countKey: "unverified_user_count" },
  { value: "inactive_12_months", label: "No Login 12+ Months", countKey: "inactive_12_month_count" },
  { value: "inactive_24_months", label: "No Login 24+ Months", countKey: "inactive_24_month_count" },
];

function userRowClass(user) {
  if (user.account_status === "delete_pending") return "root-admin-user-row--delete-pending";
  if (user.email_verified === false) return "root-admin-user-row--unverified";
  if (user.account_types?.includes("personal_plus")) return "root-admin-user-row--personal-plus";
  if (user.account_types?.includes("personal_free")) return "root-admin-user-row--personal-free";
  return "";
}

function formatLastLogin(value) {
  if (!value) return "Never logged in";
  return new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

export default function RootAdminUserAccountsPage() {
  const navigate = useNavigate();
  const [accountFilter, setAccountFilter] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [directory, setDirectory] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    const timeoutId = window.setTimeout(async () => {
      setLoading(true);
      setError("");
      try {
        const response = await getRootAdminUsers({
          accountType: accountFilter,
          query: searchTerm.trim(),
        });
        if (!cancelled) setDirectory(response.userDirectory || null);
      } catch (requestError) {
        if (!cancelled) setError(requestError.message || "Failed to load user accounts.");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }, searchTerm.trim() ? 220 : 0);

    return () => {
      cancelled = true;
      window.clearTimeout(timeoutId);
    };
  }, [accountFilter, searchTerm]);

  const summary = directory?.summary || {};
  const users = directory?.users || [];

  function selectFilter(nextFilter) {
    setAccountFilter((current) => (current === nextFilter ? "" : nextFilter));
  }

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

      <section className="hero-card stack compact">
        <div className="root-admin-section-header">
          <h1>Users</h1>
          <div className="button-row root-admin-actions">
            <button type="button" className="secondary" onClick={() => navigate("/rckscoreAdmin/dashboard")}>
              Back to Control Panel
            </button>
          </div>
        </div>
      </section>

      {error ? <div className="notice error">{error}</div> : null}

      <section className="panel stack">
        <div className="meta-grid root-admin-interest-summary root-admin-user-summary">
          {ACCOUNT_FILTERS.map((filter) => (
            <button
              key={filter.value}
              className={`meta-item root-admin-filter-card${filter.value === "unverified" ? " root-admin-filter-card--unverified" : ""}${accountFilter === filter.value ? " active" : ""}`}
              type="button"
              aria-pressed={accountFilter === filter.value}
              onClick={() => selectFilter(filter.value)}
            >
              <strong>{filter.label}</strong>
              <div>{summary[filter.countKey] ?? 0}</div>
              <span>{accountFilter === filter.value ? "Selected" : "Select to filter"}</span>
            </button>
          ))}
        </div>

        <div className="root-admin-section-header root-admin-user-list-header">
          <h2>{accountFilter ? "Filtered Users" : "All Users"}</h2>
          <div className="root-admin-user-list-tools">
            <span className="helper-text">{users.length} shown</span>
            <div className="root-admin-search root-admin-search-wide">
              <input
                aria-label="Search users"
                id="root_admin_user_search"
                placeholder="Search by username, first name or surname"
                value={searchTerm}
                onChange={(event) => setSearchTerm(event.target.value)}
              />
            </div>
          </div>
        </div>

        {loading ? <div className="notice">Loading user accounts...</div> : null}
        {!loading && users.length === 0 ? (
          <div className="dashboard-empty">No users match the current search and account filter.</div>
        ) : null}

        <div className="dashboard-list">
          {users.map((user) => (
            <article
              className={`dashboard-item root-admin-user-row ${userRowClass(user)}`}
              key={user.id}
            >
              <div className="root-admin-user-directory-fields">
                <div>
                  <span className="helper-text">Username</span>
                  <strong>{user.username}</strong>
                </div>
                <div>
                  <span className="helper-text">Name</span>
                  <strong>{user.first_name || "Not provided"}</strong>
                </div>
                <div>
                  <span className="helper-text">Surname</span>
                  <strong>{user.surname || "Not provided"}</strong>
                </div>
                <div>
                  <span className="helper-text">Last Logged In</span>
                  <strong>{formatLastLogin(user.last_login_at)}</strong>
                </div>
              </div>
              <div className="button-row root-admin-user-actions">
                {user.account_status === "delete_pending" ? (
                  <span className="root-admin-delete-pending-warning">
                    Delete pending · clears {formatLastLogin(user.deletion_purge_after)}
                  </span>
                ) : null}
                {user.email_verified === false ? (
                  <span className="root-admin-verification-warning">Email not verified</span>
                ) : null}
                <button type="button" onClick={() => navigate(`/rckscoreAdmin/users/${user.id}`)}>
                  View Profile
                </button>
              </div>
            </article>
          ))}
        </div>
      </section>

      <AppFooter />
    </main>
  );
}
