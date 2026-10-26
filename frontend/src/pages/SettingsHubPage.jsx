import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import SubscriptionPreview from "../components/SubscriptionPreview";
import { clubRoleLabel } from "../utils/accessControl";
import { COUNTRIES } from "../constants/countries";
import { useAuth } from "../hooks/useAuth";
import { getOrganizationSettings, requestPasswordReset, updatePersonalProfile } from "../services/api";
import OrganisationSettingsPage from "./OrganisationSettingsPage";

const SETTINGS_MENU = [
  { id: "profile", label: "Profile" },
  { id: "associations", label: "Association" },
  { id: "subscription", label: "Subscription" },
  { id: "app", label: "App Settings" },
];

const EMPTY_PROFILE = {
  email: "",
  first_name: "",
  surname: "",
  telephone: "",
  city_location: "",
  country: "",
};

function currentUser(settings, username) {
  const normalized = String(username || "").trim().toLowerCase();
  return (settings?.users || []).find((user) => String(user.username || "").trim().toLowerCase() === normalized) || null;
}

function profileFrom(user, session) {
  return {
    email: user?.username || session?.email || session?.username || "",
    first_name: user?.first_name || session?.first_name || "",
    surname: user?.surname || session?.surname || "",
    telephone: user?.telephone || session?.telephone || "",
    city_location: user?.city_location || session?.city_location || "",
    country: user?.country || session?.country || "",
  };
}

function planLabel(plan) {
  const labels = {
    personal_free: "Personal Free",
    personal_plus: "Personal Plus",
    club_essentials: "Club Essentials",
    club_pro: "Club Pro",
  };
  return labels[plan] || String(plan || "Not assigned").replaceAll("_", " ");
}

function initials(profile) {
  return [profile.first_name, profile.surname]
    .filter(Boolean)
    .map((value) => value.trim().slice(0, 1).toUpperCase())
    .join("") || "HS";
}

