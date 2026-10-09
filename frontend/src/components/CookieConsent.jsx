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
    setSettingsOpen(false);
  };

  if (consent !== null && !settingsOpen) {
    return null;
  }

  return (
    <section className="cookie-consent" aria-label="Cookie preferences" aria-live="polite">
      <div>
        <strong>{settingsOpen ? "Cookie preferences" : "Help us improve HitnScore"}</strong>
        <p>
          We use optional Google Analytics cookies to understand which pages and features are useful. We do not
          send names, email addresses, match identifiers or public draw keys. You can change this choice later.
        </p>
        <a href="/help?section=cookies">Read our Cookie Policy</a>
      </div>
      <div className="cookie-consent__actions">
        <button type="button" className="secondary" onClick={() => chooseConsent("denied")}>
          Reject analytics
        </button>
        <button type="button" onClick={() => chooseConsent("granted")}>
          Accept analytics
        </button>
      </div>
    </section>
  );
}
