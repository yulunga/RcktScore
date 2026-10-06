(function () {
  const header = document.getElementById("landing-header");
  const cookiePanel = document.getElementById("cookie-panel");
  const detailsTrigger = document.querySelector(".cookie-details-trigger");
  const details = document.getElementById("cookie-details");
  const cookieSettings = document.querySelector("[data-cookie-settings]");
  const appStorePreview = document.querySelector("[data-app-store-preview]");
  const consentKey = "hitnscore_cookie_consent";

  function updateHeader() {
    header?.classList.toggle("landing-header--compact", window.scrollY > 48);
  }

  function showCookiePanel() {
    cookiePanel?.classList.add("cookie-panel--visible");
  }

  function hideCookiePanel() {
    cookiePanel?.classList.remove("cookie-panel--visible");
  }

  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  try {
    const storedConsent = window.localStorage.getItem(consentKey);
    if (storedConsent === "all") {
      window.hitnscoreEnableAnalytics?.();
    } else if (!storedConsent) {
      window.setTimeout(showCookiePanel, 350);
    }
  } catch (_error) {
    showCookiePanel();
  }

  document.querySelectorAll("[data-cookie-choice]").forEach((button) => {
    button.addEventListener("click", () => {
      const choice = button.dataset.cookieChoice || "essential";
      try {
        window.localStorage.setItem(consentKey, choice);
      } catch (_error) {
        // The preference still applies for this page view if storage is unavailable.
      }
      if (choice === "all") {
        window.hitnscoreEnableAnalytics?.();
      } else {
        window.hitnscoreDisableAnalytics?.();
      }
      hideCookiePanel();
    });
  });

  detailsTrigger?.addEventListener("click", () => {
    const expanded = detailsTrigger.getAttribute("aria-expanded") === "true";
    detailsTrigger.setAttribute("aria-expanded", String(!expanded));
    detailsTrigger.firstChild.textContent = expanded ? "Show details " : "Hide details ";
    if (details) details.hidden = expanded;
  });

  cookieSettings?.addEventListener("click", showCookiePanel);

  appStorePreview?.addEventListener("click", (event) => {
    event.preventDefault();
  });
}());
