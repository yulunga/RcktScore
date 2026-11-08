import React, { useEffect, useMemo, useState } from "react";
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
  const [sortOrder, setSortOrder] = useState("recent");
  const [limit, setLimit] = useState(25);
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
  const users = useMemo(() => [...(directory?.users || [])].sort((left, right) => {
    const alphabetical = left.username.localeCompare(right.username, "en-GB", { sensitivity: "base" });
    if (sortOrder === "alphabetical") return alphabetical;
    const leftLogin = left.last_login_at ? Date.parse(left.last_login_at) : -Infinity;
    const rightLogin = right.last_login_at ? Date.parse(right.last_login_at) : -Infinity;
    return rightLogin - leftLogin || alphabetical;
  }), [directory, sortOrder]);

  function selectFilter(nextFilter) {
    setAccountFilter((current) => (current === nextFilter ? "" : nextFilter));
  }

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

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
            <span className="helper-text">{Math.min(limit, users.length)} of {users.length} shown</span>
            <select aria-label="Sort users" value={sortOrder} onChange={(event) => setSortOrder(event.target.value)}>
              <option value="recent">Last logged in</option>
              <option value="alphabetical">Username A–Z</option>
            </select>
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
          {users.slice(0, limit).map((user) => (
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
                {user.club_count > 0 ? (
                  <span className="root-admin-club-count" role="img" aria-label={`Club associations: ${user.club_count}`} title={`Club associations: ${user.club_count}`}>
                    <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M3 21V8l9-5 9 5v13z" /></svg>
                    {user.club_count}
                  </span>
                ) : null}
                {user.account_types?.includes("personal_plus") ? (
                  <span className="root-admin-plus-badge" role="img" aria-label="Personal Plus" title="Personal Plus">+</span>
                ) : null}
                <button className="root-admin-icon-button" type="button" aria-label={`View profile for ${user.username}`} title="View profile" onClick={() => navigate(`/rckscoreAdmin/users/${user.id}`)}>
                  <svg aria-hidden="true" viewBox="0 0 24 24"><circle cx="12" cy="8" r="4" /><path d="M4 21v-2a5 5 0 0 1 5-5h6a5 5 0 0 1 5 5v2" /></svg>
                </button>
              </div>
            </article>
          ))}
        </div>
        {users.length > 25 ? (
          <div className="root-admin-user-limit">
            <label htmlFor="root-admin-user-limit">Users to show</label>
            <select id="root-admin-user-limit" value={limit} onChange={(event) => setLimit(Number(event.target.value))}>
              <option value={25}>25</option>
              <option value={100}>100</option>
              <option value={200}>200</option>
            </select>
          </div>
        ) : null}
      </section>

      <AppFooter />
    </main>
  );
}
