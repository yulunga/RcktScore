import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { MATCH_SPORT_OPTIONS, normalizeEnabledSports } from "../constants/matchSports";
import { useRootAdmin } from "../hooks/useRootAdmin";
import {
  getRootAdminPlatformSports,
  updateRootAdminPlatformSports,
} from "../services/api";

export default function RootAdminPlatformSportsPage() {
  const navigate = useNavigate();
  const { session } = useRootAdmin();
  const [enabledSports, setEnabledSports] = useState(() => normalizeEnabledSports());
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [affectedOrganizationCount, setAffectedOrganizationCount] = useState(0);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function loadPlatformSports() {
    setLoading(true);
    setError("");
    try {
      const response = await getRootAdminPlatformSports();
      const platformSports = response.platformSports || {};
      setEnabledSports(normalizeEnabledSports(platformSports.enabled_sports));
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

  function toggleSport(sportValue) {
    setEnabledSports((current) => (
      current.includes(sportValue)
        ? current.filter((value) => value !== sportValue)
        : [...current, sportValue]
    ));
  }

  async function savePlatformSports() {
    setSaving(true);
    setMessage("");
    setError("");
    try {
      const response = await updateRootAdminPlatformSports({
        enabled_sports: enabledSports,
        updated_by: session?.username || "Root Admin",
      });
      const platformSports = response.platformSports || {};
      setEnabledSports(normalizeEnabledSports(platformSports.enabled_sports));
      setAffectedOrganizationCount(platformSports.affected_organization_count || 0);
      setMessage("Platform racket sports updated for all users and clubs.");
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
            <button type="button" onClick={savePlatformSports} disabled={saving || loading}>
              {saving ? "Saving..." : "Save for All Users & Clubs"}
            </button>
          </div>
        </div>

        <div className="meta-grid root-admin-interest-summary">
          <div className="meta-item">
            <strong>Enabled Sports</strong>
            <div>{enabledSports.length}</div>
          </div>
          <div className="meta-item">
            <strong>Updated Clubs & Users</strong>
            <div>{affectedOrganizationCount}</div>
          </div>
        </div>

        <p className="helper-text">
          Saving here updates the platform default and applies the same allowed racket-sport list across every club and personal account.
        </p>

        {loading ? <div className="notice">Loading platform sport controls...</div> : null}

        <div className="sport-grid">
          {MATCH_SPORT_OPTIONS.map((sport) => {
            const enabled = enabledSports.includes(sport.value);
            return (
              <article
                key={sport.value}
                className={`sport-option${enabled ? " active" : " disabled"}`}
              >
                <strong>{sport.label}</strong>
                <span>{enabled ? "Enabled" : "Disabled"}</span>
                <p>{sport.note}</p>
                <button
                  type="button"
                  className={enabled ? "secondary" : ""}
                  disabled={loading || saving}
                  onClick={() => toggleSport(sport.value)}
                >
                  {enabled ? "Disable" : "Enable"}
                </button>
              </article>
            );
          })}
        </div>
      </section>

      <AppFooter />
    </main>
  );
}
