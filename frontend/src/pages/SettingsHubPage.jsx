import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import SubscriptionPreview from "../components/SubscriptionPreview";
import { clubRoleLabel } from "../utils/accessControl";
import { COUNTRIES } from "../constants/countries";
import { useAuth } from "../hooks/useAuth";
import {
  beginProfileImageUpload,
  completeProfileImageUpload,
  deletePersonalAccount,
  deleteProfileImage,
  getProfileImage,
  getOrganizationSettings,
  requestPasswordReset,
  updatePersonalProfile,
} from "../services/api";
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

const PROFILE_IMAGE_MAX_SOURCE_BYTES = 5 * 1024 * 1024;
const PROFILE_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

async function compressedProfileImage(file) {
  if (!PROFILE_IMAGE_TYPES.has(file.type) || file.size > PROFILE_IMAGE_MAX_SOURCE_BYTES) {
    throw new Error("Choose a JPEG, PNG or WebP image no larger than 5 MB.");
  }
  const bitmap = await createImageBitmap(file);
  if (Math.min(bitmap.width, bitmap.height) < 256) {
    bitmap.close();
    throw new Error("Choose an image that is at least 256 × 256 pixels.");
  }
  const side = Math.min(bitmap.width, bitmap.height);
  const canvas = document.createElement("canvas");
  canvas.width = 512;
  canvas.height = 512;
  const context = canvas.getContext("2d", { alpha: false });
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, 512, 512);
  context.drawImage(
    bitmap,
    (bitmap.width - side) / 2,
    (bitmap.height - side) / 2,
    side,
    side,
    0,
    0,
    512,
    512,
  );
  bitmap.close();
  const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.85));
  if (!blob) throw new Error("Unable to prepare that image.");
  return blob;
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
  const [profileImageBusy, setProfileImageBusy] = useState(false);
  const [deletePanelOpen, setDeletePanelOpen] = useState(false);
  const [deleteConfirmation, setDeleteConfirmation] = useState("");
  const [deletingAccount, setDeletingAccount] = useState(false);
  const fileInputRef = useRef(null);
  const settingsMenuRef = useRef(null);
  const [settingsMenuScroll, setSettingsMenuScroll] = useState({ left: false, right: false });
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
    if (!organizationId) return undefined;
    let active = true;
    getProfileImage(organizationId)
      .then((response) => {
        if (active) setProfileImage(response?.profile_image?.url || "");
      })
      .catch(() => {
        if (active) setProfileImage("");
      });
    return () => { active = false; };
  }, [organizationId]);

  const updateSettingsMenuScroll = useCallback(() => {
    const menu = settingsMenuRef.current;
    if (!menu) return;
    const buttons = Array.from(menu.querySelectorAll("button[data-settings-section]"));
    const menuBounds = menu.getBoundingClientRect();
    const firstBounds = buttons[0]?.getBoundingClientRect();
    const lastBounds = buttons.at(-1)?.getBoundingClientRect();
    const nextState = {
      left: Boolean(firstBounds && firstBounds.left < menuBounds.left - 2),
      right: Boolean(lastBounds && lastBounds.right > menuBounds.right + 2),
    };
    setSettingsMenuScroll((current) => (
      current.left === nextState.left && current.right === nextState.right ? current : nextState
    ));
  }, []);

  useEffect(() => {
    const menu = settingsMenuRef.current;
    if (!menu) return undefined;

    const frameId = window.requestAnimationFrame(updateSettingsMenuScroll);
    const resizeObserver = typeof ResizeObserver === "undefined"
      ? null
      : new ResizeObserver(updateSettingsMenuScroll);
    resizeObserver?.observe(menu);
    Array.from(menu.children).forEach((child) => resizeObserver?.observe(child));
    window.addEventListener("resize", updateSettingsMenuScroll);

    return () => {
      window.cancelAnimationFrame(frameId);
      resizeObserver?.disconnect();
      window.removeEventListener("resize", updateSettingsMenuScroll);
    };
  }, [showClubWorkspace, updateSettingsMenuScroll]);

  useEffect(() => {
    const menu = settingsMenuRef.current;
    const activeButton = menu?.querySelector(`[data-settings-section="${activeSection}"]`);
    if (!menu || !activeButton || menu.scrollWidth <= menu.clientWidth) return undefined;
    const frameId = window.requestAnimationFrame(() => {
      activeButton.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "center" });
    });
    return () => window.cancelAnimationFrame(frameId);
  }, [activeSection, showClubWorkspace]);

  if (showClubWorkspace) {
    return <OrganisationSettingsPage />;
  }

  function selectSection(section) {
    setSearchParams(section === "profile" ? {} : { section }, { replace: true });
  }

  function scrollSettingsMenu(direction) {
    const menu = settingsMenuRef.current;
    if (!menu) return;
    const menuBounds = menu.getBoundingClientRect();
    const buttons = Array.from(menu.querySelectorAll("button[data-settings-section]"));
    const target = direction > 0
      ? buttons.find((button) => button.getBoundingClientRect().right > menuBounds.right + 2)
      : buttons.reverse().find((button) => button.getBoundingClientRect().left < menuBounds.left - 2);

    if (target) {
      target.scrollIntoView({ behavior: "auto", block: "nearest", inline: "center" });
    } else {
      menu.scrollBy({ left: direction * menu.clientWidth * 0.7, behavior: "auto" });
    }
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

  async function chooseProfileImage(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    setProfileImageBusy(true);
    setError("");
    setMessage("");
    try {
      const jpeg = await compressedProfileImage(file);
      const response = await beginProfileImageUpload(organizationId);
      const upload = response?.upload;
      const form = new FormData();
      Object.entries(upload?.fields || {}).forEach(([key, value]) => form.append(key, value));
      form.append("file", jpeg, "profile.jpg");
      const uploaded = await fetch(upload.url, { method: "POST", body: form });
      if (!uploaded.ok) throw new Error("The compressed image could not be uploaded.");
      const completed = await completeProfileImageUpload(organizationId, upload.object_key);
      setProfileImage(completed?.profile_image?.url || "");
      setMessage("Your profile image is now shared across HitnScore clients.");
    } catch (uploadError) {
      setError(uploadError.message || "Unable to update your profile image.");
    } finally {
      setProfileImageBusy(false);
      event.target.value = "";
    }
  }

  async function removeProfileImage() {
    setProfileImageBusy(true);
    setError("");
    setMessage("");
    try {
      await deleteProfileImage(organizationId);
      setProfileImage("");
      setMessage("Your profile image has been removed from every HitnScore client.");
    } catch (requestError) {
      setError(requestError.message || "Unable to remove your profile image.");
    } finally {
      setProfileImageBusy(false);
    }
  }

  async function requestAccountDeletion() {
    if (deleteConfirmation !== "DELETE MY ACCOUNT" || !organizationId || deletingAccount) return;
    setDeletingAccount(true);
    setMessage("");
    setError("");
    try {
      await deletePersonalAccount(organizationId);
      window.sessionStorage.setItem(
        "rcktscore.session-message",
        "Your account is now pending deletion. Access has been disabled and your Personal match data is scheduled for clearing after 12 months.",
      );
      logout();
      navigate("/", { replace: true });
    } catch (requestError) {
      setError(requestError.message || "Unable to request account deletion right now.");
      setDeletingAccount(false);
    }
  }

  return (
    <main className="page-shell stack settings-hub-page">
      <ClubPageHeader />

      <div className={`settings-category-switch-shell${settingsMenuScroll.left || settingsMenuScroll.right ? " settings-category-switch-shell--scrollable" : ""}`}>
        <button
          aria-label="Show previous settings sections"
          className="settings-category-scroll-control settings-category-scroll-control--previous"
          disabled={!settingsMenuScroll.left}
          type="button"
          onClick={() => scrollSettingsMenu(-1)}
        >
          <span aria-hidden="true">&#8249;</span>
        </button>
        <section
          aria-label="Settings sections"
          className="root-admin-tab-row matches-category-switch settings-category-switch"
          ref={settingsMenuRef}
          onScroll={updateSettingsMenuScroll}
        >
          {SETTINGS_MENU.map((item) => (
            <button
              className={activeSection === item.id ? "active" : ""}
              data-settings-section={item.id}
              key={item.id}
              type="button"
              onClick={() => selectSection(item.id)}
            >
              {item.label}
            </button>
          ))}
        </section>
        <button
          aria-label="Show more settings sections"
          className="settings-category-scroll-control settings-category-scroll-control--next"
          disabled={!settingsMenuScroll.right}
          type="button"
          onClick={() => scrollSettingsMenu(1)}
        >
          <span aria-hidden="true">&#8250;</span>
        </button>
      </div>

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
                <button className="secondary" disabled={profileImageBusy} type="button" onClick={() => fileInputRef.current?.click()}>{profileImageBusy ? "Uploading..." : "Change Image"}</button>
                {profileImage ? <button className="secondary" disabled={profileImageBusy} type="button" onClick={removeProfileImage}>Remove Image</button> : null}
                <button type="button" onClick={() => setEditing((value) => !value)}>{editing ? "Cancel" : "Edit"}</button>
              </div>
              <input accept="image/jpeg,image/png,image/webp" className="settings-profile-file" ref={fileInputRef} type="file" onChange={chooseProfileImage} />
            </div>
            <p className="field-hint">JPEG, PNG or WebP up to 5 MB. Images are cropped, compressed and shared securely across your HitnScore clients.</p>
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
          <section className="panel stack settings-delete-account">
            <div className="panel-heading">
              <h2>Delete Personal Account</h2>
              <p className="helper-text">
                Access will be disabled immediately and all devices will be signed out. Your account will remain marked
                as delete pending for 12 months, after which a clearing job permanently removes the Personal workspace,
                Personal matches and their scoring records. Club-owned match records remain with the club.
              </p>
            </div>
            {!deletePanelOpen ? (
              <div className="button-row">
                <button className="danger" type="button" onClick={() => setDeletePanelOpen(true)}>
                  Delete Personal Account
                </button>
              </div>
            ) : (
              <div className="stack compact settings-delete-account__confirm">
                <strong>This request cannot be reversed through the app.</strong>
                <div className="field">
                  <label htmlFor="settings-delete-account-confirmation">
                    Type DELETE MY ACCOUNT to confirm
                  </label>
                  <input
                    autoComplete="off"
                    id="settings-delete-account-confirmation"
                    value={deleteConfirmation}
                    onChange={(event) => setDeleteConfirmation(event.target.value)}
                  />
                </div>
                <div className="button-row">
                  <button
                    className="danger"
                    disabled={deleteConfirmation !== "DELETE MY ACCOUNT" || deletingAccount}
                    type="button"
                    onClick={requestAccountDeletion}
                  >
                    {deletingAccount ? "Requesting Deletion..." : "Confirm Account Deletion"}
                  </button>
                  <button
                    className="secondary"
                    disabled={deletingAccount}
                    type="button"
                    onClick={() => {
                      setDeletePanelOpen(false);
                      setDeleteConfirmation("");
                    }}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}
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
