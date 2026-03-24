import React from "react";

export default function MatchControls({
  match,
  disabled = false,
  onEventAction,
  onUndo,
  onEndMatch,
  onBackToMatches,
}) {
  const matchComplete = match?.state?.match_complete || match?.status === "completed";

  return (
    <div className="match-control-grid">
        <button
          className="secondary"
          disabled={disabled || matchComplete}
          onClick={() => onEventAction("let", { note: "General let" })}
        >
          Let
        </button>
        <button
          className="secondary"
          disabled={disabled || matchComplete}
          onClick={() => onEventAction("stroke", { player_side: "player1" })}
        >
          Stroke P1
        </button>
        <button
          className="secondary"
          disabled={disabled || matchComplete}
          onClick={() => onEventAction("stroke", { player_side: "player2" })}
        >
          Stroke P2
        </button>
        <button className="danger" disabled={disabled} onClick={onUndo}>
          Undo Last Action
        </button>
        <button
          className="danger"
          disabled={disabled || matchComplete}
          onClick={() => onEndMatch({ ended_early: true, reason: "Ended by operator" })}
        >
          End Match Early
        </button>
        <button className="secondary" type="button" onClick={onBackToMatches}>
          Back to All Matches
        </button>
    </div>
  );
}
