import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { useAuth } from "../hooks/useAuth";
import { getDashboard } from "../services/api";

function percentage(value) {
  return value === null || value === undefined ? "Not enough data" : `${value}%`;
}

function duration(seconds = 0) {
  const minutes = Math.round(seconds / 60);
  const hours = Math.floor(minutes / 60);
  return hours ? `${hours}h ${minutes % 60}m` : `${minutes}m`;
}

function sportLabel(sport) {
  if (sport === "padel") return "Padel";
  return sport ? `${sport.charAt(0).toUpperCase()}${sport.slice(1)}` : "Other";
}

function StatCard({ label, value, detail }) {
  return (
    <article className="performance-stat-card">
      <span>{label}</span>
      <strong>{value}</strong>
      {detail ? <small>{detail}</small> : null}
    </article>
  );
}

function NotTracked({ label, reason }) {
  return <StatCard label={label} value="Not tracked" detail={reason || "This activity is not yet attributed in stored match data."} />;
}

function Heatmap({ cells = [], label }) {
  const dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  const maximum = Math.max(1, ...cells.map((cell) => Number(cell.count || 0)));
  return (
    <div className="analytics-heatmap" aria-label={label} role="img">
      {dayLabels.map((day, dayIndex) => (
        <div className="analytics-heatmap__row" key={day}>
          <strong>{day}</strong>
          <div className="analytics-heatmap__cells">
            {Array.from({ length: 24 }, (_, hour) => {
              const count = cells.find((cell) => cell.day === dayIndex && cell.hour === hour)?.count || 0;
              return (
                <span
                  aria-label={`${day} ${String(hour).padStart(2, "0")}:00: ${count} matches`}
                  key={hour}
                  style={{ "--heat-color": `rgba(47, 142, 229, ${0.1 + (count / maximum) * 0.8})` }}
                  title={`${day} ${String(hour).padStart(2, "0")}:00 · ${count}`}
                />
              );
            })}
          </div>
        </div>
      ))}
      <div className="analytics-heatmap__hours" aria-hidden="true"><span>00:00</span><span>06:00</span><span>12:00</span><span>18:00</span><span>23:00</span></div>
    </div>
  );
}

function AnalyticsList({ items, empty = "No recorded activity in this period." }) {
  if (!items?.length) return <p className="helper-text">{empty}</p>;
  return (
    <div className="analytics-list">
      {items.map((item) => (
        <div className="analytics-list__row" key={item.key || item.label}>
          <strong>{item.label}</strong>
          <span>{item.value}</span>
        </div>
      ))}
    </div>
  );
}

