import React, { useEffect, useState } from "react";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import RootAdminSettingsNav from "../components/RootAdminSettingsNav";
import { getRootAdminDashboard, updateRootAdminTournamentFeature } from "../services/api";

export default function RootAdminTournamentsPage() {
  const [clubs, setClubs] = useState(null);
  const [saving, setSaving] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let current = true;
    getRootAdminDashboard().then(
      (response) => { if (current) setClubs(response.rootAdminDashboard.organizations); },
      (failure) => { if (current) setError(failure.message); },
    );
    return () => { current = false; };
  }, []);

  async function toggleAccess(club) {
    const enabled = !club.tournament_enabled;
    setSaving(club.id);
    setError("");
    try {
      await updateRootAdminTournamentFeature(club.id, enabled);
      setClubs((previous) => previous.map((row) =>
        row.id === club.id ? { ...row, tournament_enabled: enabled } : row,
      ));
    } catch (failure) {
      setError(failure.message);
    } finally {
      setSaving(null);
    }
  }

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />
      <RootAdminSettingsNav />
      <section className="panel stack">
        <h1>Tournament Manager</h1>
        <p className="helper-text">{clubs?.filter((club) => club.tournament_enabled).length ?? "—"} clubs enabled</p>
        {error ? <div className="notice error" role="alert">{error}</div> : null}
        {!clubs && !error ? <div className="notice">Loading clubs…</div> : null}
        {clubs?.length === 0 ? <div className="dashboard-empty">No clubs found.</div> : null}
        {clubs?.map((club) => (
          <article className="dashboard-item root-admin-section-header" key={club.id}>
            <strong>{club.organization_name}</strong>
            <span className="helper-text">{club.tournament_enabled ? "Enabled" : "Disabled"}</span>
            <button
              className={club.tournament_enabled ? "secondary" : ""}
              type="button"
              disabled={saving !== null}
              onClick={() => toggleAccess(club)}
              aria-label={`${club.tournament_enabled ? "Disable" : "Enable"} Tournament Manager for ${club.organization_name}`}
            >
              {saving === club.id ? "Saving…" : club.tournament_enabled ? "Disable" : "Enable"}
            </button>
          </article>
        ))}
      </section>
      <AppFooter />
    </main>
  );
}
