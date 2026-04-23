import React from "react";

export default function MatchControls({
  match,
  disabled = false,
  onEventAction,
  onUndo,
  onEndMatch,
  onOpenSettings,
}) {
  const matchComplete = match?.state?.match_complete || match?.status === "completed";

  return (
    <div className="match-control-grid">
      <button
        className="secondary match-control-grid__stroke-left"
        disabled={disabled || matchComplete}
        onClick={() => onEventAction("stroke", { player_side: "player1" })}
      >
        Stroke P1
      </button>
      <button
        className="secondary match-control-grid__let"
        disabled={disabled || matchComplete}
        onClick={() => onEventAction("let", { note: "General let" })}
      >
        Let
      </button>
      <button
        className="secondary match-control-grid__stroke-right"
        disabled={disabled || matchComplete}
        onClick={() => onEventAction("stroke", { player_side: "player2" })}
      >
        Stroke P2
      </button>
      <button className="danger match-control-grid__undo" disabled={disabled} onClick={onUndo}>
        Undo Last Action
      </button>
      <button
        className="danger match-control-grid__end"
        disabled={disabled || matchComplete}
        onClick={() => onEndMatch({ ended_early: true, reason: "Ended by operator" })}
      >
        End Match Early
      </button>
      <button
        aria-label="Game settings"
        className="secondary match-control-grid__settings"
        disabled={disabled || matchComplete}
        onClick={onOpenSettings}
        title="Game settings"
        type="button"
      >
        <svg aria-hidden="true" className="match-control-grid__settings-icon" viewBox="0 0 24 24">
          <path d="M19.4 13.5c.1-.5.1-1 .1-1.5s0-1-.1-1.5l2-1.5-2-3.5-2.4 1a8 8 0 0 0-2.6-1.5L14 2.5h-4l-.4 2.5A8 8 0 0 0 7 6.5l-2.4-1-2 3.5 2 1.5c-.1.5-.1 1-.1 1.5s0 1 .1 1.5l-2 1.5 2 3.5 2.4-1a8 8 0 0 0 2.6 1.5l.4 2.5h4l.4-2.5a8 8 0 0 0 2.6-1.5l2.4 1 2-3.5-2-1.5ZM12 15.5A3.5 3.5 0 1 1 12 8a3.5 3.5 0 0 1 0 7.5Z" />
        </svg>
      </button>
    </div>
  );
}