export default function SettingsHubPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { session, setSession, logout } = useAuth();
  const [settings, setSettings] = useState(null);
  const [profile, setProfile] = useState(EMPTY_PROFILE);
  const [editing, setEditing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [profileImage, setProfileImage] = useState("");
  const fileInputRef = useRef(null);
  const requestedSection = searchParams.get("section");
  const activeSection = SETTINGS_MENU.some((item) => item.id === requestedSection) ? requestedSection : "profile";
  const showClubWorkspace = searchParams.get("club") === "1";

  const memberships = useMemo(() => {
    const available = session?.available_memberships || session?.memberships || [session];
    return available.filter(Boolean);
  }, [session]);
  const clubMemberships = memberships.filter((membership) => membership.organization_type === "club");
  const identityMembership = memberships.find((membership) => membership.organization_type === "personal") || session;
  const organizationId = identityMembership?.organization_id;

  const loadProfile = useCallback(async () => {
    if (!organizationId) return;
    setLoading(true);
    setError("");
    try {
      const response = await getOrganizationSettings(organizationId);
      const nextSettings = response?.organizationSettings || response;
      setSettings(nextSettings);
      setProfile(profileFrom(currentUser(nextSettings, session?.username), session));
    } catch (requestError) {
      setError(requestError.message || "Unable to load settings.");
    } finally {
      setLoading(false);
    }
  }, [organizationId, session]);

  useEffect(() => {
    loadProfile();
  }, [loadProfile]);

  useEffect(() => {
    const imageKey = `rcktscore.profile-image.${String(session?.username || "").toLowerCase()}`;
    setProfileImage(window.localStorage.getItem(imageKey) || "");
  }, [session?.username]);

  if (showClubWorkspace) {
    return <OrganisationSettingsPage />;
  }

  function selectSection(section) {
    setSearchParams(section === "profile" ? {} : { section }, { replace: true });
  }

  async function saveProfile(event) {
    event.preventDefault();
    setSaving(true);
    setMessage("");
    setError("");
    try {
      const nextEmail = profile.email.trim().toLowerCase();
      const emailChanged = nextEmail !== String(session?.username || "").trim().toLowerCase();
      await updatePersonalProfile(organizationId, { ...profile, email: nextEmail });
      if (emailChanged) {
        window.sessionStorage.setItem("rcktscore.profile-message", `Email updated. Sign in again using ${nextEmail}.`);
        logout();
        navigate("/", { replace: true });
        return;
      }
      setSession({ ...session, ...profile, username: nextEmail, email: nextEmail });
      setEditing(false);
      setMessage("Your profile has been updated across your HitnScore memberships.");
      await loadProfile();
    } catch (requestError) {
      setError(requestError.message || "Unable to update your profile.");
    } finally {
      setSaving(false);
    }
  }

  function chooseProfileImage(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/") || file.size > 2 * 1024 * 1024) {
      setError("Choose an image smaller than 2 MB.");
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      const value = String(reader.result || "");
      const imageKey = `rcktscore.profile-image.${String(session?.username || "").toLowerCase()}`;
      window.localStorage.setItem(imageKey, value);
      setProfileImage(value);
      setMessage("Profile image updated on this browser.");
    };
    reader.readAsDataURL(file);
  }

  return (
    <main className="page-shell stack settings-hub-page">
      <ClubPageHeader />

      <section className="root-admin-tab-row matches-category-switch settings-category-switch" aria-label="Settings sections">
        {SETTINGS_MENU.map((item) => (
          <button className={activeSection === item.id ? "active" : ""} key={item.id} type="button" onClick={() => selectSection(item.id)}>
            {item.label}
          </button>
        ))}
      </section>

      {loading ? <div className="notice">Loading settings...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {!loading && activeSection === "profile" ? (
        <>
          <section className="panel stack settings-hub-profile">
            <div className="settings-hub-profile__heading">
              <div className="settings-profile-photo">
                {profileImage ? <img alt="Profile" src={profileImage} /> : <span>{initials(profile)}</span>}
              </div>
              <div><h2>Profile</h2><p className="helper-text">Your personal HitnScore account details.</p></div>
              <div className="button-row">
                <button className="secondary" type="button" onClick={() => fileInputRef.current?.click()}>Change Image</button>
                <button type="button" onClick={() => setEditing((value) => !value)}>{editing ? "Cancel" : "Edit"}</button>
              </div>
              <input accept="image/*" className="settings-profile-file" ref={fileInputRef} type="file" onChange={chooseProfileImage} />
            </div>
            <p className="field-hint">Profile images are currently stored only in this browser and are not shared across devices.</p>
            <form className="stack" onSubmit={saveProfile}>
              <div className="field-grid settings-profile-grid">
                {[
                  ["first_name", "First Name"], ["surname", "Surname"], ["email", "Email / Username"],
                  ["telephone", "Telephone"], ["city_location", "City / Location"],
                ].map(([field, label]) => (
                  <div className="field" key={field}>
                    <label htmlFor={`settings-profile-${field}`}>{label}</label>
                    <input id={`settings-profile-${field}`} readOnly={!editing} type={field === "email" ? "email" : "text"} value={profile[field]} onChange={(event) => setProfile((current) => ({ ...current, [field]: event.target.value }))} />
                  </div>
                ))}
                <div className="field">
                  <label htmlFor="settings-profile-country">Country</label>
                  <select disabled={!editing} id="settings-profile-country" value={profile.country} onChange={(event) => setProfile((current) => ({ ...current, country: event.target.value }))}>
                    <option value="">Not set</option>
                    {COUNTRIES.map((country) => <option key={country} value={country}>{country}</option>)}
                  </select>
                </div>
              </div>
              {editing ? <div className="button-row"><button disabled={saving} type="submit">{saving ? "Saving..." : "Save Profile"}</button></div> : null}
            </form>
          </section>
          <section className="panel stack">
            <div className="panel-heading"><h2>Club Associations</h2><p className="helper-text">Read-only memberships linked to this sign-in.</p></div>
            {clubMemberships.length ? <div className="settings-association-summary">
              {clubMemberships.map((membership) => <div className="dashboard-item" key={membership.organization_id}><strong>{membership.organization_name}</strong><span>{`Club ${clubRoleLabel(membership.role).toLowerCase()}`} · {planLabel(membership.plan)}</span></div>)}
            </div> : <div className="dashboard-empty">No club associations are linked to this account.</div>}
          </section>
        </>
      ) : null}

      {!loading && activeSection === "associations" ? (
        <section className="panel stack">
          <div className="panel-heading"><h2>Associations</h2><p className="helper-text">Clubs linked to your HitnScore sign-in.</p></div>
          {clubMemberships.length === 0 ? <div className="dashboard-empty">No club associations are linked to this account.</div> : null}
          <div className="settings-association-grid">
            {clubMemberships.map((membership) => {
              const admin = membership.role === "admin";
              const clubQuery = `club=1&organizationId=${encodeURIComponent(membership.organization_id)}`;
              return <article className="settings-association-card" key={membership.organization_id}>
                <div>
                  <span className="status-pill">{`Club ${clubRoleLabel(membership.role).toLowerCase()}`}</span>
                  <h3>{membership.organization_name}</h3>
                  <div className="dashboard-item-meta">
                    <span><strong>Account type:</strong> Club account</span>
                    <span><strong>Subscription:</strong> {planLabel(membership.plan)}</span>
                  </div>
                </div>
                {!admin ? <div className="notice">Club settings are view only for this role. Only organisation admins can change them.</div> : null}
                <div className="settings-association-actions">
                  <button title="Club profile" type="button" onClick={() => navigate(`/settings?${clubQuery}&tab=organisation`)}>⌂<span>Club Profile</span></button>
                  {admin ? <>
                    <button title="Club courts" type="button" onClick={() => navigate(`/settings?${clubQuery}&tab=courts`)}>▦<span>Courts</span></button>
                    <button title="Club users" type="button" onClick={() => navigate(`/settings?${clubQuery}&tab=users`)}>♟<span>Users</span></button>
                    <button title="Club settings" type="button" onClick={() => navigate(`/settings?${clubQuery}&tab=game-social`)}>⚙<span>Settings</span></button>
                  </> : null}
                </div>
              </article>;
            })}
          </div>
        </section>
      ) : null}

      {!loading && activeSection === "subscription" ? (
        <SubscriptionPreview accountEmail={profile.email} currentPlan={identityMembership?.plan || settings?.organization?.plan || "personal_free"} />
      ) : null}

      {!loading && activeSection === "app" ? (
        <section className="panel stack">
          <div className="panel-heading"><h2>App Settings</h2><p className="helper-text">Account access and scoring preferences.</p></div>
          <div className="settings-tile-grid">
            <button className="settings-option-tile" type="button" onClick={() => navigate("/settings?club=1&tab=game-social")}><span className="settings-option-tile__icon">◎</span><span><strong>Racket Sports & Timers</strong><small>View sport access and default match timers for the active association.</small></span><span>›</span></button>
            <button className="settings-option-tile" type="button" onClick={async () => { await requestPasswordReset({ email: profile.email }); setMessage("If that email is registered, a password reset link has been sent."); }}><span className="settings-option-tile__icon">⌁</span><span><strong>Password</strong><small>Send a secure password reset link.</small></span><span>›</span></button>
          </div>
        </section>
      ) : null}

      <AppFooter />
    </main>
  );
}