function AppAnalytics({ stats, periodDays, setPeriodDays }) {
  const sports = stats.matches_by_sport || [
    { sport: "squash", count: 0 },
    { sport: "racketball", count: 0 },
    { sport: "tennis", count: 0 },
    { sport: "padel", count: 0 },
  ];
  return (
    <section className="panel stack analytics-app-panel">
      <div className="panel-heading panel-heading--with-action analytics-panel-heading">
        <div>
          <h2>App Analytics</h2>
          <p className="helper-text">Match activity recorded by this account during the selected period.</p>
        </div>
        <label className="analytics-period-field" htmlFor="analytics-period">
          <span>Period</span>
          <select id="analytics-period" value={periodDays} onChange={(event) => setPeriodDays(Number(event.target.value))}>
            <option value={30}>Last 30 days</option>
            <option value={90}>Last 90 days</option>
            <option value={365}>Last 12 months</option>
            <option value={0}>All time</option>
          </select>
        </label>
      </div>
      <div className="performance-stat-grid">
        <StatCard label="Matches scored" value={stats.matches_scored || 0} detail="Total matches recorded during this period" />
        <StatCard label="Completed-match rate" value={percentage(stats.completed_match_rate)} detail={`${stats.completed_matches || 0} reached a completed result`} />
        <StatCard label="Abandoned-match rate" value={percentage(stats.abandoned_match_rate)} detail={`${stats.uncompleted_started_matches || 0} started without a completed result`} />
        <StatCard label="Average match duration" value={stats.average_match_duration_seconds ? duration(stats.average_match_duration_seconds) : "Not enough data"} detail="Completed matches with a recorded duration" />
        <StatCard label="Longest match" value={stats.longest_match ? duration(stats.longest_match.duration_seconds) : "Not enough data"} detail={stats.longest_match ? sportLabel(stats.longest_match.sport) : "No valid completed duration"} />
        <StatCard label="Shortest completed match" value={stats.shortest_completed_match ? duration(stats.shortest_completed_match.duration_seconds) : "Not enough data"} detail={stats.shortest_completed_match ? sportLabel(stats.shortest_completed_match.sport) : "Zero-duration records are excluded"} />
      </div>
      <div className="analytics-sport-breakdown stack">
        <div className="panel-heading"><h2>Matches by Sport</h2></div>
        <div className="performance-stat-grid">
          {sports.map((item) => <StatCard key={item.sport} label={sportLabel(item.sport)} value={item.count || 0} />)}
        </div>
      </div>

      <div className="analytics-section-grid">
        <section className="analytics-subpanel stack">
          <div className="panel-heading"><h2>Duration Distribution</h2></div>
          <AnalyticsList items={[
            { label: "Under 30 minutes", value: stats.duration_distribution?.under_30 || 0 },
            { label: "30–60 minutes", value: stats.duration_distribution?.["30_60"] || 0 },
            { label: "60–90 minutes", value: stats.duration_distribution?.["60_90"] || 0 },
            { label: "Over 90 minutes", value: stats.duration_distribution?.over_90 || 0 },
          ]} />
        </section>
        <section className="analytics-subpanel stack">
          <div className="panel-heading"><h2>Returning Usage</h2></div>
          <div className="performance-stat-grid performance-stat-grid--compact">
            <StatCard label="Active weeks" value={stats.returning_usage_weeks || 0} />
            <StatCard label="Average per active day" value={stats.average_matches_per_active_day ?? "Not enough data"} />
            <StatCard label="Average per active week" value={stats.average_matches_per_active_week ?? "Not enough data"} />
          </div>
        </section>
      </div>

      <section className="analytics-subpanel stack">
        <div className="panel-heading"><h2>Hourly Activity Heatmap</h2><p className="helper-text">Match records by day of week and hour.</p></div>
        <Heatmap cells={stats.hourly_activity_heatmap} label="Hourly app match activity" />
      </section>

      <div className="analytics-section-grid">
        <section className="analytics-subpanel stack">
          <div className="panel-heading"><h2>Monthly Scoring Trend</h2></div>
          <AnalyticsList items={(stats.monthly_scoring_trend || []).map((item) => ({ key: item.month, label: item.month, value: `${item.count} matches` }))} />
        </section>
        <section className="analytics-subpanel stack">
          <div className="panel-heading"><h2>Web versus iOS</h2></div>
          {stats.platform_usage?.tracked ? (
            <AnalyticsList items={[
              { label: "Web", value: stats.platform_usage.web || 0 },
              { label: "iOS", value: stats.platform_usage.ios || 0 },
              { label: "Earlier unattributed records", value: stats.platform_usage.unattributed || 0 },
            ]} />
          ) : <NotTracked label="Client platform" reason="Existing match events do not identify whether scoring came from web or iOS." />}
        </section>
      </div>

      <section className="analytics-subpanel stack">
        <div className="panel-heading"><h2>Match Setup and Rules</h2></div>
        <div className="performance-stat-grid">
          {stats.setup_completion?.tracked
            ? <StatCard label="New-match setup completion" value={percentage(stats.setup_completion.rate)} />
            : <NotTracked label="New-match setup completion" reason={stats.setup_completion?.reason} />}
          <StatCard label="Most-used match format" value={stats.most_used_match_format?.label || "Not enough data"} detail={`${stats.most_used_match_format?.count || 0} matches`} />
          <StatCard label="Timed-break usage" value={percentage(stats.timed_break_usage_rate)} />
          <StatCard label="Golden Point usage" value={percentage(stats.golden_point_usage_rate)} />
          <StatCard label="Handicap-match usage" value={percentage(stats.handicap_match_usage_rate)} />
          <StatCard label="Final-set tiebreak usage" value={percentage(stats.final_set_tiebreak_usage_rate)} />
        </div>
      </section>

      <section className="analytics-subpanel stack">
        <div className="panel-heading"><h2>Match Structure and Competitiveness</h2></div>
        <div className="performance-stat-grid">
          <StatCard label="Close-match frequency" value={percentage(stats.close_match_frequency)} />
          <StatCard label="Extra-points frequency" value={percentage(stats.extra_points_frequency)} />
          <StatCard label="Comeback-match frequency" value={percentage(stats.comeback_match_frequency)} />
          <StatCard label="Longest game or set" value={stats.longest_game_or_set ? duration(stats.longest_game_or_set.duration_seconds) : "Not enough data"} detail={stats.longest_game_or_set ? sportLabel(stats.longest_game_or_set.sport) : "No timed game or set"} />
          <StatCard label="Unique participant names" value={stats.unique_participant_names || 0} />
          <StatCard label="Repeat-participant rate" value={percentage(stats.repeat_participant_rate)} />
        </div>
        <div className="analytics-section-grid">
          <div>
            <h3>Average games or sets per match</h3>
            <AnalyticsList items={(stats.average_units_by_sport || []).map((item) => ({ key: item.sport, label: sportLabel(item.sport), value: item.average === null ? "Not enough data" : `${item.average} ${item.unit}` }))} />
          </div>
          <div>
            <h3>Average points per match</h3>
            <AnalyticsList items={(stats.average_points_by_sport || []).map((item) => ({ key: item.sport, label: sportLabel(item.sport), value: item.average ?? "Not enough data" }))} />
          </div>
          <div>
            <h3>Average points per game or set</h3>
            <AnalyticsList items={(stats.average_points_per_unit_by_sport || []).map((item) => ({ key: item.sport, label: sportLabel(item.sport), value: item.average ?? "Not enough data" }))} />
          </div>
        </div>
      </section>
    </section>
  );
}

