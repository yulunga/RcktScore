import React from "react";

export default function PublicSiteFooter() {
  return (
    <footer className="public-site-footer">
      <a className="public-site-footer__brand" href="https://www.hitnscore.com/" aria-label="HitNScore home">
        <img src="/branding/logo/brand-logo.png" alt="" />
        <span><b>Hit</b><i>n</i><b>Score</b></span>
      </a>

      <p>Racket-sport scoring for players and clubs.</p>

      <a
        className="public-site-footer__app-store-badge"
        href="#app-store-coming-soon"
        onClick={(event) => event.preventDefault()}
        aria-label="HitNScore on the App Store, coming soon"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 20.94c1.5 0 2.75 1.04 3.8 1.04 1.27 0 2.68-.66 3.66-2.25-3.34-1.58-3.98-6.27-.57-8.15-1.04-1.3-2.5-2.06-3.88-2.06-1.15 0-2.45.45-3.1.45-.69 0-1.73-.43-2.79-.41-1.53.02-2.95.89-3.74 2.26-1.61 2.79-.41 6.9 1.15 9.17.76 1.1 1.66 2.32 2.85 2.28 1.15-.05 1.59-.74 2.98-.74 1.38 0 1.78.74 3 .71Z" />
          <path d="M15 6.5c.67-.84 1.13-2 1-3.15-1 .04-2.21.67-2.92 1.5-.64.73-1.2 1.9-1.05 3.02 1.12.09 2.3-.55 2.97-1.37Z" />
        </svg>
        <span><small>Coming soon on the</small><strong>App Store</strong></span>
      </a>

      <nav aria-label="Footer navigation">
        <a href="/tournament-draw">Tournament draw</a>
        <a href="/scoreboard">Scoreboard display</a>
        <a href="/help">Help &amp; feedback</a>
        <a href="/help?section=privacy">Privacy &amp; terms</a>
        <a href="/help?section=cookies">Cookie settings</a>
      </nav>
    </footer>
  );
}
