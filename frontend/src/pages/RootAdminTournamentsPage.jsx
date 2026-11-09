import React, { useEffect, useState } from "react";

import RootAdminSwitch from "../components/RootAdminSwitch";
import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import RootAdminSettingsNav from "../components/RootAdminSettingsNav";
import { getRootAdminDashboard, updateRootAdminTournamentFeature } from "../services/api";

const TOURNAMENT_STATUS = {
  registration: "Registration open",
  draw_published: "Draw published",
  in_progress: "In progress",
};
const tournamentDate = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeZone: "UTC" });

function ClubTournamentActivity({ club }) {
  const activity = club.tournament_activity;
  return (
    <details className="stack compact">
      <summary>{club.organization_name}</summary>
      {activity ? (
        <>
          <p className="helper-text">Completed tournaments: <strong>{activity.completed_count}</strong></p>
          <h2>Current tournaments</h2>
          {activity.current_events.length ? (
            <ul className="stack compact">
              {activity.current_events.map((event) => (
                <li key={event.id}>
                  <strong>{event.name}</strong>
                  <div className="helper-text">
                    <span style={{ textTransform: "capitalize" }}>{event.sport}</span>
                    {" · "}{TOURNAMENT_STATUS[event.status]}
                    {event.starts_on ? ` · ${tournamentDate.format(new Date(event.starts_on))}` : ""}
                    {event.ends_on && event.ends_on !== event.starts_on ? ` – ${tournamentDate.format(new Date(event.ends_on))}` : ""}
                  </div>
                </li>
              ))}
            </ul>
          ) : <p className="helper-text">No current tournaments.</p>}
        </>
      ) : <p className="helper-text">Tournament activity is unavailable.</p>}
    </details>
  );
}

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
          <article className="dashboard-item root-admin-club-tournament-row" key={club.id}>
            <ClubTournamentActivity club={club} />
            <RootAdminSwitch
              label={`Tournament Manager for ${club.organization_name}`}
              checked={Boolean(club.tournament_enabled)}
              disabled={saving !== null}
              onChange={() => toggleAccess(club)}
            >
              {saving === club.id ? "Saving…" : club.tournament_enabled ? "Enabled" : "Disabled"}
            </RootAdminSwitch>
          </article>
        ))}
      </section>
      <AppFooter />
    </main>
  );
}
