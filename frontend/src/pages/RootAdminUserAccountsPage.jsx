import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { getRootAdminUsers } from "../services/api";

const ACCOUNT_FILTERS = [
  { value: "personal_free", label: "Personal Free", countKey: "personal_free_count" },
  { value: "personal_plus", label: "Personal Plus", countKey: "personal_plus_count" },
  { value: "club", label: "Club Accounts", countKey: "club_user_count" },
  { value: "unverified", label: "Unverified Users", countKey: "unverified_user_count" },
];

export default function RootAdminUserAccountsPage() {
  const navigate = useNavigate();
  const [accountFilter, setAccountFilter] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [directory, setDirectory] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const timeoutId = window.setTimeout(async () => {
      setLoading(true);
      setError("");
      try {
        const response = await getRootAdminUsers({
          accountType: accountFilter,
          query: searchTerm.trim(),
        });
        setDirectory(response.userDirectory || null);
      } catch (requestError) {
        setError(requestError.message || "Failed to load user accounts.");
      } finally {
        setLoading(false);
      }
    }, searchTerm.trim() ? 220 : 0);

    return () => window.clearTimeout(timeoutId);
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
          <h1>User Accounts</h1>
          <div className="button-row root-admin-actions">
            <button type="button" className="secondary" onClick={() => navigate("/rckscoreAdmin/dashboard")}>
              Back to Platform Control Centre
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
              onClick={() => selectFilter(filter.value)}
            >
              <strong>{filter.label}</strong>
              <div>{summary[filter.countKey] ?? 0}</div>
              <span>{accountFilter === filter.value ? "Showing this account type" : "Select to filter"}</span>
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
              className={`dashboard-item root-admin-user-row${user.email_verified === false ? " root-admin-user-row--unverified" : ""}`}
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
              </div>
              <div className="button-row root-admin-user-actions">
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
