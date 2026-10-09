import React, { useEffect, useState } from "react";
import { useLocation } from "react-router-dom";

import {
  ANALYTICS_CONSENT_EVENT,
  OPEN_COOKIE_SETTINGS_EVENT,
  getAnalyticsConsent,
  initializeAnalytics,
  setAnalyticsConsent,
  trackPageView,
} from "../services/analytics";

export default function CookieConsent() {
  const { pathname } = useLocation();
  const [consent, setConsent] = useState(() => getAnalyticsConsent());
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);

  useEffect(() => {
    if (consent === "granted") {
      initializeAnalytics();
      trackPageView(pathname);
    }
  }, [consent, pathname]);

  useEffect(() => {
    const handleConsentChange = (event) => setConsent(event.detail);
    const handleOpenSettings = () => setSettingsOpen(true);

    window.addEventListener(ANALYTICS_CONSENT_EVENT, handleConsentChange);
    window.addEventListener(OPEN_COOKIE_SETTINGS_EVENT, handleOpenSettings);
    return () => {
      window.removeEventListener(ANALYTICS_CONSENT_EVENT, handleConsentChange);
      window.removeEventListener(OPEN_COOKIE_SETTINGS_EVENT, handleOpenSettings);
    };
  }, []);

  const chooseConsent = (value) => {
    setAnalyticsConsent(value);
    setConsent(value);
    setDetailsOpen(false);
    setSettingsOpen(false);
  };

  if (consent !== null && !settingsOpen) {
    return null;
  }

  return (
    <section className="cookie-consent" aria-labelledby="cookie-consent-title" aria-live="polite">
      <div className="cookie-consent__brand" aria-hidden="true">
        <img src="/branding/logo/brand-logo.png" alt="" />
      </div>
      <div className="cookie-consent__copy">
        <h2 id="cookie-consent-title">Your privacy choices</h2>
        <p>
          We use essential storage to remember your choices and keep this app working. Optional Google Analytics
          will only be used if you allow it. Read our <a href="/help?section=privacy">privacy information</a>.
        </p>
        <button
          className="cookie-consent__details-trigger"
          type="button"
          aria-expanded={detailsOpen}
          aria-controls="cookie-consent-details"
          onClick={() => setDetailsOpen((currentValue) => !currentValue)}
        >
          {detailsOpen ? "Hide details" : "Show details"}
          <span aria-hidden="true">⌄</span>
        </button>
        <div className="cookie-consent__details" id="cookie-consent-details" hidden={!detailsOpen}>
          <div>
            <strong>Essential</strong>
            <span>Always active</span>
            <p>Stores your consent choice and supports secure sign-in and core app behaviour.</p>
          </div>
          <div>
            <strong>Optional analytics</strong>
            <span>Off until allowed</span>
            <p>
              Google Analytics helps us understand useful pages, device types and general engagement. We exclude
              names, email addresses, account identifiers, match identifiers and public draw keys.
            </p>
          </div>
        </div>
      </div>
      <div className="cookie-consent__actions">
        <button className="cookie-consent__allow" type="button" onClick={() => chooseConsent("granted")}>
          Allow all
        </button>
        <button className="cookie-consent__essential" type="button" onClick={() => chooseConsent("denied")}>
          Essential only
        </button>
      </div>
    </section>
  );
}
