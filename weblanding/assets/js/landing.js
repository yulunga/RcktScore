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

  // Parallax: expose each section's scroll progress (0 entering → .5 filling the screen → 1 leaving) as --p.
  const parallaxSections = Array.from(document.querySelectorAll("[data-parallax]"));
  const reduceMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)");
  let parallaxQueued = false;

  function updateParallax() {
    parallaxQueued = false;
    const viewport = window.innerHeight || 1;
    parallaxSections.forEach((section) => {
      if (reduceMotion?.matches) {
        section.style.setProperty("--p", "0.5");
        return;
      }
      const rect = section.getBoundingClientRect();
      if (rect.bottom < -viewport || rect.top > viewport * 2) return;
      const progress = (viewport - rect.top) / (viewport + rect.height);
      section.style.setProperty("--p", Math.min(1, Math.max(0, progress)).toFixed(4));
    });
  }

  function queueParallax() {
    if (parallaxQueued) return;
    parallaxQueued = true;
    window.requestAnimationFrame(updateParallax);
  }

  if (parallaxSections.length) {
    updateParallax();
    window.addEventListener("scroll", queueParallax, { passive: true });
    window.addEventListener("resize", queueParallax);
  }

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