function BasicPlayerAnalytics({ stats }) {
  return (
    <section className="panel stack">
      <div className="panel-heading"><h2>Your Player Stats</h2><p className="helper-text">Matches are linked by the first name and surname on your user profile.</p></div>
      <div className="performance-stat-grid">
        <StatCard label="Matches played" value={stats.matches_played || 0} />
        <StatCard label="Win percentage" value={percentage(stats.win_percentage)} detail={`${stats.matches_won || 0} won · ${stats.matches_lost || 0} lost`} />
        <StatCard label="Points won" value={stats.points_won || 0} />
        <StatCard label="Playing time" value={duration(stats.playing_time_seconds)} />
        <StatCard label="Average match duration" value={stats.average_match_duration_seconds ? duration(stats.average_match_duration_seconds) : "Not enough data"} />
      </div>
      <div className="analytics-section-grid">
        <div><h3>Your Sports</h3><AnalyticsList items={(stats.sports || []).map((item) => ({ key: item.sport, label: sportLabel(item.sport), value: `${item.matches} matches` }))} /></div>
        <div><h3>Most-played Opponents</h3><AnalyticsList items={(stats.opponents || []).slice(0, 10).map((item) => ({ key: item.name, label: item.name, value: `${item.matches} matches` }))} /></div>
      </div>
    </section>
  );
}

