import React, { useState } from "react";
import { Bar, BarChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";

const monthShort = new Intl.DateTimeFormat("en-GB", { month: "short", timeZone: "UTC" });
const monthFull = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });
const formatMonth = (month, formatter) => formatter.format(new Date(`${month}-01T00:00:00Z`));

export default function RootAdminMonthlyCard({ title, count, note, metric, series, onOpen }) {
  const [showChart, setShowChart] = useState(false);

  return (
    <div className="meta-item root-admin-monthly-card">
      <strong>{title}</strong>
      <button
        type="button"
        className="root-admin-monthly-toggle"
        aria-label={`Monthly chart for ${title}`}
        aria-pressed={showChart}
        title={showChart ? "Show total" : "Show monthly chart"}
        onClick={() => setShowChart((visible) => !visible)}
      >
        <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d={showChart ? "M5 6h14M5 12h14M5 18h14" : "M4 3v17h17M8 16v-4m5 4V8m5 8V5"} />
        </svg>
      </button>
      {showChart ? (
        <div className="root-admin-monthly-chart" aria-label={`${title} over the last 12 months`}>
          {series?.length ? (
            <ResponsiveContainer width="100%" height={92}>
              <BarChart data={series} margin={{ top: 4, right: 8, bottom: 0, left: 0 }} accessibilityLayer>
                <XAxis dataKey="month" tickFormatter={(month) => formatMonth(month, monthShort)} fontSize={10} minTickGap={4} />
                <YAxis allowDecimals={false} width={24} fontSize={10} />
                <Tooltip labelFormatter={(month) => formatMonth(month, monthFull)} />
                <Bar dataKey={metric} name={title} fill="#1769c9" radius={[2, 2, 0, 0]} isAnimationActive={false} />
              </BarChart>
            </ResponsiveContainer>
          ) : <span className="helper-text">Monthly counts unavailable</span>}
        </div>
      ) : (
        <>
          <button type="button" className="root-admin-summary-count" onClick={onOpen} aria-label={`Open ${title}, ${count} total`}>
            {count}
          </button>
          <span className="root-admin-summary-note">{note}</span>
        </>
      )}
    </div>
  );
}
