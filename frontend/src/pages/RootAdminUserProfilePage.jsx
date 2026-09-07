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
} from "../services/api";

const PLAN_LABELS = {
  personal_free: "Personal Free",
  personal_plus: "Personal Plus",
  club_essentials: "Club Essentials",
  club_pro: "Club Pro",
};

function formatDateTime(value) {
  if (!value) {
    return "Not recorded";
  }
  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default function RootAdminUserProfilePage() {
  const navigate = useNavigate();
  const { userId } = useParams();
  const { session } = useRootAdmin();
  const [profile, setProfile] = useState(null);
  const [selectedClubId, setSelectedClubId] = useState("");
  const [selectedRole, setSelectedRole] = useState("user");
  const [loading, setLoading] = useState(true);
  const [savingKey, setSavingKey] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const loadProfile = useCallback(async () => {
    if (!userId) {
      return;
    }
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
      () => addRootAdminUserMembership(userId, {
        organization_id: selectedClubId,
        role: selectedRole,
      }),
      "Club invitation created. The user must approve the association before it becomes active.",
    );
    if (result) {
      setSelectedClubId("");
      setSelectedRole("user");
    }
  }

  async function handleRemoveClub(membership) {
    const confirmed = window.confirm(
      `Remove ${profile.user.username} from ${membership.organization_name}?`,
    );
    if (!confirmed) {
      return;
    }
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

  const user = profile?.user || {};
  const activity = profile?.activity || {};
  const memberships = profile?.memberships || [];
  const personalMemberships = memberships.filter((membership) => membership.organization_type === "personal");
  const clubMemberships = memberships.filter((membership) => membership.organization_type !== "personal");
  const availableClubs = profile?.available_clubs || [];

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

      <section className="hero-card stack compact">
        <div className="root-admin-section-header">
          <div>
            <h1>User Profile</h1>
            <p className="helper-text">Account, scoring activity and club associations for {user.username || "this user"}.</p>
          </div>
          <div className="button-row root-admin-actions">
            <button type="button" className="secondary" onClick={() => navigate("/rckscoreAdmin/users")}>
              Back to User Accounts
            </button>
          </div>
        </div>
      </section>

      {loading ? <div className="notice">Loading user profile...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {!loading && profile ? (
        <>
          <section className="panel stack">
            <div className="panel-heading">
              <h2>Registered Details</h2>
            </div>
            <div className="meta-grid">
              <div className="meta-item"><strong>Username</strong><div>{user.username}</div></div>
              <div className="meta-item"><strong>First Name</strong><div>{user.first_name || "Not provided"}</div></div>
              <div className="meta-item"><strong>Surname</strong><div>{user.surname || "Not provided"}</div></div>
              <div className="meta-item"><strong>Registered</strong><div>{formatDateTime(user.registered_at)}</div></div>
              <div className="meta-item"><strong>Telephone</strong><div>{user.telephone || "Not provided"}</div></div>
              <div className="meta-item"><strong>Location</strong><div>{[user.city_location, user.country].filter(Boolean).join(", ") || "Not provided"}</div></div>
            </div>
          </section>

          <section className="panel stack">
            <div className="panel-heading">
              <h2>Scoring Activity</h2>
              <p className="helper-text">{activity.attribution_note}</p>
            </div>
            <div className="meta-grid">
              <div className="meta-item"><strong>Matches Scored</strong><div>{activity.match_count ?? 0}</div></div>
              {(activity.game_types || []).map((gameType) => (
                <div className="meta-item" key={gameType.sport}>
                  <strong>{gameType.label}</strong>
                  <div>{gameType.match_count}</div>
                </div>
              ))}
            </div>
            <div className="dashboard-list">
              {(activity.recent_matches || []).map((match) => (
                <article className="dashboard-item" key={match.id}>
                  <div className="dashboard-item-head">
                    <strong>{match.players}</strong>
                    <span className="status-pill">{match.sport_label}</span>
                  </div>
                  <div className="dashboard-item-meta">
                    <span>{match.organization_name}</span>
                    <span>{match.status}</span>
                    <span>{formatDateTime(match.updated_at || match.created_at)}</span>
                  </div>
                </article>
              ))}
              {(activity.recent_matches || []).length === 0 ? (
                <div className="dashboard-empty">No attributable match activity has been recorded yet.</div>
              ) : null}
            </div>
          </section>

          <section className="panel stack">
            <div className="panel-heading">
              <h2>Club Associations</h2>
              <p className="helper-text">Club memberships continue to use invitation and approval.</p>
            </div>

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
                <select id="user_profile_role" value={selectedRole} onChange={(event) => setSelectedRole(event.target.value)}>
                  <option value="user">User</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
              <div className="button-row root-admin-profile-add-action">
                <button disabled={savingKey === "add-club" || !availableClubs.length} type="submit">
                  {savingKey === "add-club" ? "Sending Invitation..." : "Add Club Association"}
                </button>
              </div>
            </form>

            <div className="dashboard-list">
              {clubMemberships.map((membership) => (
                <article className="dashboard-item" key={membership.id}>
                  <div className="dashboard-item-head">
                    <strong>{membership.organization_name}</strong>
                    <span className={`status-pill ${membership.status === "pending" ? "warning" : ""}`}>{membership.status}</span>
                  </div>
                  <div className="dashboard-item-meta">
                    <span>{PLAN_LABELS[membership.plan] || membership.plan}</span>
                    <span>Role: {membership.role}</span>
                    <span>Joined: {formatDateTime(membership.registered_at)}</span>
                    <span>Sports: {membership.enabled_sports.length ? membership.enabled_sports.join(", ") : "None"}</span>
                  </div>
                  <div className="button-row">
                    <button className="danger" disabled={savingKey === `remove-${membership.id}`} type="button" onClick={() => handleRemoveClub(membership)}>
                      {savingKey === `remove-${membership.id}` ? "Removing..." : "Remove from Club"}
                    </button>
                  </div>
                </article>
              ))}
              {clubMemberships.length === 0 ? <div className="dashboard-empty">No club associations.</div> : null}
            </div>
          </section>

          {personalMemberships.map((membership) => {
            const enabledSports = normalizeEnabledSports(membership.enabled_sports);
            return (
              <section className="panel stack" key={membership.id}>
                <div className="panel-heading">
                  <h2>Personal Account</h2>
                  <p className="helper-text">Current plan: {PLAN_LABELS[membership.plan] || membership.plan}</p>
                </div>
                <div className="button-row">
                  <button disabled={savingKey === `plan-${membership.id}` || membership.plan === "personal_free"} type="button" onClick={() => handlePlanChange(membership, "personal_free")}>Set Personal Free</button>
                  <button className="secondary" disabled={savingKey === `plan-${membership.id}` || membership.plan === "personal_plus"} type="button" onClick={() => handlePlanChange(membership, "personal_plus")}>Set Personal Plus</button>
                </div>
                <div className="sport-grid">
                  {MATCH_SPORT_OPTIONS.map((sport) => {
                    const enabled = enabledSports.includes(sport.value);
                    return (
                      <article className={`sport-option${enabled ? " active" : " disabled"}`} key={sport.value}>
                        <strong>{sport.label}</strong>
                        <span>{enabled ? "Enabled" : "Disabled"}</span>
                        <button disabled={savingKey === `sports-${membership.id}`} type="button" className={enabled ? "secondary" : ""} onClick={() => handleSportToggle(membership, sport.value)}>
                          {enabled ? "Disable" : "Enable"}
                        </button>
                      </article>
                    );
                  })}
                </div>
              </section>
            );
          })}
        </>
      ) : null}

      <AppFooter />
    </main>
  );
}
