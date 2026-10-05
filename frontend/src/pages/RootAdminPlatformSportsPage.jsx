import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { MATCH_SPORT_OPTIONS, normalizeEnabledSports } from "../constants/matchSports";
import { useRootAdmin } from "../hooks/useRootAdmin";
import {
  getRootAdminPlatformSports,
  previewRootAdminPlatformSports,
  updateRootAdminPlatformSports,
} from "../services/api";

function sportList(values) {
  if (!values.length) return "None";
  return values
    .map((value) => MATCH_SPORT_OPTIONS.find((sport) => sport.value === value)?.label || value)
    .join(", ");
}

export default function RootAdminPlatformSportsPage() {
  const navigate = useNavigate();
  const { session } = useRootAdmin();
  const [webSports, setWebSports] = useState(() => normalizeEnabledSports());
  const [iosSports, setIosSports] = useState(() => normalizeEnabledSports());
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [preview, setPreview] = useState(null);
  const [affectedOrganizationCount, setAffectedOrganizationCount] = useState(0);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function loadPlatformSports() {
    setLoading(true);
    setError("");
    try {
      const response = await getRootAdminPlatformSports();
      const platformSports = response.platformSports || {};
      setWebSports(normalizeEnabledSports(platformSports.enabled_sports_web ?? platformSports.enabled_sports));
      setIosSports(normalizeEnabledSports(platformSports.enabled_sports_ios ?? platformSports.enabled_sports));
      setAffectedOrganizationCount(platformSports.affected_organization_count || 0);
    } catch (requestError) {
      setError(requestError.message || "Failed to load platform racket sports.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadPlatformSports();
  }, []);

  function toggleSport(client, sportValue) {
    setPreview(null);
    const setter = client === "ios" ? setIosSports : setWebSports;
    setter((current) => (
      current.includes(sportValue)
        ? current.filter((value) => value !== sportValue)
        : [...current, sportValue]
    ));
  }

  async function showAffectedUsers() {
    setPreviewLoading(true);
    setMessage("");
    setError("");
    try {
      const response = await previewRootAdminPlatformSports({
        enabled_sports_web: webSports,
        enabled_sports_ios: iosSports,
      });
      setPreview(response.platformSportsPreview || null);
    } catch (requestError) {
      setError(requestError.message || "Failed to preview affected users.");
    } finally {
      setPreviewLoading(false);
    }
  }

  async function savePlatformSports(applyToAll) {
    const affectedText = preview
      ? `${preview.user_count} users across ${preview.membership_count} memberships`
      : "all user memberships";
    const confirmationMessage = applyToAll
      ? `Apply these settings to ${affectedText}?\n\nWeb: ${sportList(webSports)}\niOS: ${sportList(iosSports)}\n\nAll active user sessions will be signed out.`
      : `Save these platform availability settings?\n\nWeb: ${sportList(webSports)}\niOS: ${sportList(iosSports)}\n\nExisting club and user selections will not be changed.`;
    const confirmed = window.confirm(confirmationMessage);
    if (!confirmed) {
      return;
    }
    setSaving(true);
    setMessage("");
    setError("");
    try {
      const response = await updateRootAdminPlatformSports({
        enabled_sports: [...new Set([...webSports, ...iosSports])],
        enabled_sports_web: webSports,
        enabled_sports_ios: iosSports,
        updated_by: session?.username || "Root Admin",
        apply_to_all: applyToAll,
      });
      const platformSports = response.platformSports || {};
      setWebSports(normalizeEnabledSports(platformSports.enabled_sports_web ?? platformSports.enabled_sports));
      setIosSports(normalizeEnabledSports(platformSports.enabled_sports_ios ?? platformSports.enabled_sports));
      setAffectedOrganizationCount(platformSports.affected_organization_count || 0);
      setPreview(null);
      setMessage(applyToAll
        ? "Platform availability was saved and applied to every club and user. Active sessions were signed out."
        : "Platform availability was saved. Club and user access was not changed; assign sports from the relevant club or User Account page.");
    } catch (requestError) {
      setError(requestError.message || "Failed to update platform racket sports.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

      <section className="hero-card stack compact">
        <div className="root-admin-section-header">
          <div>
            <h1>RacketSports</h1>
            <p className="helper-text">
              Control which racket sports are globally available to all users and clubs for scoring.
            </p>
          </div>
          <div className="button-row root-admin-actions">
            <button type="button" className="secondary" onClick={() => navigate("/rckscoreAdmin/dashboard")}>
              Back to Platform Control Centre
            </button>
          </div>
        </div>
      </section>

      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      <section className="panel stack">
        <div className="root-admin-section-header">
          <h2>Platform Sports Controls</h2>
          <div className="button-row root-admin-actions">
            <button type="button" className="secondary" onClick={showAffectedUsers} disabled={saving || loading || previewLoading}>
              {previewLoading ? "Loading Users..." : "Preview Bulk Apply"}
            </button>
            <button type="button" className="secondary" onClick={() => savePlatformSports(true)} disabled={saving || loading}>
              Apply to All Users & Clubs
            </button>
            <button type="button" onClick={() => savePlatformSports(false)} disabled={saving || loading}>
              {saving ? "Saving..." : "Save Platform Availability"}
            </button>
          </div>
        </div>

        <div className="meta-grid root-admin-interest-summary">
          <div className="meta-item">
            <strong>Enabled Sports</strong>
            <div>{new Set([...webSports, ...iosSports]).size}</div>
          </div>
          <div className="meta-item">
            <strong>Clubs Updated by Last Bulk Apply</strong>
            <div>{affectedOrganizationCount}</div>
          </div>
        </div>

        <p className="helper-text">
          Save Platform Availability changes only which sports may be assigned on each client. It does not grant access to any club or user. Assign access later from club settings or individual User Account profiles. Bulk apply remains available when every existing account should receive the same selection.
        </p>

        {loading ? <div className="notice">Loading platform sport controls...</div> : null}

        <div className="sport-grid">
          {MATCH_SPORT_OPTIONS.map((sport) => {
            const webEnabled = webSports.includes(sport.value);
            const iosEnabled = iosSports.includes(sport.value);
            const enabled = webEnabled || iosEnabled;
            return (
              <article
                key={sport.value}
                className={`sport-option${enabled ? " active" : " disabled"}`}
              >
                <strong>{sport.label}</strong>
                <span>{enabled ? "Available on at least one client" : "Disabled everywhere"}</span>
                <p>{sport.note}</p>
                <div className="button-row">
                  <button type="button" className={webEnabled ? "secondary" : ""} disabled={loading || saving} onClick={() => toggleSport("web", sport.value)}>
                    Web: {webEnabled ? "On" : "Off"}
                  </button>
                  <button type="button" className={iosEnabled ? "secondary" : ""} disabled={loading || saving} onClick={() => toggleSport("ios", sport.value)}>
                    iOS: {iosEnabled ? "On" : "Off"}
                  </button>
                </div>
              </article>
            );
          })}
        </div>

        {preview ? (
          <section className="stack root-admin-platform-sports-preview">
            <div className="root-admin-section-header">
              <div>
                <h3>Affected Users</h3>
                <p className="helper-text">
                  {preview.user_count} users across {preview.membership_count} memberships will receive the selections shown below.
                </p>
              </div>
              <button type="button" className="secondary" onClick={() => setPreview(null)}>Hide Preview</button>
            </div>
            <div className="dashboard-list">
              {(preview.users || []).map((user) => (
                <article className="dashboard-item" key={user.username}>
                  <div className="dashboard-item-head">
                    <strong>{[user.first_name, user.surname].filter(Boolean).join(" ") || user.username}</strong>
                    <span>{user.username}</span>
                  </div>
                  {(user.memberships || []).map((membership) => (
                    <div className="dashboard-item-meta" key={membership.id}>
                      <span>{membership.organization_type === "personal" ? "Personal Account" : membership.organization_name}</span>
                      <span>Web: {sportList(membership.enabled_sports_web || [])}</span>
                      <span>iOS: {sportList(membership.enabled_sports_ios || [])}</span>
                      <span>Status: {membership.status}</span>
                    </div>
                  ))}
                </article>
              ))}
              {(preview.users || []).length === 0 ? <div className="dashboard-empty">No users will be affected.</div> : null}
            </div>
          </section>
        ) : null}
      </section>

      <AppFooter />
    </main>
  );
}
