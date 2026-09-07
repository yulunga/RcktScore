import React, { useCallback, useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { MATCH_SPORT_OPTIONS, normalizeEnabledSports } from "../constants/matchSports";
import { useRootAdmin } from "../hooks/useRootAdmin";
import {
  addRootAdminUserMembership,
  deleteRootAdminUserMembership,
  getRootAdminUserProfile,
  updateRootAdminPersonalAccount,
  updateRootAdminUserPassword,
} from "../services/api";

const PLAN_LABELS = {
  personal_free: "Personal",
  personal_plus: "Personal Plus",
  club_essentials: "Club Essentials",
  club_pro: "Club Pro",
};

const PROFILE_TABS = [
  { id: "profile", label: "Profile" },
  { id: "subscription", label: "Subscription" },
  { id: "clubs", label: "Club Association" },
  { id: "activity", label: "Scoring Activity" },
  { id: "settings", label: "Settings" },
];

function formatDateTime(value) {
  if (!value) {
    return "Not recorded";
  }
  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function displaySportList(enabledSports) {
  const sports = normalizeEnabledSports(enabledSports);
  return sports.length
    ? sports.map((sport) => MATCH_SPORT_OPTIONS.find((option) => option.value === sport)?.label || sport).join(", ")
    : "None enabled";
}

export default function RootAdminUserProfilePage() {
  const navigate = useNavigate();
  const { userId } = useParams();
  const { session } = useRootAdmin();
  const [profile, setProfile] = useState(null);
  const [activeTab, setActiveTab] = useState("profile");
  const [selectedClubId, setSelectedClubId] = useState("");
  const [selectedRole, setSelectedRole] = useState("user");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(true);
  const [savingKey, setSavingKey] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const loadProfile = useCallback(async () => {
    if (!userId) return;
    setLoading(true);
    setError("");
    try {
      const response = await getRootAdminUserProfile(userId);
      setProfile(response.userProfile || null);
    } catch (requestError) {
      setError(requestError.message || "Failed to load the user profile.");
    } finally {
      setLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    loadProfile();
  }, [loadProfile]);

  async function runMutation(key, task, successMessage) {
    setSavingKey(key);
    setMessage("");
    setError("");
    try {
      const result = await task();
      await loadProfile();
      setMessage(successMessage);
      return result;
    } catch (requestError) {
      setError(requestError.message || "Request failed.");
      return null;
    } finally {
      setSavingKey("");
    }
  }

  async function handleAddClub(event) {
    event.preventDefault();
    if (!selectedClubId) {
      setError("Select a club to add.");
      return;
    }
    const result = await runMutation(
      "add-club",
      () => addRootAdminUserMembership(userId, { organization_id: selectedClubId, role: selectedRole }),
      "Club invitation created. The user must approve the association before it becomes active.",
    );
    if (result) {
      setSelectedClubId("");
      setSelectedRole("user");
    }
  }

  async function handleRemoveClub(membership) {
    if (!window.confirm(`Remove ${profile.user.username} from ${membership.organization_name}?`)) return;
    const result = await runMutation(
      `remove-${membership.id}`,
      () => deleteRootAdminUserMembership(userId, membership.id),
      "Club association removed.",
    );
    if (result?.next_user_id && String(result.next_user_id) !== String(userId)) {
      navigate(`/rckscoreAdmin/users/${result.next_user_id}`, { replace: true });
    }
  }

  async function handlePlanChange(membership, plan) {
    await runMutation(
      `plan-${membership.id}`,
      () => updateRootAdminPersonalAccount(membership.organization_id, {
        personal_plan: plan,
        updated_by: session?.username || "Root Admin",
      }),
      `Personal account changed to ${PLAN_LABELS[plan]}.`,
    );
  }

  async function handleSportToggle(membership, sportValue) {
    const currentSports = normalizeEnabledSports(membership.enabled_sports);
    const nextSports = currentSports.includes(sportValue)
      ? currentSports.filter((value) => value !== sportValue)
      : [...currentSports, sportValue];
    await runMutation(
      `sports-${membership.id}`,
      () => updateRootAdminPersonalAccount(membership.organization_id, {
        enabled_sports: nextSports,
        updated_by: session?.username || "Root Admin",
      }),
      "Personal account sports updated.",
    );
  }

  async function handlePasswordChange(event) {
    event.preventDefault();
    if (newPassword.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (newPassword !== confirmPassword) {
      setError("The password confirmation does not match.");
      return;
    }
    if (!window.confirm(`Change the password for ${user.username}? All active sessions for this user will be signed out.`)) return;

    const result = await runMutation(
      "password",
      () => updateRootAdminUserPassword(userId, { password: newPassword }),
      "Password changed. All active sessions for this user have been signed out.",
    );
    if (result) {
      setNewPassword("");
      setConfirmPassword("");
    }
  }

  const user = profile?.user || {};
  const activity = profile?.activity || {};
  const memberships = profile?.memberships || [];
  const clubMemberships = memberships.filter((membership) => membership.organization_type !== "personal");
  const availableClubs = profile?.available_clubs || [];

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

      <section className="hero-card compact root-admin-profile-header">
        <strong className="root-admin-profile-username">{user.username || "User account"}</strong>
        <div className="button-row root-admin-actions">
          <button type="button" className="secondary" onClick={() => navigate("/rckscoreAdmin/users")}>Back to User Accounts</button>
        </div>
      </section>

      {loading ? <div className="notice">Loading user profile...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {!loading && profile ? (
        <>
          <nav className="panel root-admin-profile-tabs" aria-label="User profile sections">
            {PROFILE_TABS.map((tab) => (
              <button key={tab.id} className={`root-admin-tab${activeTab === tab.id ? " active" : ""}`} type="button" onClick={() => setActiveTab(tab.id)}>
                {tab.label}
              </button>
            ))}
          </nav>

          {activeTab === "profile" ? (
            <section className="panel stack">
              <div className="panel-heading"><h2>Profile</h2></div>
              <div className="root-admin-profile-detail-grid">
                <div><strong>Username</strong><span>{user.username}</span></div>
                <div><strong>First Name</strong><span>{user.first_name || "Not provided"}</span></div>
                <div><strong>Surname</strong><span>{user.surname || "Not provided"}</span></div>
                <div><strong>Email Address</strong><span>{user.email || user.username}</span></div>
                <div><strong>Location</strong><span>{[user.city_location, user.country].filter(Boolean).join(", ") || "Not provided"}</span></div>
                <div><strong>Telephone</strong><span>{user.telephone || "Not provided"}</span></div>
                <div><strong>Date Registered</strong><span>{formatDateTime(user.registered_at)}</span></div>
                <div><strong>Last Activity</strong><span>{formatDateTime(user.last_activity_at)}</span></div>
              </div>
              <form className="stack root-admin-password-form" onSubmit={handlePasswordChange}>
                <div className="panel-heading">
                  <h3>Change Password</h3>
                  <p className="helper-text">Changing the password signs this user out on every device.</p>
                </div>
                <div className="field-grid settings-field-grid-tight">
                  <div className="field">
                    <label htmlFor="root_admin_new_password">New Password</label>
                    <input id="root_admin_new_password" minLength="8" required type="password" autoComplete="new-password" value={newPassword} onChange={(event) => setNewPassword(event.target.value)} />
                  </div>
                  <div className="field">
                    <label htmlFor="root_admin_confirm_password">Confirm Password</label>
                    <input id="root_admin_confirm_password" minLength="8" required type="password" autoComplete="new-password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} />
                  </div>
                </div>
                <div className="button-row"><button disabled={savingKey === "password"} type="submit">{savingKey === "password" ? "Changing Password..." : "Change Password"}</button></div>
              </form>
            </section>
          ) : null}

          {activeTab === "subscription" ? (
            <section className="panel stack">
              <div className="panel-heading"><h2>Subscription</h2><p className="helper-text">Current personal and club subscription access.</p></div>
              <div className="dashboard-list">
                {memberships.map((membership) => (
                  <article className="dashboard-item" key={membership.id}>
                    <div className="dashboard-item-head">
                      <strong>{membership.organization_type === "personal" ? "Personal Account" : membership.organization_name}</strong>
                      <span className="status-pill">{PLAN_LABELS[membership.plan] || membership.plan}</span>
                    </div>
                    <div className="dashboard-item-meta"><span>Status: {membership.status}</span><span>Registered: {formatDateTime(membership.registered_at)}</span></div>
                    {membership.organization_type === "personal" ? (
                      <div className="button-row">
                        <button aria-pressed={membership.plan === "personal_free"} className={`root-admin-plan-option${membership.plan === "personal_free" ? " active" : ""}`} disabled={savingKey === `plan-${membership.id}`} type="button" onClick={() => handlePlanChange(membership, "personal_free")}>Personal</button>
                        <button aria-pressed={membership.plan === "personal_plus"} className={`root-admin-plan-option${membership.plan === "personal_plus" ? " active" : ""}`} disabled={savingKey === `plan-${membership.id}`} type="button" onClick={() => handlePlanChange(membership, "personal_plus")}>Personal Plus</button>
                      </div>
                    ) : null}
                  </article>
                ))}
              </div>
            </section>
          ) : null}

          {activeTab === "clubs" ? (
            <section className="panel stack">
              <div className="panel-heading"><h2>Club Association</h2><p className="helper-text">Club memberships continue to use invitation and approval.</p></div>
              <form className="field-grid settings-field-grid-tight" onSubmit={handleAddClub}>
                <div className="field">
                  <label htmlFor="user_profile_club">Add to Club</label>
                  <select id="user_profile_club" value={selectedClubId} onChange={(event) => setSelectedClubId(event.target.value)}>
                    <option value="">Select a club</option>
                    {availableClubs.map((club) => <option key={club.id} value={club.id}>{club.organization_name}</option>)}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="user_profile_role">Role</label>
                  <select id="user_profile_role" value={selectedRole} onChange={(event) => setSelectedRole(event.target.value)}><option value="user">User</option><option value="admin">Admin</option></select>
                </div>
                <div className="button-row root-admin-profile-add-action">
                  <button disabled={savingKey === "add-club" || !availableClubs.length} type="submit">{savingKey === "add-club" ? "Sending Invitation..." : "Add Club Association"}</button>
                </div>
              </form>
              <div className="dashboard-list">
                {clubMemberships.map((membership) => (
                  <article className="dashboard-item" key={membership.id}>
                    <div className="dashboard-item-head"><strong>{membership.organization_name}</strong><span className={`status-pill ${membership.status === "pending" ? "warning" : ""}`}>{membership.status}</span></div>
                    <div className="dashboard-item-meta">
                      <span>{PLAN_LABELS[membership.plan] || membership.plan}</span><span>Role: {membership.role}</span><span>Joined: {formatDateTime(membership.registered_at)}</span><span>Sports: {displaySportList(membership.enabled_sports)}</span>
                    </div>
                    <div className="button-row"><button className="danger" disabled={savingKey === `remove-${membership.id}`} type="button" onClick={() => handleRemoveClub(membership)}>{savingKey === `remove-${membership.id}` ? "Removing..." : "Remove from Club"}</button></div>
                  </article>
                ))}
                {clubMemberships.length === 0 ? <div className="dashboard-empty">No club associations.</div> : null}
              </div>
            </section>
          ) : null}

          {activeTab === "activity" ? (
            <section className="panel stack">
              <div className="panel-heading"><h2>Scoring Activity</h2><p className="helper-text">{activity.attribution_note}</p></div>
              <div className="meta-grid root-admin-profile-activity-grid">
                <div className="meta-item"><strong>Matches Scored</strong><div>{activity.match_count ?? 0}</div></div>
                {MATCH_SPORT_OPTIONS.map((sport) => {
                  const gameType = (activity.game_types || []).find((item) => item.sport === sport.value);
                  return <div className="meta-item" key={sport.value}><strong>{sport.label}</strong><div>{gameType?.match_count ?? 0}</div></div>;
                })}
              </div>
              <div className="dashboard-list">
                {(activity.recent_matches || []).map((match) => (
                  <article className="dashboard-item" key={match.id}>
                    <div className="dashboard-item-head"><strong>{match.players}</strong><span className="status-pill">{match.sport_label}</span></div>
                    <div className="dashboard-item-meta"><span>{match.organization_name}</span><span>{match.status}</span><span>{formatDateTime(match.updated_at || match.created_at)}</span></div>
                  </article>
                ))}
                {(activity.recent_matches || []).length === 0 ? <div className="dashboard-empty">No attributable match activity has been recorded yet.</div> : null}
              </div>
            </section>
          ) : null}

          {activeTab === "settings" ? (
            <section className="panel stack">
              <div className="panel-heading"><h2>Scoring Sports Enabled</h2><p className="helper-text">Personal sports can be changed here. Club sports are controlled from the club settings page.</p></div>
              {memberships.map((membership) => {
                const enabledSports = normalizeEnabledSports(membership.enabled_sports);
                return (
                  <div className="stack root-admin-profile-sports-group" key={membership.id}>
                    <div className="root-admin-section-header"><h3>{membership.organization_type === "personal" ? "Personal Account" : membership.organization_name}</h3><span className="helper-text">{membership.organization_type === "personal" ? "Editable" : "Managed by club"}</span></div>
                    <div className="sport-grid">
                      {MATCH_SPORT_OPTIONS.map((sport) => {
                        const enabled = enabledSports.includes(sport.value);
                        return (
                          <article className={`sport-option${enabled ? " active" : " disabled"}`} key={sport.value}>
                            <strong>{sport.label}</strong><span>{enabled ? "Enabled" : "Disabled"}</span>
                            {membership.organization_type === "personal" ? <button disabled={savingKey === `sports-${membership.id}`} type="button" className={enabled ? "secondary" : ""} onClick={() => handleSportToggle(membership, sport.value)}>{enabled ? "Disable" : "Enable"}</button> : null}
                          </article>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </section>
          ) : null}
        </>
      ) : null}

      <AppFooter />
    </main>
  );
}
