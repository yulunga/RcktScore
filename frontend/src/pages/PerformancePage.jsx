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

function StatCard({ label, value, detail }) {
  return (
    <article className="performance-stat-card">
      <span>{label}</span>
      <strong>{value}</strong>
      {detail ? <small>{detail}</small> : null}
    </article>
  );
}

export default function PerformancePage() {
  const navigate = useNavigate();
  const { session } = useAuth();
  const [performance, setPerformance] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const isPersonalPlus = (session?.organization_type === "personal" || Number(session?.organization_id) >= 50000)
    && session?.plan === "personal_plus";

  useEffect(() => {
    async function load() {
      if (!session?.organization_id || !isPersonalPlus) {
        setLoading(false);
        return;
      }
      try {
        const response = await getDashboard(session.organization_id, { activeLimit: 0, recentLimit: 0 });
        setPerformance(response?.dashboard?.performance || null);
      } catch (requestError) {
        setError(requestError.message || "Unable to load performance statistics.");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [isPersonalPlus, session?.organization_id]);

  if (!isPersonalPlus) {
    return (
      <main className="page-shell stack">
        <ClubPageHeader title="Performance" subtitle="Advanced personal match statistics." />
        <section className="panel performance-upgrade-panel">
          <h2>Performance is included with Personal+</h2>
          <p>Upgrade to unlock trends, opponent records, serving performance and progress summaries.</p>
          <button type="button" onClick={() => navigate("/settings")}>View Personal+</button>
        </section>
        <AppFooter />
      </main>
    );
  }

  const stats = performance || {};
  return (
    <main className="page-shell stack">
      <ClubPageHeader
        title="Performance"
        subtitle="Your results, playing patterns and progress across every retained match."
        actions={[{ label: "Matches", onClick: () => navigate("/matches") }, { label: "History", onClick: () => navigate("/history") }]}
      />
      {loading ? <div className="notice">Loading performance...</div> : null}
      {error ? <div className="notice error">{error}</div> : null}
      {!loading && !error ? (
        <>
          {stats.unclassified_match_count > 0 ? (
            <div className="notice">{stats.unclassified_match_count} match(es) are excluded because your profile name does not exactly match either player.</div>
          ) : null}
          <section className="panel stack">
            <div className="panel-heading"><h2>Performance Dashboard</h2></div>
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
              {[['This week', stats.weekly_summary], ['This month', stats.monthly_summary]].map(([label, summary]) => (
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
      ) : null}
      <AppFooter />
    </main>
  );
}
