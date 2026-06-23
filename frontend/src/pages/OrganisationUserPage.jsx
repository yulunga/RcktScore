import React, { useCallback, useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import {
  deleteOrganizationUser,
  getOrganizationSettings,
  updateOrganizationUser,
} from "../services/api";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function formatDate(value) {
  if (!value) {
    return "Unknown";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default function OrganisationUserPage() {
  const navigate = useNavigate();
  const { userId } = useParams();
  const { session } = useAuth();
  const [settings, setSettings] = useState(null);
  const [loading, setLoading] = useState(true);
  const [savingSection, setSavingSection] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    first_name: "",
    surname: "",
    username: "",
    role: "user",
    password: "",
  });

  const organizationId = session?.organization_id;
  const isAdmin = session?.role === "admin";
  const isPersonalSession = session?.organization_type === "personal";

  useEffect(() => {
    if (organizationId && (!isAdmin || isPersonalSession)) {
      navigate("/dashboard", { replace: true });
    }
  }, [isAdmin, isPersonalSession, navigate, organizationId]);

  const syncLocalState = useCallback((response) => {
    const nextSettings = response?.organizationSettings || response || null;
    const nextUser = (nextSettings?.users || []).find((user) => String(user.id) === String(userId));

    setSettings(nextSettings);
    if (nextUser) {
      setForm({
        first_name: nextUser.first_name || "",
        surname: nextUser.surname || "",
        username: nextUser.username || "",
        role: nextUser.role || "user",
        password: "",
      });
    }
  }, [userId]);

  const loadSettings = useCallback(async () => {
    if (!organizationId) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setError("");
    try {
      const response = await getOrganizationSettings(organizationId);
      syncLocalState(response);
    } catch (requestError) {
      setError(requestError.message || "Failed to load organisation user.");
    } finally {
      setLoading(false);
    }
  }, [organizationId, syncLocalState]);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  const user = (settings?.users || []).find((entry) => String(entry.id) === String(userId)) || null;

  async function handleSubmit(event) {
    event.preventDefault();
    const normalizedUsername = form.username.trim().toLowerCase();

    if (!EMAIL_PATTERN.test(normalizedUsername)) {
      setMessage("");
      setError("Enter a valid email address for the user.");
      return;
    }

    setSavingSection("save");
    setMessage("");
    setError("");
    try {
      await updateOrganizationUser(userId, {
        organization_id: organizationId,
        first_name: form.first_name,
        surname: form.surname,
        username: normalizedUsername,
        role: form.role,
        ...(form.password ? { password: form.password } : {}),
      });
      await loadSettings();
      setMessage("User details updated.");
    } catch (requestError) {
      setError(requestError.message || "Unable to update this user.");
    } finally {
      setSavingSection("");
    }
  }

  async function handleDelete() {
    const confirmed = window.confirm("Delete this user from the organisation?");
    if (!confirmed) {
      return;
    }

    setSavingSection("delete");
    setMessage("");
    setError("");
    try {
      await deleteOrganizationUser(userId, {
        organization_id: organizationId,
      });
      navigate("/settings?tab=users", { replace: true });
    } catch (requestError) {
      setError(requestError.message || "Unable to delete this user.");
      setSavingSection("");
    }
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        actions={[
          {
            label: "Back to Users",
            onClick: () => navigate("/settings?tab=users"),
          },
          {
            label: "Back to Dashboard",
            onClick: () => navigate("/dashboard"),
          },
        ]}
        subtitle="Edit organisation user details, role, and membership access."
        title="Organisation User"
      />

      {loading ? <div className="notice">Loading user...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}
      {message ? <div className="notice">{message}</div> : null}

      {!loading && !user ? (
        <section className="panel stack">
          <div className="dashboard-empty">User not found.</div>
        </section>
      ) : null}

      {user ? (
        <section className="panel stack">
          <div className="panel-heading">
            <h2>{[user.first_name, user.surname].filter(Boolean).join(" ").trim() || user.username}</h2>
            <p className="helper-text">Use this page to correct contact details, adjust role access, or remove the user from this organisation.</p>
          </div>

          <div className="meta-grid">
            <div className="meta-item meta-item--compact">
              <strong>Status</strong>
              <div>{user.status || "approved"}</div>
            </div>
            <div className="meta-item meta-item--compact">
              <strong>Created</strong>
              <div>{formatDate(user.created_at)}</div>
            </div>
            <div className="meta-item meta-item--compact">
              <strong>Password</strong>
              <div>{user.can_edit_password ? "Can be edited here" : "Managed across another shared account"}</div>
            </div>
          </div>

          <form className="stack" onSubmit={handleSubmit}>
            <div className="field-grid">
              <div className="field">
                <label htmlFor="edit_first_name">First Name</label>
                <input
                  id="edit_first_name"
                  value={form.first_name}
                  onChange={(event) => setForm((current) => ({ ...current, first_name: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="edit_surname">Surname</label>
                <input
                  id="edit_surname"
                  value={form.surname}
                  onChange={(event) => setForm((current) => ({ ...current, surname: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="edit_username">Email Address</label>
                <input
                  id="edit_username"
                  type="email"
                  value={form.username}
                  onChange={(event) => setForm((current) => ({ ...current, username: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="edit_role">Role</label>
                <select
                  id="edit_role"
                  value={form.role}
                  onChange={(event) => setForm((current) => ({ ...current, role: event.target.value }))}
                >
                  <option value="user">User</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
              <div className="field settings-field-wide">
                <label htmlFor="edit_password">Password</label>
                <input
                  disabled={!user.can_edit_password}
                  id="edit_password"
                  minLength="8"
                  placeholder={user.can_edit_password ? "Leave blank to keep the current password" : "Password cannot be changed here"}
                  type="password"
                  value={form.password}
                  onChange={(event) => setForm((current) => ({ ...current, password: event.target.value }))}
                />
                <p className="helper-text">
                  {user.can_edit_password
                    ? "Set a new password only if you need to correct or replace the current one."
                    : "This email is used in another organisation, so password changes must stay on the shared account."}
                </p>
              </div>
            </div>

            <div className="button-row">
              <button disabled={savingSection === "save" || savingSection === "delete"} type="submit">
                {savingSection === "save" ? "Saving..." : "Save User Details"}
              </button>
              <button
                className="danger"
                disabled={savingSection === "save" || savingSection === "delete"}
                type="button"
                onClick={handleDelete}
              >
                {savingSection === "delete" ? "Deleting..." : "Delete User"}
              </button>
            </div>
          </form>
        </section>
      ) : null}
      <AppFooter />
    </main>
  );
}
