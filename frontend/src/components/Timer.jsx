import React from "react";

function formatSeconds(value) {
  const minutes = String(Math.floor(value / 60)).padStart(2, "0");
  const seconds = String(value % 60).padStart(2, "0");
  return `${minutes}:${seconds}`;
}

export default function Timer({
  title = "Timer",
  label = "Match Clock",
  seconds = 0,
  running = false,
  onToggle,
  onReset,
  helperText = "",
}) {
  return (
    <section className="panel match-timer-panel">
      <div className="match-timer-panel__top">
        <div className="match-timer-panel__copy">
          <h2>{title}</h2>
          <div className="match-timer-label">{label}</div>
          {helperText ? <p className="helper-text match-timer-helper">{helperText}</p> : null}
        </div>
        <div className="timer-chip">{formatSeconds(seconds)}</div>
      </div>
      <div className="button-row match-timer-actions">
        <button type="button" onClick={onToggle}>
          {running ? "Pause" : "Start"}
        </button>
        <button
          className="secondary"
          type="button"
          onClick={onReset}
        >
          Reset
        </button>
      </div>
    </section>
  );
}
