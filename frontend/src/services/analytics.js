const DEFAULT_MEASUREMENT_ID = "G-30V1YTPY1F";

export const ANALYTICS_CONSENT_STORAGE_KEY = "hitnscore.analytics-consent";
export const ANALYTICS_CONSENT_EVENT = "hitnscore:analytics-consent-changed";
export const OPEN_COOKIE_SETTINGS_EVENT = "hitnscore:open-cookie-settings";

let analyticsInitialized = false;
let lastTrackedPath = null;

function measurementId() {
  return import.meta.env.VITE_GOOGLE_ANALYTICS_ID || DEFAULT_MEASUREMENT_ID;
}

export function getAnalyticsConsent() {
  try {
    const storedValue = window.localStorage.getItem(ANALYTICS_CONSENT_STORAGE_KEY);
    return storedValue === "granted" || storedValue === "denied" ? storedValue : null;
  } catch {
    return null;
  }
}

export function setAnalyticsConsent(value) {
  if (value !== "granted" && value !== "denied") {
    return;
  }

  try {
    window.localStorage.setItem(ANALYTICS_CONSENT_STORAGE_KEY, value);
  } catch {
    // A blocked storage API should not prevent the visitor using the app.
  }

  if (typeof window.gtag === "function") {
    window.gtag("consent", "update", {
      analytics_storage: value,
      ad_storage: "denied",
      ad_user_data: "denied",
      ad_personalization: "denied",
    });
  }

  window.dispatchEvent(new CustomEvent(ANALYTICS_CONSENT_EVENT, { detail: value }));
}

export function initializeAnalytics() {
  if (analyticsInitialized || getAnalyticsConsent() !== "granted") {
    return;
  }

  analyticsInitialized = true;
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function gtag() {
    window.dataLayer.push(arguments);
  };

  window.gtag("consent", "default", {
    analytics_storage: "granted",
    ad_storage: "denied",
    ad_user_data: "denied",
    ad_personalization: "denied",
  });
  window.gtag("js", new Date());
  window.gtag("config", measurementId(), {
    send_page_view: false,
    allow_google_signals: false,
    allow_ad_personalization_signals: false,
  });

  const script = document.createElement("script");
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(measurementId())}`;
  script.dataset.hitnscoreAnalytics = "true";
  document.head.appendChild(script);
}

export function sanitizeAnalyticsPath(pathname) {
  const path = pathname || "/";
  const privateRoutePatterns = [
    [/^\/settings\/users\/[^/]+\/?$/, "/settings/users/:userId"],
    [/^\/tournaments\/[^/]+\/?$/, "/tournaments/:tournamentId"],
    [/^\/tournament-draw\/[^/]+\/?$/, "/tournament-draw/:accessKey"],
    [/^\/match\/[^/]+\/history\/?$/, "/match/:matchId/history"],
    [/^\/match\/(?!new(?:\/|$))[^/]+\/?$/, "/match/:matchId"],
    [/^\/rckscoreAdmin\/clubs\/[^/]+\/?$/, "/rckscoreAdmin/clubs/:organizationId"],
    [/^\/rckscoreAdmin\/users\/[^/]+\/?$/, "/rckscoreAdmin/users/:userId"],
  ];

  const match = privateRoutePatterns.find(([pattern]) => pattern.test(path));
  return match ? match[1] : path;
}

export function trackPageView(pathname) {
  if (getAnalyticsConsent() !== "granted") {
    return;
  }

  const pagePath = sanitizeAnalyticsPath(pathname);
  if (pagePath === lastTrackedPath) {
    return;
  }

  initializeAnalytics();
  lastTrackedPath = pagePath;
  window.gtag("event", "page_view", {
    page_path: pagePath,
    page_location: `${window.location.origin}${pagePath}`,
    page_referrer: "",
    page_title: document.title,
  });
}
