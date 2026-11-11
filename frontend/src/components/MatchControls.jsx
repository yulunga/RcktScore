import React, { useState } from "react";

export default function MatchControls({
  match,
  disabled = false,
  undoDisabled = false,
  onEventAction,
  onUndo,
  onEndMatch,
  onOpenSettings,
  showRacketActions = true,
}) {
  const matchComplete = match?.state?.match_complete || match?.status === "completed";
  const [showActionMenu, setShowActionMenu] = useState(false);
  const [showEndMatchConfirm, setShowEndMatchConfirm] = useState(false);
  const [earlyWinner, setEarlyWinner] = useState("");

  const player1Name = [match?.player1_name, match?.player1_surname].filter(Boolean).join(" ") || "Player 1";
  const player2Name = [match?.player2_name, match?.player2_surname].filter(Boolean).join(" ") || "Player 2";

  async function handleConfirmEndMatch() {
    if (!earlyWinner) return;
    await onEndMatch({
      ended_early: true,
      reason: "Ended by operator",
      winner_side: earlyWinner,
    });
    setShowEndMatchConfirm(false);
    setEarlyWinner("");
  }

  async function handleUndo() {
    await onUndo();
    setShowActionMenu(false);
  }

  return (
    <>
      {showEndMatchConfirm ? (
        <div className="overlay-backdrop">
          <div className="overlay-panel overlay-panel--match-confirm stack">
            <h2>End Match Early?</h2>
            <p className="helper-text">Confirm the result that should be recorded.</p>
            <div className="match-confirm-winner" role="radiogroup" aria-label="Early match result">
              <button aria-checked={earlyWinner === "player1"} className={earlyWinner === "player1" ? "active" : ""} role="radio" type="button" onClick={() => setEarlyWinner("player1")}>{player1Name} wins</button>
              <button aria-checked={earlyWinner === "player2"} className={earlyWinner === "player2" ? "active" : ""} role="radio" type="button" onClick={() => setEarlyWinner("player2")}>{player2Name} wins</button>
              <button aria-checked={earlyWinner === "draw"} className={earlyWinner === "draw" ? "active" : ""} role="radio" type="button" onClick={() => setEarlyWinner("draw")}>Draw / no winner</button>
            </div>
            <p className="helper-text match-confirm-warning">
              This cannot be undone.
            </p>
            <div className="button-row match-confirm-actions">
              <button
                className="secondary"
                disabled={disabled}
                type="button"
                onClick={() => {
                  setShowEndMatchConfirm(false);
                  setEarlyWinner("");
                }}
              >
                Cancel
              </button>
              <button
                className="danger"
                disabled={disabled || !earlyWinner}
                type="button"
                onClick={handleConfirmEndMatch}
              >
                End Match
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {showActionMenu ? (
        <div className="overlay-backdrop">
          <div className="overlay-panel overlay-panel--match-actions stack">
            <div className="settings-header-row">
              <h2>Match Actions</h2>
              <button
                aria-label="Close match actions"
                className="help-close-button"
                type="button"
                onClick={() => setShowActionMenu(false)}
              >
                &times;
              </button>
            </div>
            {showRacketActions ? (
              <div className="match-action-decisions">
                <p className="helper-text">Let decision</p>
                <div className="match-action-decisions__row">
                  <button disabled={disabled || matchComplete} type="button" onClick={async () => { await onEventAction("let", { decision: "no_let", note: "No Let" }); setShowActionMenu(false); }}>No Let</button>
                  <button disabled={disabled || matchComplete} type="button" onClick={async () => { await onEventAction("let", { decision: "yes_let", note: "Yes Let" }); setShowActionMenu(false); }}>Yes Let</button>
                </div>
                <p className="helper-text">Stroke awarded to</p>
                <div className="match-action-decisions__row">
                  <button className="danger" disabled={disabled || matchComplete} type="button" onClick={async () => { await onEventAction("stroke", { player_side: "player2" }); setShowActionMenu(false); }}>{player2Name}</button>
                  <button className="danger" disabled={disabled || matchComplete} type="button" onClick={async () => { await onEventAction("stroke", { player_side: "player1" }); setShowActionMenu(false); }}>{player1Name}</button>
                </div>
              </div>
            ) : null}
            <button
              className="match-action-menu__button match-action-menu__button--danger"
              disabled={disabled || matchComplete}
              type="button"
              onClick={() => {
                setShowActionMenu(false);
                setEarlyWinner("");
                setShowEndMatchConfirm(true);
              }}
            >
              <span aria-hidden="true">■</span>
              <span><strong>End Match Early</strong><small>Stop scoring and record the match as ended.</small></span>
            </button>
          </div>
        </div>
      ) : null}

      <div className="match-control-grid">
        <button
          aria-label="Match actions"
          className="secondary match-control-grid__actions"
          disabled={disabled || (matchComplete && undoDisabled)}
          onClick={() => setShowActionMenu(true)}
          title="Match actions"
          type="button"
        >
          <svg aria-hidden="true" className="match-control-grid__actions-icon" viewBox="0 0 24 24">
            <circle cx="12" cy="5.5" r="2.25" fill="none" stroke="currentColor" strokeWidth="1.8" />
            <path d="M5.25 10.25L8 13l4.75-5" fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.8" />
            <path d="M16 9.25l3.5 3.5M19.5 9.25L16 12.75" fill="none" stroke="currentColor" strokeLinecap="round" strokeWidth="1.8" />
            <path d="M7.25 20v-2.25c0-2.35 2.13-4.25 4.75-4.25s4.75 1.9 4.75 4.25V20" fill="none" stroke="currentColor" strokeLinecap="round" strokeWidth="1.8" />
          </svg>
        </button>
        <button
          aria-label="Undo last action"
          className="secondary match-control-grid__undo"
          disabled={disabled || undoDisabled}
          onClick={handleUndo}
          title={undoDisabled ? "Undo is only available for 5 minutes after match completion." : "Undo last action"}
          type="button"
        >
          <svg aria-hidden="true" className="match-control-grid__undo-icon" viewBox="0 0 24 24">
            <path d="M9 7H4v-5M4.8 6.2A9 9 0 1 1 3 13" fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.2" />
          </svg>
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
            <path d="M10.67 2.52a1 1 0 0 1 .99-.82h.68a1 1 0 0 1 .99.82l.33 2.18a7.9 7.9 0 0 1 1.78.74l1.82-1.24a1 1 0 0 1 1.28.12l.48.48a1 1 0 0 1 .12 1.28L17.9 7.9c.28.57.53 1.16.74 1.79l2.18.33a1 1 0 0 1 .82.99v.68a1 1 0 0 1-.82.99l-2.18.33a7.92 7.92 0 0 1-.74 1.78l1.24 1.82a1 1 0 0 1-.12 1.28l-.48.48a1 1 0 0 1-1.28.12l-1.82-1.24a7.9 7.9 0 0 1-1.78.74l-.33 2.18a1 1 0 0 1-.99.82h-.68a1 1 0 0 1-.99-.82l-.33-2.18a7.9 7.9 0 0 1-1.79-.74l-1.82 1.24a1 1 0 0 1-1.28-.12l-.48-.48a1 1 0 0 1-.12-1.28l1.24-1.82a7.9 7.9 0 0 1-.74-1.78l-2.18-.33a1 1 0 0 1-.82-.99v-.68a1 1 0 0 1 .82-.99l2.18-.33c.21-.63.46-1.22.74-1.79L4.86 6.08a1 1 0 0 1 .12-1.28l.48-.48a1 1 0 0 1 1.28-.12L8.56 5.44c.57-.28 1.16-.53 1.79-.74l.32-2.18ZM12 15.75a3.75 3.75 0 1 0 0-7.5 3.75 3.75 0 0 0 0 7.5Z" />
          </svg>
        </button>
      </div>
    </>
  );
}
