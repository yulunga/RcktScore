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

  async function handleConfirmEndMatch() {
    await onEndMatch({ ended_early: true, reason: "Ended by operator" });
    setShowEndMatchConfirm(false);
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
            <p className="helper-text">
              This will end the current match now. Continue only if you are sure.
            </p>
            <p className="helper-text match-confirm-warning">
              This cannot be undone.
            </p>
            <div className="button-row match-confirm-actions">
              <button
                className="secondary"
                disabled={disabled}
                type="button"
                onClick={() => setShowEndMatchConfirm(false)}
              >
                Cancel
              </button>
              <button
                className="danger"
                disabled={disabled}
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
            <button
              className="match-action-menu__button"
              disabled={disabled || undoDisabled}
              title={undoDisabled ? "Undo is only available for 5 minutes after match completion." : undefined}
              type="button"
              onClick={handleUndo}
            >
              <span aria-hidden="true">↶</span>
              <span><strong>Undo Last Action</strong><small>Remove the most recent scoring action.</small></span>
            </button>
            <button
              className="match-action-menu__button match-action-menu__button--danger"
              disabled={disabled || matchComplete}
              type="button"
              onClick={() => {
                setShowActionMenu(false);
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
        {showRacketActions ? <button
          className="secondary match-control-grid__stroke-left"
          disabled={disabled || matchComplete}
          onClick={() => onEventAction("stroke", { player_side: "player1" })}
        >
          Stroke P1
        </button> : null}
        {showRacketActions ? <button
          className="secondary match-control-grid__let"
          disabled={disabled || matchComplete}
          onClick={() => onEventAction("let", { note: "General let" })}
        >
          Let
        </button> : null}
        {showRacketActions ? <button
          className="secondary match-control-grid__stroke-right"
          disabled={disabled || matchComplete}
          onClick={() => onEventAction("stroke", { player_side: "player2" })}
        >
          Stroke P2
        </button> : null}
        <button
          aria-label="Match actions"
          className="secondary match-control-grid__actions"
          disabled={disabled || (matchComplete && undoDisabled)}
          onClick={() => setShowActionMenu(true)}
          title="Match actions"
          type="button"
        >
          <svg aria-hidden="true" className="match-control-grid__actions-icon" viewBox="0 0 24 24">
            <circle cx="12" cy="5" r="2" />
            <circle cx="12" cy="12" r="2" />
            <circle cx="12" cy="19" r="2" />
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
