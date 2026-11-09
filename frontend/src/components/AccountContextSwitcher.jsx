import React, { useEffect, useRef, useState } from "react";

import { useAuth } from "../hooks/useAuth";
import { clubRoleLabel } from "../utils/accessControl";

function contextName(membership) {
  if (membership?.organization_type === "personal") {
    return "Personal";
  }
  return membership?.organization_name || "Account";
}

function contextType(membership) {
  if (membership?.organization_type === "personal") {
    return membership?.plan === "personal_plus" ? "Personal Plus" : "Personal Free";
  }
  return `Club ${clubRoleLabel(membership?.role).toLowerCase()}`;
}

export default function AccountContextSwitcher({ className = "", label = "Context", menuIcon = "chevron", onContextChange, onLogout, presentation = "menu" }) {
  const { session, switchOrganization } = useAuth();
  const [open, setOpen] = useState(false);
  const [menuMounted, setMenuMounted] = useState(false);
  const containerRef = useRef(null);
  const memberships = session?.available_memberships || session?.memberships || (session ? [session] : []);
  const menuMemberships = [...memberships].sort((left, right) => {
    const leftPersonal = left?.organization_type === "personal";
    const rightPersonal = right?.organization_type === "personal";
    if (leftPersonal !== rightPersonal) return leftPersonal ? -1 : 1;
    return contextName(left).localeCompare(contextName(right), undefined, { sensitivity: "base" });
  });
  const personalMembershipCount = menuMemberships.filter((membership) => membership?.organization_type === "personal").length;
  const hasClubMemberships = menuMemberships.some((membership) => membership?.organization_type !== "personal");
  const hasChoices = memberships.length > 1;
  const hasMenu = hasChoices || Boolean(onLogout);

  useEffect(() => {
    if (!open) return undefined;
    function closeOnOutsidePress(event) {
      if (!containerRef.current?.contains(event.target)) setOpen(false);
    }
    function closeOnEscape(event) {
      if (event.key === "Escape") setOpen(false);
    }
    document.addEventListener("pointerdown", closeOnOutsidePress);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("pointerdown", closeOnOutsidePress);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [open]);

  useEffect(() => {
    if (open || !menuMounted) return undefined;
    const timer = window.setTimeout(() => setMenuMounted(false), 180);
    return () => window.clearTimeout(timer);
  }, [menuMounted, open]);

  if (!session) return null;

  function choose(membership) {
    if (Number(membership.organization_id) === Number(session.organization_id)) {
      setOpen(false);
      return;
    }
    if (switchOrganization(membership)) {
      setOpen(false);
      onContextChange?.(membership);
    }
  }

  function toggleMenu() {
    if (!hasMenu) return;
    if (open) {
      setOpen(false);
      return;
    }
    setMenuMounted(true);
    window.requestAnimationFrame(() => setOpen(true));
  }

  if (presentation === "choices") {
    const hasPersonalMembership = memberships.some((membership) => membership?.organization_type === "personal");
    return (
      <section className={`account-context-choices ${className}`.trim()} aria-label={label}>
        <p className="account-context-choices__title">{label}</p>
        <div className="account-context-choices__list" role="radiogroup" aria-label={label}>
          {memberships.map((membership) => {
            const active = Number(membership.organization_id) === Number(session.organization_id);
            return (
              <button
                aria-checked={active ? "true" : "false"}
                className={`account-context-choices__option${active ? " active" : ""}`}
                key={`${membership.organization_id}-${membership.id}`}
                role="radio"
                type="button"
                onClick={() => choose(membership)}
              >
                <span className="account-context-choices__icon" aria-hidden="true">
                  {membership.organization_type === "personal" ? "●" : "◆"}
                </span>
                <span className="account-context-choices__copy">
                  <strong>{membership.organization_type === "personal" && membership.plan === "personal_plus" ? "Personal Plus" : contextName(membership)}</strong>
                  <small>{membership.organization_type === "personal" ? "Personal scoring" : "Club scoring"}</small>
                </span>
                <span className="account-context-choices__status" aria-hidden="true">{active ? "✓" : "○"}</span>
              </button>
            );
          })}
        </div>
        {!hasPersonalMembership ? (
          <p className="account-context-choices__note">Personal scoring appears here when this login has an approved Personal account.</p>
        ) : null}
      </section>
    );
  }

  return (
    <div className={`account-context-switcher ${className}`.trim()} ref={containerRef}>
      <button
        aria-expanded={open ? "true" : "false"}
        aria-haspopup={hasMenu ? "menu" : undefined}
        className="account-context-switcher__trigger"
        disabled={!hasMenu}
        title={hasChoices ? "Change active account or club" : (onLogout ? "Account menu" : "Active account")}
        type="button"
        onClick={toggleMenu}
      >
        {label ? <span className="account-context-switcher__label">{label}</span> : null}
        <strong>{contextName(session)}</strong>
        {hasMenu ? (
          menuIcon === "hamburger" ? (
            <span className={`account-context-switcher__expand-icon${open ? " account-context-switcher__expand-icon--open" : ""}`} aria-hidden="true">
              <span />
              <span />
              <span />
            </span>
          ) : <span aria-hidden="true">⌄</span>
        ) : null}
      </button>
      {menuMounted ? (
        <div className={`account-context-switcher__menu${open ? " account-context-switcher__menu--open" : ""}`} role="menu" aria-label="Choose active context">
          {menuMemberships.map((membership, index) => {
            const active = Number(membership.organization_id) === Number(session.organization_id);
            return (
              <React.Fragment key={`${membership.organization_id}-${membership.id}`}>
                {index === personalMembershipCount && personalMembershipCount > 0 && hasClubMemberships ? (
                  <div className="account-context-switcher__group-separator" role="separator" aria-label="Personal and club accounts" />
                ) : null}
                <button
                  aria-current={active ? "true" : undefined}
                  className={active ? "active" : ""}
                  role="menuitem"
                  type="button"
                  onClick={() => choose(membership)}
                >
                  <span><strong>{contextName(membership)}</strong><small>{contextType(membership)}</small></span>
                  <b>{active ? "Current" : "Switch"}</b>
                </button>
              </React.Fragment>
            );
          })}
          {onLogout ? (
            <button className="account-context-switcher__logout" role="menuitem" type="button" onClick={onLogout}>
              <span><strong>Logout</strong><small>Sign out of HitnScore</small></span>
              <b aria-hidden="true">↗</b>
            </button>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
