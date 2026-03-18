import React from "react";

export default function MatchControls({
  match,
  disabled = false,
  onScorePoint,
  onEventAction,
  onUndo,
  onEndMatch,
  onBackToMatches,
}) {
  const matchComplete = match?.state?.match_complete || match?.status === "completed";

  return (
    <section className="panel stack">
      <h2>Match Controls</h2>
      <p className="helper-text">
        Use the squash controls below to record rallies, update serve side if needed, undo the last action, or end
        the match early.
      </p>

      <div className="match-control-grid">
        <button disabled={disabled || matchComplete} onClick={() => onScorePoint("player1")}>
          +1 Player 1
        </button>
        <button disabled={disabled || matchComplete} onClick={() => onScorePoint("player2")}>
          +1 Player 2
        </button>
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
        <button
          className="warning"
          disabled={disabled || matchComplete}
          onClick={() => onEventAction("serve_side", { side: "Left" })}
        >
          Serve Left
        </button>
        <button
          className="warning"
          disabled={disabled || matchComplete}
          onClick={() => onEventAction("serve_side", { side: "Right" })}
        >
          Serve Right
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
    </section>
  );
}