function ClubAnalytics({ stats }) {
  const memberReason = stats.member_activity?.reason;
  return (
    <section className="panel stack analytics-club-panel">
      <div className="panel-heading"><h2>Club Usage Analytics</h2><p className="helper-text">Administrative usage, demand, and court reporting for this club.</p></div>
      <div className="performance-stat-grid">
        <StatCard label="Club matches scored" value={stats.club_matches_scored || 0} />
        <NotTracked label="Active club members" reason={memberReason} />
        <NotTracked label="Member adoption rate" reason={memberReason} />
        <NotTracked label="New member activation" reason={memberReason} />
        <StatCard label="Peak-time concentration" value={percentage(stats.peak_time_concentration)} detail={(stats.peak_hours || []).map((hour) => `${String(hour).padStart(2, "0")}:00`).join(", ") || "Not enough data"} />
        <StatCard label="Off-peak usage" value={stats.off_peak_matches || 0} detail="Matches outside the three busiest hours" />
        <StatCard label="Simultaneous court activity" value={stats.simultaneous_court_activity || 0} detail="Highest overlapping match count" />
      </div>
      <section className="analytics-subpanel stack">
        <div className="panel-heading"><h2>Club Usage Heatmap</h2></div>
        <Heatmap cells={stats.club_usage_heatmap} label="Club match starts by day and hour" />
      </section>
      <section className="analytics-subpanel stack">
        <div className="panel-heading"><h2>Court Usage</h2></div>
        <div className="analytics-table-wrap">
          <table className="analytics-table">
            <thead><tr><th>Court</th><th>Matches</th><th>Court hours</th><th>Sport demand</th></tr></thead>
            <tbody>{(stats.court_usage || []).map((court) => (
              <tr key={court.court}>
                <th>{court.court}</th><td>{court.matches}</td><td>{(court.duration_seconds / 3600).toFixed(1)}</td>
                <td>{(court.sports || []).map((item) => `${sportLabel(item.sport)} ${item.count}`).join(" · ")}</td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      </section>
      <div className="analytics-section-grid">
        <section className="analytics-subpanel stack">
          <div className="panel-heading"><h2>Scheduled-match Demand</h2></div>
          <AnalyticsList items={(stats.scheduled_match_demand || []).map((item, index) => ({ key: `${item.court}-${index}`, label: `${item.day}${item.hour === null ? "" : ` ${String(item.hour).padStart(2, "0")}:00`}`, value: `${sportLabel(item.sport)} · ${item.court}` }))} />
        </section>
        <section className="analytics-subpanel stack">
          <div className="panel-heading"><h2>Sport Popularity Trend</h2></div>
          <AnalyticsList items={(stats.sport_popularity_trend || []).map((item) => ({ key: `${item.month}-${item.sport}`, label: `${item.month} · ${sportLabel(item.sport)}`, value: `${item.count} matches` }))} />
        </section>
        <section className="analytics-subpanel stack">
          <div className="panel-heading"><h2>Premium Club Digest</h2></div>
          <p>{stats.premium_digest}</p>
          <p className="helper-text">Member-based changes will appear once member action attribution is stored.</p>
        </section>
      </div>
    </section>
  );
}

function PlayerAnalytics({ stats }) {
  return (
    <>
      {stats.unclassified_match_count > 0 ? (
        <div className="notice">{stats.unclassified_match_count} match(es) are excluded because your profile name does not exactly match either player.</div>
      ) : null}
      <section className="panel stack">
        <div className="panel-heading"><h2>Player Analytics</h2></div>
        <div className="performance-stat-grid">
          <StatCard label="Win percentage" value={percentage(stats.win_percentage)} detail={`${stats.matches_won || 0} won · ${stats.matches_lost || 0} lost`} />
          <StatCard label="Games won" value={stats.games_won || 0} detail={`${percentage(stats.game_win_percentage)} of recorded games`} />
          <StatCard label="Points won" value={stats.points_won || 0} detail={`${percentage(stats.point_win_percentage)} of recorded points`} />
          <StatCard label="Playing time" value={duration(stats.playing_time_seconds)} detail={`${stats.matches_played || 0} classified matches`} />
          <StatCard label="Close games / sets" value={percentage(stats.close_game_win_percentage)} detail={`${stats.close_games_won || 0} of ${stats.close_games_played || 0} won`} />
          <StatCard label="Current win streak" value={stats.current_win_streak || 0} detail={`Best: ${stats.best_win_streak || 0}`} />
          <StatCard label="Points won on serve" value={percentage(stats.service_point_win_percentage)} detail={`${stats.service_points_won || 0} won · ${stats.service_points_lost || 0} lost`} />
        </div>
      </section>

      <section className="performance-two-column">
        <div className="panel stack">
          <div className="panel-heading"><h2>Progress Summaries</h2></div>
          {[["This week", stats.weekly_summary], ["This month", stats.monthly_summary]].map(([label, summary]) => (
            <article className="performance-list-row" key={label}>
              <strong>{label}</strong>
              <span>{summary?.matches_played || 0} matches · {summary?.matches_won || 0} won · {duration(summary?.playing_time_seconds)}</span>
            </article>
          ))}
          {(stats.monthly_improvement || []).map((item) => (
            <article className="performance-list-row" key={item.sport}>
              <strong>{item.sport}</strong>
              <span>{item.percentage_point_change === null ? "Play in consecutive months to see improvement" : `${item.percentage_point_change > 0 ? "+" : ""}${item.percentage_point_change} percentage points vs last month`}</span>
            </article>
          ))}
        </div>
        <div className="panel stack">
          <div className="panel-heading"><h2>Winning Score Ratios</h2></div>
          {(stats.scoreline_wins || []).length ? stats.scoreline_wins.map((item) => (
            <article className="performance-list-row" key={item.scoreline}><strong>{item.scoreline}</strong><span>{item.count} win(s)</span></article>
          )) : <p className="helper-text">Complete a classified win to see score ratios.</p>}
        </div>
      </section>

      <section className="performance-two-column">
        <div className="panel stack">
          <div className="panel-heading"><h2>By Sport</h2></div>
          {(stats.sports || []).map((item) => (
            <article className="performance-list-row" key={item.sport}><strong>{item.sport}</strong><span>{item.won}-{item.lost} · {percentage(item.win_percentage)} · {duration(item.playing_time_seconds)}</span></article>
          ))}
        </div>
        <div className="panel stack">
          <div className="panel-heading"><h2>Opponents</h2></div>
          {(stats.opponents || []).map((item) => (
            <article className="performance-list-row" key={item.name}><strong>{item.name}</strong><span>{item.won}-{item.lost} · {percentage(item.win_percentage)}</span></article>
          ))}
        </div>
      </section>
    </>
  );
}

export default function PerformancePage() {
  const navigate = useNavigate();
  const { session } = useAuth();
  const [activeTab, setActiveTab] = useState("app");
  const [periodDays, setPeriodDays] = useState(30);
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const isPersonalPlus = (session?.organization_type === "personal" || Number(session?.organization_id) >= 50000)
    && session?.plan === "personal_plus";

  useEffect(() => {
    async function load() {
      if (!session?.organization_id) {
        setLoading(false);
        return;
      }
      setLoading(true);
      setError("");
      try {
        const response = await getDashboard(session.organization_id, {
          activeLimit: 0,
          recentLimit: 0,
          analyticsPeriodDays: periodDays,
        });
        setDashboard(response?.dashboard || null);
      } catch (requestError) {
        setError(requestError.message || "Unable to load analytics.");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [periodDays, session?.organization_id]);

  const appStats = dashboard?.app_analytics || {};
  const playerStats = dashboard?.performance || {};
  const basicPlayerStats = dashboard?.player_analytics;
  const clubStats = dashboard?.club_analytics;
  const isClubAccount = session?.organization_type === "club" && Number(session?.organization_id) < 50000;
  const canSeeClubAnalytics = isClubAccount && session?.role === "admin";
  const analyticsTabs = canSeeClubAnalytics ? ["app", "player", "club"] : ["app", "player"];

  return (
    <main className="page-shell stack">
      <ClubPageHeader />

      <div className="matches-category-switch analytics-category-switch" role="tablist" aria-label="Analytics category">
        {analyticsTabs.map((tab) => (
          <button
            aria-selected={activeTab === tab}
            className={activeTab === tab ? "active" : ""}
            key={tab}
            role="tab"
            type="button"
            onClick={() => setActiveTab(tab)}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </div>

      {loading ? <div className="notice">Loading analytics...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}
      {!loading && !error && activeTab === "app" ? <AppAnalytics stats={appStats} periodDays={periodDays} setPeriodDays={setPeriodDays} /> : null}

      {!loading && !error && activeTab === "player" && !basicPlayerStats ? (
        <section className="panel performance-upgrade-panel">
          <h2>Player analytics are included with Personal+</h2>
          <p>Personal+ adds trends, opponent records, serving performance and progress summaries.</p>
          <button type="button" onClick={() => navigate("/settings")}>View Personal+</button>
        </section>
      ) : null}
      {!loading && !error && activeTab === "player" && basicPlayerStats ? (
        <>
          <BasicPlayerAnalytics stats={basicPlayerStats} />
          {isPersonalPlus ? <PlayerAnalytics stats={playerStats} /> : null}
        </>
      ) : null}

      {!loading && !error && activeTab === "club" && canSeeClubAnalytics && clubStats ? <ClubAnalytics stats={clubStats} /> : null}

      <AppFooter />
    </main>
  );
}
