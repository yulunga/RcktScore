import React from "react";

export default function PublicAccessHeader({ label, children = null }) {
  return (
    <header className="public-access-header">
      <a className="public-access-header__brand" href="https://www.hitnscore.com/" aria-label="HitNScore home">
        <img src="/branding/logo/brand-logo.png" alt="" />
        <span className="public-access-header__brand-stack">
          <strong aria-label="HitnScore">
            <span>Hit</span><i>n</i><span>Score</span>
          </strong>
          <small>{label}</small>
        </span>
      </a>
      {children ? <div className="public-access-header__controls">{children}</div> : null}
    </header>
  );
}
