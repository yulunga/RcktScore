import React from "react";

export default function MatchControls({
  disabled = false,
  onScorePoint,
  onEventAction,
  onUndo,
}) {
  return (
    <section className="panel stack">
      <h2>Match Controls</h2>

      <div className="match-control-grid">
        <button disabled={disabled} onClick={() => onScorePoint("player1")}>
          +1 Player 1
        </button>
        <button disabled={disabled} onClick={() => onScorePoint("player2")}>
          +1 Player 2
        </button>
        <button
          className="secondary"
          disabled={disabled}
          onClick={() => onEventAction("let", { note: "General let" })}
        >
          Let
        </button>
        <button
          className="secondary"
          disabled={disabled}
          onClick={() => onEventAction("stroke", { player_side: "player1" })}
        >
          Stroke P1
        </button>
        <button
          className="secondary"
          disabled={disabled}
          onClick={() => onEventAction("stroke", { player_side: "player2" })}
        >
          Stroke P2
        </button>
        <button
          className="warning"
          disabled={disabled}
          onClick={() => onEventAction("serve_side", { side: "Left" })}
        >
          Serve Left
        </button>
        <button
          className="warning"
          disabled={disabled}
          onClick={() => onEventAction("serve_side", { side: "Right" })}
        >
          Serve Right
        </button>
        <button
          className="danger"
          disabled={disabled}
          onClick={onUndo}
        >
          Undo Last Action
        </button>
      </div>
    </section>
  );
}
