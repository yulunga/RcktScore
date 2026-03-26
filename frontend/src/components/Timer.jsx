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
  onSkip,
  skipLabel = "",
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
        <button
          className={`timer-chip timer-chip--button${running ? "" : " timer-chip--paused"}`}
          type="button"
          onClick={onToggle}
        >
          {formatSeconds(seconds)}
        </button>
      </div>
      {skipLabel && onSkip ? (
        <div className="match-timer-actions">
          <button className="secondary" type="button" onClick={onSkip}>
            {skipLabel}
          </button>
        </div>
      ) : null}
    </section>
  );
}
