import React, { useEffect, useMemo, useState } from "react";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { useRootAdmin } from "../hooks/useRootAdmin";
import {
  createRootAdminOrganization,
  createRootAdminOrganizationUser,
  getRootAdminDashboard,
  updateRootAdminOrganizationUserRole,
} from "../services/api";

const emptyOrganizationForm = {
  organization_name: "",
  org_address: "",
  org_contact: "",
  org_telephone: "",
  org_email: "",
  org_webaddress: "",
};

const emptyUserForm = {
  organization_id: "",
  username: "",
  password: "",
  role: "user",
};

function formatDate(value) {
  if (!value) {
    return "Unknown";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default function RootAdminDashboardPage() {
  const { session } = useRootAdmin();
  const [dashboard, setDashboard] = useState(null);
  const [organizationForm, setOrganizationForm] = useState(emptyOrganizationForm);
  const [userForm, setUserForm] = useState(emptyUserForm);
  const [userRoleDrafts, setUserRoleDrafts] = useState({});
  const [loading, setLoading] = useState(true);
  const [savingSection, setSavingSection] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function loadDashboard() {
    setLoading(true);
    setError("");
    try {
      const response = await getRootAdminDashboard();
      const nextDashboard = response.rootAdminDashboard || null;
      setDashboard(nextDashboard);
      setUserRoleDrafts(
        Object.fromEntries(
          (nextDashboard?.organizations || []).flatMap((organization) =>
            (organization.users || []).map((user) => [user.id, user.role || "user"]),
          ),
        ),
      );
      setUserForm((current) => ({
        ...current,
        organization_id:
          current.organization_id
          || String(nextDashboard?.organizations?.[0]?.id || ""),
      }));
    } catch (requestError) {
      setError(requestError.message || "Failed to load root admin dashboard.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadDashboard();
  }, []);

  async function runMutation(section, task, successMessage) {
    setSavingSection(section);
    setMessage("");
    setError("");
    try {
      await task();
      await loadDashboard();
      setMessage(successMessage);
    } catch (requestError) {
      setError(requestError.message || "Request failed.");
    } finally {
      setSavingSection("");
    }
  }

  async function handleCreateOrganization(event) {
    event.preventDefault();
    await runMutation(
      "create-organization",
      () => createRootAdminOrganization(organizationForm),
      "Organisation created.",
    );
    setOrganizationForm(emptyOrganizationForm);
  }

  async function handleCreateUser(event) {
    event.preventDefault();
    await runMutation(
      "create-user",
      () => createRootAdminOrganizationUser(userForm),
      "Tenant user created.",
    );
    setUserForm((current) => ({
      ...emptyUserForm,
      organization_id: current.organization_id,
    }));
  }

  async function handleUserRoleSave(user) {
    await runMutation(
      `save-user-${user.id}`,
      () =>
        updateRootAdminOrganizationUserRole(user.id, {
          organization_id: user.organization_id,
          role: userRoleDrafts[user.id],
        }),
      "User role updated.",
    );
  }

  const organizations = dashboard?.organizations || [];
  const summary = dashboard?.summary || {};
  const organizationOptions = useMemo(
    () =>
      organizations.map((organization) => ({
        value: String(organization.id),
        label: organization.organization_name || `Organisation ${organization.id}`,
      })),
    [organizations],
  );

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

      <section className="hero-card stack compact">
        <span className="status-pill">Root Administration</span>
        <h1>Platform Control Centre</h1>
        <p className="helper-text">
          Manage tenant organisations and their users from one top-level administration portal.
        </p>
        <div className="meta-grid">
          <div className="meta-item">
            <strong>Signed in as</strong>
            <div>{session?.username || "Root Admin"}</div>
          </div>
          <div className="meta-item">
            <strong>Tenant Organisations</strong>
            <div>{summary.organization_count ?? 0}</div>
          </div>
          <div className="meta-item">
            <strong>Tenant Users</strong>
            <div>{summary.user_count ?? 0}</div>
          </div>
          <div className="meta-item">
            <strong>Tenant Admins</strong>
            <div>{summary.admin_count ?? 0}</div>
          </div>
        </div>
      </section>

      {loading ? <div className="notice">Loading root admin dashboard...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      <section className="dashboard-grid">
        <section className="panel stack dashboard-primary">
          <div className="panel-heading">
            <h2>Create Tenant Organisation</h2>
            <p className="helper-text">Add a new tenant organisation to the platform.</p>
          </div>

          <form className="stack" onSubmit={handleCreateOrganization}>
            <div className="field-grid">
              <div className="field">
                <label htmlFor="root_org_name">Club Name</label>
                <input
                  id="root_org_name"
                  required
                  value={organizationForm.organization_name}
                  onChange={(event) =>
                    setOrganizationForm((current) => ({
                      ...current,
                      organization_name: event.target.value,
                    }))}
                />
              </div>
              <div className="field">
                <label htmlFor="root_org_contact">Primary Contact</label>
                <input
                  id="root_org_contact"
                  value={organizationForm.org_contact}
                  onChange={(event) =>
                    setOrganizationForm((current) => ({ ...current, org_contact: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="root_org_telephone">Telephone</label>
                <input
                  id="root_org_telephone"
                  value={organizationForm.org_telephone}
                  onChange={(event) =>
                    setOrganizationForm((current) => ({ ...current, org_telephone: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="root_org_email">Email</label>
                <input
                  id="root_org_email"
                  type="email"
                  value={organizationForm.org_email}
                  onChange={(event) =>
                    setOrganizationForm((current) => ({ ...current, org_email: event.target.value }))}
                />
              </div>
              <div className="field settings-field-wide">
                <label htmlFor="root_org_web">Website</label>
                <input
                  id="root_org_web"
                  type="url"
                  value={organizationForm.org_webaddress}
                  onChange={(event) =>
                    setOrganizationForm((current) => ({ ...current, org_webaddress: event.target.value }))}
                />
              </div>
              <div className="field settings-field-wide">
                <label htmlFor="root_org_address">Address</label>
                <input
                  id="root_org_address"
                  value={organizationForm.org_address}
                  onChange={(event) =>
                    setOrganizationForm((current) => ({ ...current, org_address: event.target.value }))}
                />
              </div>
            </div>

            <div className="button-row">
              <button disabled={savingSection === "create-organization"} type="submit">
                {savingSection === "create-organization" ? "Creating..." : "Create Organisation"}
              </button>
            </div>
          </form>
        </section>

        <section className="panel stack">
          <div className="panel-heading">
            <h2>Create Tenant User</h2>
            <p className="helper-text">Add a user directly into any tenant organisation.</p>
          </div>

          <form className="stack" onSubmit={handleCreateUser}>
            <div className="field">
              <label htmlFor="root_user_org">Organisation</label>
              <select
                id="root_user_org"
                required
                value={userForm.organization_id}
                onChange={(event) =>
                  setUserForm((current) => ({ ...current, organization_id: event.target.value }))}
              >
                <option value="">Select organisation</option>
                {organizationOptions.map((organization) => (
                  <option key={organization.value} value={organization.value}>
                    {organization.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="field">
              <label htmlFor="root_user_name">Username</label>
              <input
                id="root_user_name"
                required
                value={userForm.username}
                onChange={(event) =>
                  setUserForm((current) => ({ ...current, username: event.target.value }))}
              />
            </div>
            <div className="field">
              <label htmlFor="root_user_password">Password</label>
              <input
                id="root_user_password"
                required
                type="password"
                value={userForm.password}
                onChange={(event) =>
                  setUserForm((current) => ({ ...current, password: event.target.value }))}
              />
            </div>
            <div className="field">
              <label htmlFor="root_user_role">Role</label>
              <select
                id="root_user_role"
                value={userForm.role}
                onChange={(event) =>
                  setUserForm((current) => ({ ...current, role: event.target.value }))}
              >
                <option value="user">User</option>
                <option value="admin">Admin</option>
              </select>
            </div>

            <div className="button-row">
              <button disabled={savingSection === "create-user"} type="submit">
                {savingSection === "create-user" ? "Creating..." : "Create Tenant User"}
              </button>
            </div>
          </form>
        </section>

        <section className="panel stack">
          <div className="panel-heading">
            <h2>Tenant Organisations</h2>
            <p className="helper-text">Platform-wide organisation list with current user access.</p>
          </div>

          {organizations.length === 0 ? (
            <div className="dashboard-empty">No organisations have been created yet.</div>
          ) : (
            <div className="dashboard-list">
              {organizations.map((organization) => (
                <article className="dashboard-item root-admin-org-card" key={organization.id}>
                  <div className="dashboard-item-head">
                    <strong>{organization.organization_name || `Organisation ${organization.id}`}</strong>
                    <span className="status-pill">Tenant {organization.id}</span>
                  </div>

                  <div className="dashboard-item-meta">
                    <span>Email: {organization.org_email || "Not set"}</span>
                    <span>Contact: {organization.org_contact || "Not set"}</span>
                    <span>Telephone: {organization.org_telephone || "Not set"}</span>
                    <span>Courts: {organization.court_count ?? 0}</span>
                    <span>Users: {organization.user_count ?? 0}</span>
                    <span>Admins: {organization.admin_count ?? 0}</span>
                  </div>

                  <div className="root-admin-user-list">
                    {(organization.users || []).length === 0 ? (
                      <div className="dashboard-empty">No users for this organisation yet.</div>
                    ) : (
                      organization.users.map((user) => (
                        <div className="root-admin-user-row" key={user.id}>
                          <div>
                            <strong>{user.username}</strong>
                            <span className="helper-text">Created {formatDate(user.created_at)}</span>
                          </div>
                          <div className="settings-inline-actions">
                            <select
                              value={userRoleDrafts[user.id] || user.role || "user"}
                              onChange={(event) =>
                                setUserRoleDrafts((current) => ({
                                  ...current,
                                  [user.id]: event.target.value,
                                }))}
                            >
                              <option value="user">User</option>
                              <option value="admin">Admin</option>
                            </select>
                            <button
                              className="secondary"
                              disabled={savingSection === `save-user-${user.id}`}
                              type="button"
                              onClick={() => handleUserRoleSave(user)}
                            >
                              {savingSection === `save-user-${user.id}` ? "Saving..." : "Save Role"}
                            </button>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>
      </section>

      <AppFooter />
    </main>
  );
}
