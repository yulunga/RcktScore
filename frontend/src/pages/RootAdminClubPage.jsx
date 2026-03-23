import React, { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import {
  createOrganizationCourt,
  createOrganizationUser,
  deleteOrganizationCourt,
  getOrganizationSettings,
  updateOrganizationCourt,
  updateOrganizationDetails,
  updateOrganizationUserRole,
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
  username: "",
  password: "",
  role: "user",
};

const emptyCourtForm = {
  court_name: "",
  court_alias: "",
};

const sportOptions = [
  { name: "Squash", status: "active", note: "Primary launch scoring mode" },
  { name: "Tennis", status: "planned", note: "Planned after squash launch" },
  { name: "Racketball", status: "planned", note: "Planned after squash launch" },
  { name: "Badminton", status: "planned", note: "Planned after squash launch" },
];

function formatDate(value) {
  if (!value) {
    return "Unknown";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default function RootAdminClubPage() {
  const navigate = useNavigate();
  const { organizationId } = useParams();
  const [settings, setSettings] = useState(null);
  const [organizationForm, setOrganizationForm] = useState(emptyOrganizationForm);
  const [userForm, setUserForm] = useState(emptyUserForm);
  const [courtForm, setCourtForm] = useState(emptyCourtForm);
  const [courtDrafts, setCourtDrafts] = useState({});
  const [userRoleDrafts, setUserRoleDrafts] = useState({});
  const [handicapScoringEnabled, setHandicapScoringEnabled] = useState(true);
  const [loading, setLoading] = useState(true);
  const [savingSection, setSavingSection] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const mapUrl = useMemo(() => {
    const address = organizationForm.org_address || settings?.organization?.org_address;
    if (!address) {
      return "";
    }

    return `https://www.google.com/maps?q=${encodeURIComponent(address)}&output=embed`;
  }, [organizationForm.org_address, settings?.organization?.org_address]);

  const syncLocalState = useCallback((response) => {
    const nextSettings = response?.organizationSettings || response || null;

    setSettings(nextSettings);
    setOrganizationForm({
      organization_name: nextSettings?.organization?.organization_name || "",
      org_address: nextSettings?.organization?.org_address || "",
      org_contact: nextSettings?.organization?.org_contact || "",
      org_telephone: nextSettings?.organization?.org_telephone || "",
      org_email: nextSettings?.organization?.org_email || "",
      org_webaddress: nextSettings?.organization?.org_webaddress || "",
    });
    setCourtDrafts(
      Object.fromEntries(
        (nextSettings?.courts || []).map((court) => [
          court.id,
          {
            court_name: court.court_name || "",
            court_alias: court.court_alias || "",
          },
        ]),
      ),
    );
    setUserRoleDrafts(
      Object.fromEntries((nextSettings?.users || []).map((user) => [user.id, user.role || "user"])),
    );
  }, []);

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
      setError(requestError.message || "Failed to load club administration settings.");
    } finally {
      setLoading(false);
    }
  }, [organizationId, syncLocalState]);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  async function runMutation(section, task, successMessage) {
    setSavingSection(section);
    setMessage("");
    setError("");
    try {
      await task();
      await loadSettings();
      setMessage(successMessage);
    } catch (requestError) {
      setError(requestError.message || "Request failed.");
    } finally {
      setSavingSection("");
    }
  }

  async function handleOrganizationSubmit(event) {
    event.preventDefault();
    await runMutation(
      "organization",
      () => updateOrganizationDetails(organizationId, organizationForm),
      "Organisation details updated.",
    );
  }

  async function handleUserSubmit(event) {
    event.preventDefault();
    await runMutation(
      "user-create",
      () => createOrganizationUser({
        organization_id: organizationId,
        username: userForm.username,
        password: userForm.password,
        role: userForm.role,
      }),
      "User added to organisation.",
    );
    setUserForm(emptyUserForm);
  }

  async function handleUserRoleSave(userId) {
    await runMutation(
      `user-role-${userId}`,
      () => updateOrganizationUserRole(userId, {
        organization_id: organizationId,
        role: userRoleDrafts[userId],
      }),
      "User role updated.",
    );
  }

  async function handleCourtCreate(event) {
    event.preventDefault();
    await runMutation(
      "court-create",
      () => createOrganizationCourt({
        organization_id: organizationId,
        court_name: courtForm.court_name,
        court_alias: courtForm.court_alias,
      }),
      "Court created.",
    );
    setCourtForm(emptyCourtForm);
  }

  async function handleCourtSave(courtId) {
    await runMutation(
      `court-save-${courtId}`,
      () => updateOrganizationCourt(courtId, {
        organization_id: organizationId,
        court_name: courtDrafts[courtId]?.court_name || "",
        court_alias: courtDrafts[courtId]?.court_alias || "",
      }),
      "Court updated.",
    );
  }

  async function handleCourtDelete(courtId) {
    await runMutation(
      `court-delete-${courtId}`,
      () => deleteOrganizationCourt(courtId, { organization_id: organizationId }),
      "Court deleted.",
    );
  }

  const users = settings?.users || [];
  const courts = settings?.courts || [];

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

      <section className="hero-card stack compact">
        <span className="status-pill">Club Administration</span>
        <div className="settings-header-row">
          <div className="stack compact">
            <h1>{organizationForm.organization_name || "Club"}</h1>
            <p className="helper-text">
              Manage all club attributes, users, courts, and launch settings as root admin.
            </p>
          </div>
          <div className="button-row">
            <button className="secondary" type="button" onClick={() => navigate("/rckscoreAdmin/dashboard")}>
              Back to Root Admin
            </button>
          </div>
        </div>
      </section>

      {loading ? <div className="notice">Loading club administration page...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      <section className="settings-grid">
        <section className="panel stack settings-primary">
          <div className="panel-heading">
            <h2>Organisation Details</h2>
            <p className="helper-text">Club details used for contact information and venue context.</p>
          </div>

          <form className="stack" onSubmit={handleOrganizationSubmit}>
            <div className="field-grid">
              <div className="field">
                <label htmlFor="organization_name">Club Name</label>
                <input
                  id="organization_name"
                  value={organizationForm.organization_name}
                  onChange={(event) => setOrganizationForm((current) => ({ ...current, organization_name: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="org_contact">Primary Contact</label>
                <input
                  id="org_contact"
                  value={organizationForm.org_contact}
                  onChange={(event) => setOrganizationForm((current) => ({ ...current, org_contact: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="org_telephone">Telephone</label>
                <input
                  id="org_telephone"
                  value={organizationForm.org_telephone}
                  onChange={(event) => setOrganizationForm((current) => ({ ...current, org_telephone: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="org_email">Email</label>
                <input
                  id="org_email"
                  type="email"
                  value={organizationForm.org_email}
                  onChange={(event) => setOrganizationForm((current) => ({ ...current, org_email: event.target.value }))}
                />
              </div>
              <div className="field settings-field-wide">
                <label htmlFor="org_webaddress">Website</label>
                <input
                  id="org_webaddress"
                  type="url"
                  value={organizationForm.org_webaddress}
                  onChange={(event) => setOrganizationForm((current) => ({ ...current, org_webaddress: event.target.value }))}
                />
              </div>
              <div className="field settings-field-wide">
                <label htmlFor="org_address">Address</label>
                <input
                  id="org_address"
                  value={organizationForm.org_address}
                  onChange={(event) => setOrganizationForm((current) => ({ ...current, org_address: event.target.value }))}
                />
              </div>
            </div>

            <div className="button-row">
              <button disabled={savingSection === "organization"} type="submit">
                {savingSection === "organization" ? "Saving..." : "Save Organisation Details"}
              </button>
            </div>
          </form>
        </section>

        <section className="panel stack">
          <div className="panel-heading">
            <h2>Game Settings</h2>
            <p className="helper-text">
              Launch controls for organisation-specific scoring behaviour and future racket sports.
            </p>
          </div>

          <div className="game-settings-grid">
            <div className="field checkbox-field">
              <label className="checkbox-label" htmlFor="org_handicap_scoring">
                <input
                  checked={handicapScoringEnabled}
                  id="org_handicap_scoring"
                  name="org_handicap_scoring"
                  type="checkbox"
                  onChange={(event) => setHandicapScoringEnabled(event.target.checked)}
                />
                Enable Handicap Scoring
              </label>
              <p className="helper-text">
                Controls whether handicap match setup should be available for this organisation.
              </p>
            </div>

            <div className="dashboard-empty">
              This setting is scaffolded in the UI for now. Organisation-level persistence and enforcement
              will be added in a later backend pass.
            </div>
          </div>

          <div className="panel-heading">
            <h3>Racket Sports</h3>
            <p className="helper-text">
              Squash is the active launch sport. The others are shown for roadmap visibility only.
            </p>
          </div>

          <div className="sport-grid">
            {sportOptions.map((sport) => (
              <article
                key={sport.name}
                className={`sport-option ${sport.status === "active" ? "active" : "disabled"}`}
              >
                <strong>{sport.name}</strong>
                <span>{sport.status}</span>
                <p>{sport.note}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="panel stack">
          <div className="panel-heading">
            <h2>Organisation Users</h2>
            <p className="helper-text">Create users and update club roles.</p>
          </div>

          <form className="stack" onSubmit={handleUserSubmit}>
            <div className="field-grid settings-field-grid-tight">
              <div className="field">
                <label htmlFor="club_user_username">Username</label>
                <input
                  id="club_user_username"
                  required
                  value={userForm.username}
                  onChange={(event) => setUserForm((current) => ({ ...current, username: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="club_user_password">Password</label>
                <input
                  id="club_user_password"
                  required
                  type="password"
                  value={userForm.password}
                  onChange={(event) => setUserForm((current) => ({ ...current, password: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="club_user_role">Role</label>
                <select
                  id="club_user_role"
                  value={userForm.role}
                  onChange={(event) => setUserForm((current) => ({ ...current, role: event.target.value }))}
                >
                  <option value="user">User</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
            </div>

            <div className="button-row">
              <button disabled={savingSection === "user-create"} type="submit">
                {savingSection === "user-create" ? "Adding..." : "Add User"}
              </button>
            </div>
          </form>

          <div className="dashboard-list">
            {users.length === 0 ? (
              <div className="dashboard-empty">No organisation users yet.</div>
            ) : (
              users.map((user) => (
                <article className="dashboard-item" key={user.id}>
                  <div className="dashboard-item-head">
                    <strong>{user.username}</strong>
                    <span>{formatDate(user.created_at)}</span>
                  </div>
                  <div className="settings-inline-actions">
                    <select
                      value={userRoleDrafts[user.id] || user.role || "user"}
                      onChange={(event) =>
                        setUserRoleDrafts((current) => ({ ...current, [user.id]: event.target.value }))}
                    >
                      <option value="user">User</option>
                      <option value="admin">Admin</option>
                    </select>
                    <button
                      className="secondary"
                      disabled={savingSection === `user-role-${user.id}`}
                      type="button"
                      onClick={() => handleUserRoleSave(user.id)}
                    >
                      {savingSection === `user-role-${user.id}` ? "Saving..." : "Save Role"}
                    </button>
                  </div>
                </article>
              ))
            )}
          </div>
        </section>

        <section className="panel stack">
          <div className="panel-heading">
            <h2>Courts</h2>
            <p className="helper-text">Manage court names and aliases for this club.</p>
          </div>

          <form className="stack" onSubmit={handleCourtCreate}>
            <div className="field-grid settings-field-grid-tight">
              <div className="field">
                <label htmlFor="court_name">Court Name</label>
                <input
                  id="court_name"
                  required
                  value={courtForm.court_name}
                  onChange={(event) => setCourtForm((current) => ({ ...current, court_name: event.target.value }))}
                />
              </div>
              <div className="field">
                <label htmlFor="court_alias">Court Alias</label>
                <input
                  id="court_alias"
                  value={courtForm.court_alias}
                  onChange={(event) => setCourtForm((current) => ({ ...current, court_alias: event.target.value }))}
                />
              </div>
            </div>

            <div className="button-row">
              <button disabled={savingSection === "court-create"} type="submit">
                {savingSection === "court-create" ? "Adding..." : "Add Court"}
              </button>
            </div>
          </form>

          <div className="dashboard-list">
            {courts.length === 0 ? (
              <div className="dashboard-empty">No courts configured yet.</div>
            ) : (
              courts.map((court) => (
                <article className="dashboard-item" key={court.id}>
                  <div className="field-grid settings-field-grid-tight">
                    <div className="field">
                      <label htmlFor={`court_name_${court.id}`}>Court Name</label>
                      <input
                        id={`court_name_${court.id}`}
                        value={courtDrafts[court.id]?.court_name || ""}
                        onChange={(event) =>
                          setCourtDrafts((current) => ({
                            ...current,
                            [court.id]: {
                              ...current[court.id],
                              court_name: event.target.value,
                            },
                          }))}
                      />
                    </div>
                    <div className="field">
                      <label htmlFor={`court_alias_${court.id}`}>Court Alias</label>
                      <input
                        id={`court_alias_${court.id}`}
                        value={courtDrafts[court.id]?.court_alias || ""}
                        onChange={(event) =>
                          setCourtDrafts((current) => ({
                            ...current,
                            [court.id]: {
                              ...current[court.id],
                              court_alias: event.target.value,
                            },
                          }))}
                      />
                    </div>
                  </div>
                  <div className="button-row">
                    <button
                      disabled={savingSection === `court-save-${court.id}`}
                      type="button"
                      onClick={() => handleCourtSave(court.id)}
                    >
                      {savingSection === `court-save-${court.id}` ? "Saving..." : "Save Court"}
                    </button>
                    <button
                      className="danger"
                      disabled={savingSection === `court-delete-${court.id}`}
                      type="button"
                      onClick={() => handleCourtDelete(court.id)}
                    >
                      {savingSection === `court-delete-${court.id}` ? "Deleting..." : "Delete Court"}
                    </button>
                  </div>
                </article>
              ))
            )}
          </div>
        </section>

        <section className="panel stack">
          <div className="panel-heading">
            <h2>Venue Preview</h2>
            <p className="helper-text">Google Maps preview based on the saved club address.</p>
          </div>

          {mapUrl ? (
            <div className="map-frame-wrap">
              <iframe
                title="Organisation map"
                className="map-frame"
                src={mapUrl}
                loading="lazy"
                referrerPolicy="no-referrer-when-downgrade"
              />
            </div>
          ) : (
            <div className="dashboard-empty">Add an address above to show the venue map.</div>
          )}
        </section>
      </section>

      <AppFooter />
    </main>
  );
}
