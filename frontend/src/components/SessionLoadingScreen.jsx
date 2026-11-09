import React from "react";

export default function SessionLoadingScreen() {
  return (
    <main className="session-loading-screen" aria-busy="true" aria-live="polite">
      <div className="session-loading-screen__brand">
        <img src="/branding/logo/brand-logo.png" alt="" />
        <div className="session-loading-screen__wordmark" aria-label="HitnScore">
          <span>Hit</span><span>n</span><span>Score</span>
        </div>
      </div>
      <div className="session-loading-screen__progress" aria-hidden="true" />
      <p>Restoring your session…</p>
    </main>
  );
}
