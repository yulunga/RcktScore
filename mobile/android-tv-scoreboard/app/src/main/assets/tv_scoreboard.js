// HitnScore TV Scoreboard: adjustments the TV app makes to the web scoreboard page.
// Runs at document start (before the page's own code), so the polling change below can
// take effect. Nothing here changes the web scoreboard in a browser.
//
// 1. Faster live updates: while a match is being scored the page refreshes every second
//    instead of every 5 s (and stays at 5 s when the court is idle).
// 2. No Refresh button on the TV (updates are automatic).
// 3. Compact header (smaller logo, name and Layout menu).
// 4. All Games layout: the court's own match keeps the main area; other courts are a
//    narrow column of small cards on the right instead of covering it.
// 5. Fit to screen with no scrolling (below).
//
// Fit to screen:
// The web page is laid out for browsers; on a TV (often 960x540 CSS px at 1080p) parts of it
// can run off the bottom. This scales the whole page down until everything fits the screen,
// re-checks whenever the page changes (pairing screen -> live scoreboard), and turns off
// scrolling. It never scales above 100%, so screens that already fit are untouched.
(function () {
  if (window.__hnsFitInstalled) return;
  window.__hnsFitInstalled = true;

  var FAST_MS = 1000;

  // A match is on this court and being scored (not the idle "waiting" card).
  function isLiveMatch() {
    return !!document.querySelector(
      ".display-session-active > .scoreboard-card:not(.scoreboard-card--idle)"
    );
  }

  // 1. The page polls the scoreboard with setInterval(poll, poll_interval_seconds * 1000),
  //    5 s by default. Intervals of 3–15 s are run on a 1 s tick instead: they fire every
  //    second while a match is live, otherwise at their own delay. Other timers (the 1 s
  //    countdown, 2 s pairing check, 5 min All Games page rotation) are left alone.
  var nativeSetInterval = window.setInterval.bind(window);
  var nativeClearInterval = window.clearInterval.bind(window);
  window.setInterval = function (callback, delay) {
    var args = Array.prototype.slice.call(arguments, 2);
    if (typeof callback !== "function" || !(delay >= 3000 && delay <= 15000)) {
      return nativeSetInterval.apply(window, arguments);
    }
    var last = Date.now();
    return nativeSetInterval(function () {
      var now = Date.now();
      var due = isLiveMatch() ? FAST_MS : delay;
      if (now - last >= due - 50) {
        last = now;
        callback.apply(window, args);
      }
    }, FAST_MS);
  };
  window.clearInterval = nativeClearInterval;

  // Keep the court pairing when the TV app restarts or the stick reboots. The web page keeps
  // it in sessionStorage, which a browser tab keeps but the app loses on restart, so it is
  // mirrored to localStorage and put back before the page starts. Change Court (or an
  // expired pairing) removes both.
  var PAIRING_KEY = "rcktscore.scoreboardDisplay";
  var BACKUP_KEY = "hns.tv.scoreboardDisplay";
  try {
    var backup = window.localStorage.getItem(BACKUP_KEY);
    if (backup && !window.sessionStorage.getItem(PAIRING_KEY)) window.sessionStorage.setItem(PAIRING_KEY, backup);
    var storageProto = Object.getPrototypeOf(window.sessionStorage);
    var nativeSetItem = storageProto.setItem;
    var nativeRemoveItem = storageProto.removeItem;
    storageProto.setItem = function (key, value) {
      nativeSetItem.call(this, key, value);
      if (this === window.sessionStorage && key === PAIRING_KEY) nativeSetItem.call(window.localStorage, BACKUP_KEY, value);
    };
    storageProto.removeItem = function (key) {
      nativeRemoveItem.call(this, key);
      if (this === window.sessionStorage && key === PAIRING_KEY) nativeRemoveItem.call(window.localStorage, BACKUP_KEY);
    };
  } catch (ignored) {}

  // Change Court must win over a scoreboard update that is still on its way. With updates
  // every second one is nearly always in flight, and when it arrived after the click it
  // reconnected the court, so the button seemed to do nothing. Updates requested before the
  // click (or in the next few seconds) are now dropped instead of applied.
  var changeCourtAt = 0;
  var nativeFetch = window.fetch ? window.fetch.bind(window) : null;
  if (nativeFetch) {
    window.fetch = function (input, init) {
      var url = typeof input === "string" ? input : (input && input.url) || "";
      if (url.indexOf("/scoreboard_display/current") === -1) return nativeFetch(input, init);
      var startedAt = Date.now();
      if (startedAt - changeCourtAt < 3000) return new Promise(function () {});
      return nativeFetch(input, init).then(function (response) {
        if (changeCourtAt >= startedAt) return new Promise(function () {});
        return response;
      });
    };
  }
  document.addEventListener("click", function (event) {
    var button = event.target && event.target.closest ? event.target.closest("button") : null;
    if (!button) return;
    var label = (button.textContent || "").trim();
    if (label === "Change Court" || label === "Use Different Code") changeCourtAt = Date.now();
  }, true);

  // 2. Hide the header's Refresh button (keep "Use Different Code" and Layout).
  function hideRefreshButton() {
    var buttons = document.querySelectorAll(".display-header-card__actions button");
    for (var i = 0; i < buttons.length; i++) {
      var label = (buttons[i].textContent || "").trim();
      if (label === "Refresh" || label === "Refreshing...") buttons[i].style.display = "none";
      // Clearer name on a TV.
      if (label === "Use Different Code") buttons[i].textContent = "Change Court";
    }
  }

  // 3. Compact header on every layout: smaller logo, name and controls.
  var HEADER_CSS =
    ".display-shell.display-session-active{gap:8px!important;padding-top:8px!important;padding-bottom:8px!important;" +
      "height:100vh!important;min-height:100vh!important;}" +
    ".display-shell.display-session-active.display-mode-standard," +
    ".display-shell.display-session-active.display-mode-large-scores," +
    ".display-shell.display-session-active.display-mode-minimal{grid-template-rows:44px minmax(0,1fr)!important;}" +
    ".display-shell .public-access-header{height:44px!important;min-height:44px!important;max-height:44px!important;" +
      "padding:0 12px!important;gap:8px!important;}" +
    ".display-shell .public-access-header__brand{gap:6px!important;}" +
    ".display-shell .public-access-header__brand > img{width:28px!important;height:28px!important;}" +
    ".display-shell .public-access-header__brand-stack > strong{font-size:1rem!important;line-height:1.1!important;}" +
    ".display-shell .public-access-header__brand-stack small{font-size:0.5rem!important;letter-spacing:0.08em!important;}" +
    ".display-shell .public-access-header .button-row{gap:6px!important;}" +
    ".display-shell .public-access-header .button-row button{min-height:28px!important;padding:4px 10px!important;font-size:0.7rem!important;}" +
    ".display-shell .display-layout-control{gap:6px!important;font-size:0.7rem!important;}" +
    ".display-shell .display-layout-control__label{font-size:0.7rem!important;}" +
    ".display-shell .display-layout-control select{min-height:28px!important;height:28px!important;padding:2px 26px 2px 10px!important;" +
      "font-size:0.75rem!important;border-width:1px!important;}";

  // 3b. Scoreboard: no point timeline between the two players (just the two score cards),
  //     and no thin blue line along the top of the header.
  var SCORE_CSS =
    ".display-shell .scoreboard-point-strip-wrap{display:none!important;}" +
    ".display-shell .scoreboard-grid{grid-template-columns:minmax(0,1fr) minmax(0,1fr)!important;}" +
    ".display-shell .public-access-header{border-top:0!important;}" +
    // All Games: no game-scores row under this court's score (the side panel has the other
    // courts). The other layouts keep it: each finished game's score and its winner.
    // Large Scores (web value "standard") also leaves the game-results row out.
    ".display-mode-all-games .scoreboard-history-strip,.display-mode-standard .scoreboard-history-strip{display:none!important;}" +
    // Standard and Large Scores: the game-scores row always sits at the bottom of the score
    // card, in view. The players' score area takes whatever height is left, so big scores
    // can't push the row off the screen.
    ".display-mode-standard > .scoreboard-card,.display-mode-large-scores > .scoreboard-card{" +
      "display:grid!important;grid-template-rows:auto minmax(0,1fr) auto!important;overflow:hidden!important;}" +
    ".display-mode-standard > .scoreboard-card .scoreboard-grid,.display-mode-large-scores > .scoreboard-card .scoreboard-grid{" +
      "min-height:0!important;overflow:hidden!important;}" +
    ".display-mode-large-scores .scoreboard-history-strip{" +
      "display:flex!important;flex-wrap:nowrap!important;gap:8px!important;margin:0!important;overflow:hidden!important;}" +
    ".display-mode-large-scores .scoreboard-history-strip .meta-item--compact{" +
      "padding:4px 10px!important;font-size:0.8rem!important;white-space:nowrap!important;}";

  // 3c. Large-scores layout (shown as "Standard Scores" on the TV): the court name, small,
  //     right at the top of the score card with the match details on the same line; bigger
  //     score numbers; each player's name on one line, shrunk to fit (see fitPlayerNames).
  var LARGE_CSS =
    ".display-mode-large-scores .scoreboard-card{padding-top:8px!important;gap:8px!important;}" +
    ".display-mode-large-scores .scoreboard-header{display:flex!important;flex-direction:row!important;" +
      "justify-content:flex-start!important;align-items:center!important;gap:12px!important;margin:0!important;" +
      "min-height:0!important;flex-wrap:nowrap!important;}" +
    ".display-mode-large-scores .scoreboard-header h2{font-size:1rem!important;line-height:1.2!important;margin:0!important;white-space:nowrap!important;}" +
    ".display-mode-large-scores .scoreboard-header-meta{margin:0!important;flex-wrap:nowrap!important;}" +
    ".display-mode-large-scores .scoreboard-header .score-series-chip{font-size:0.75rem!important;padding:3px 10px!important;" +
      "min-height:0!important;white-space:nowrap!important;}" +
    ".display-mode-large-scores .player-score{font-size:clamp(7rem,34vh,22rem)!important;line-height:0.95!important;}" +
    // Names: first name and surname on one line in every layout.
    ".display-shell .player-name-stack{display:flex!important;flex-direction:row!important;flex-wrap:nowrap!important;" +
      "gap:0.3em!important;white-space:nowrap!important;overflow:hidden!important;max-width:100%!important;min-width:0!important;}" +
    ".display-shell .player-name-stack h3{white-space:nowrap!important;margin:0!important;}";

  // Shrinks a player's name until the whole name fits on its one line.
  function fitPlayerNames() {
    var stacks = document.querySelectorAll(".display-shell .player-name-stack");
    for (var i = 0; i < stacks.length; i++) {
      var stack = stacks[i];
      stack.style.fontSize = "";
      var size = parseFloat(window.getComputedStyle(stack.querySelector("h3") || stack).fontSize) || 24;
      var names = stack.querySelectorAll("h3");
      for (var j = 0; j < names.length; j++) names[j].style.fontSize = "";
      var guard = 0;
      while (stack.scrollWidth > stack.clientWidth + 1 && size > 10 && guard < 40) {
        size = size * 0.92;
        for (var k = 0; k < names.length; k++) names[k].style.fontSize = size + "px";
        guard++;
      }
    }
  }

  // Layout menu names on the TV: "large-scores" is called Standard Scores and "standard"
  // is called Large Scores (the stored layout values are unchanged).
  // Menu order on the TV: Standard Scores, Large Scores, All Games, then anything else.
  var LAYOUT_ORDER = ["large-scores", "standard", "all-games"];
  function renameLayouts() {
    var select = document.querySelector(".display-layout-control select");
    if (!select) return;
    var options = select.querySelectorAll("option");
    for (var i = 0; i < options.length; i++) {
      if (options[i].value === "standard" && options[i].textContent !== "Large Scores") options[i].textContent = "Large Scores";
      if (options[i].value === "large-scores" && options[i].textContent !== "Standard Scores") options[i].textContent = "Standard Scores";
    }
    // Reorder only when the order is wrong. (Moving options on every check made the page
    // change itself, re-check, and move them again, every frame: the flicker.)
    var wanted = [];
    for (var j = 0; j < LAYOUT_ORDER.length; j++) {
      var option = select.querySelector('option[value="' + LAYOUT_ORDER[j] + '"]');
      if (option) wanted.push(option);
    }
    var inOrder = true;
    for (var k = 0; k < wanted.length; k++) {
      if (select.options[k] !== wanted[k]) { inOrder = false; break; }
    }
    if (!inOrder) {
      for (var n = wanted.length - 1; n >= 0; n--) select.insertBefore(wanted[n], select.firstChild);
    }
  }

  // Landing page (before a court is paired), TV version:
  //   "Open a Scoreboard" / "Pair this screen with the HitnScore Scoring App",
  //   then the QR code centred, the display-code box under it, and Refresh QR centred under
  //   that. The web page shows QR and code on separate tabs; the code box here fills in the
  //   page's own Enter Code form and submits it, so pairing works exactly as on the web.
  var PAIRING_CSS =
    ".hns-qr-mode .scoreboard-entry-tabs{display:none!important;}" +
    ".hns-qr-mode .scoreboard-pairing .hns-hide{display:none!important;}" +
    ".scoreboard-entry-card .panel-heading{text-align:center!important;}" +
    ".scoreboard-pairing{display:flex!important;flex-direction:column!important;align-items:center!important;gap:14px!important;}" +
    ".scoreboard-pairing .scoreboard-shell__actions{justify-content:center!important;width:100%!important;}" +
    "#hns-code-entry{display:flex;gap:10px;align-items:center;justify-content:center;}" +
    "#hns-code-entry input{width:16ch;text-align:center;letter-spacing:0.12em;font-size:1.05rem;padding:10px 14px;" +
      "border-radius:14px;border:1px solid rgba(18,116,208,0.35);text-transform:uppercase;}" +
    ".hns-qr-mode .scoreboard-pairing .scoreboard-shell__actions{display:none!important;}" +
    ".scoreboard-pairing__qr{position:relative!important;}" +
    ".hns-qr-overlay{position:absolute;inset:0;display:flex;padding:10px;border-radius:20px;" +
      "background:rgba(255,255,255,0.7);}" +
    "#hns-qr-slot{width:252px;height:252px;display:flex;padding:10px;box-sizing:border-box;border-radius:20px;}" +
    // The whole square is one light, bright button holding the message.
    ".hns-qr-refresh{flex:1;display:flex;align-items:center;justify-content:center;text-align:center;" +
      "padding:16px;border-radius:16px;border:2px solid #1274d0;background:#e9f4ff;color:#0b5fb3;" +
      "font-size:1.1rem;font-weight:800;line-height:1.3;box-shadow:0 8px 24px rgba(18,116,208,0.18);cursor:pointer;}" +
    ".hns-qr-refresh:focus,.hns-qr-refresh:hover{background:#d6ebff;outline:3px solid #f5b301;outline-offset:2px;}" +
    ".hns-qr-refresh:disabled{opacity:0.7;}" +
    // Fixed order and sizes on the pairing panel, whatever the page re-renders: QR (or the
    // Refresh square) first, then the countdown line, then the display-code box. The code
    // box therefore never moves when the QR code expires.
    ".hns-qr-mode .scoreboard-pairing > *{order:9;}" +
    ".hns-qr-mode .scoreboard-pairing > .scoreboard-pairing__qr,.hns-qr-mode .scoreboard-pairing > #hns-qr-slot{order:1;}" +
    ".hns-qr-mode .scoreboard-pairing > #hns-qr-countdown{order:2;height:1.6em;line-height:1.6em;}" +
    ".hns-qr-mode .scoreboard-pairing > #hns-code-entry{order:3;}" +
    // Active QR: light green frame. Expired: light red (below).
    ".hns-qr-mode .scoreboard-pairing__qr{background:#ecfbf1!important;border:2px solid #2fa866!important;" +
      "box-shadow:0 8px 24px rgba(47,168,102,0.18)!important;box-sizing:border-box!important;}" +
    ".hns-qr-mode .scoreboard-pairing__qr.hns-expired{background:#fdecec!important;border-color:#d64545!important;" +
      "box-shadow:0 8px 24px rgba(214,69,69,0.18)!important;}" +
    ".hns-qr-refresh{flex-direction:column!important;gap:4px;}" +
    ".hns-qr-line1,.hns-qr-line2{display:block;white-space:nowrap;}" +
    ".hns-qr-line2{font-size:0.9em;font-weight:700;}" +
    // Expired: the QR square turns light red (Preparing… stays blue).
    ".hns-qr-refresh:not(:disabled){border-color:#d64545;background:#fdecec;color:#b42318;box-shadow:0 8px 24px rgba(214,69,69,0.18);}" +
    ".hns-qr-refresh:not(:disabled):focus,.hns-qr-refresh:not(:disabled):hover{background:#fbd5d5;}" +
    ".hns-qr-overlay{background:rgba(253,236,236,0.75)!important;}" +
    "#hns-qr-countdown{margin:0;color:#486581;font-size:1rem;font-weight:700;font-variant-numeric:tabular-nums;}" +
    "#hns-code-entry input::placeholder{letter-spacing:0.04em;text-transform:none;}";

  function submitDisplayCode(value) {
    var code = (value || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
    if (code.length !== 12) return;
    var tabs = document.querySelectorAll(".scoreboard-entry-tabs button");
    for (var i = 0; i < tabs.length; i++) {
      if ((tabs[i].textContent || "").trim() === "Enter Code") tabs[i].click();
    }
    // Wait for the page to show its code form, type the code into it, then submit it.
    var tries = 0;
    (function fill() {
      var input = document.getElementById("scoreboard_code");
      if (!input) {
        if (tries++ < 40) setTimeout(fill, 50);
        return;
      }
      var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
      setter.call(input, code);
      input.dispatchEvent(new Event("input", { bubbles: true }));
      setTimeout(function () {
        var form = input.form;
        if (form && form.requestSubmit) form.requestSubmit();
        else if (form) form.querySelector("button[type=submit]").click();
      }, 80);
    })();
  }

  // QR code on the TV: each code shows a 10:00 countdown (10:00, 9:59 …). At 0:00 the QR
  // is covered by a "Refresh" overlay; pressing it fetches a new code and the countdown
  // starts again. Nothing refreshes by itself, and the page's own Refresh QR button and
  // seconds countdown are hidden, so the page stays still. If there is no code (still
  // loading, or the server expired it) the same square shows "Refresh" or "Preparing…".
  var QR_SHOW_MS = 10 * 60 * 1000;
  var qrKey = "";
  var qrShownAt = 0;
  var qrTicker = null;
  var qrSize = null; // last QR box size, so the Refresh square takes exactly the same space

  function pageRefreshButton(pairing) {
    var buttons = pairing.querySelectorAll(".scoreboard-shell__actions button");
    for (var i = 0; i < buttons.length; i++) {
      var label = (buttons[i].textContent || "").trim();
      if (label === "Refresh QR" || label === "Preparing…" || label === "Preparing...") return buttons[i];
    }
    return null;
  }

  // "QR expired" on the first line, "Click to refresh" on the next.
  function setExpiredText(button) {
    button.textContent = "";
    var line1 = document.createElement("span");
    line1.className = "hns-qr-line1";
    line1.textContent = "QR expired";
    var line2 = document.createElement("span");
    line2.className = "hns-qr-line2";
    line2.textContent = "Click to refresh";
    button.appendChild(line1);
    button.appendChild(line2);
  }

  function refreshButton(pairing) {
    var button = document.createElement("button");
    button.type = "button";
    button.className = "hns-qr-refresh";
    setExpiredText(button);
    button.addEventListener("click", function () {
      var page = pageRefreshButton(pairing);
      if (page && !page.disabled) page.click();
    });
    return button;
  }

  function qrPanel(pairing) {
    var pageCountdowns = pairing.querySelectorAll(".scoreboard-pairing__countdown");
    for (var c = 0; c < pageCountdowns.length; c++) {
      if (pageCountdowns[c].style.display !== "none") pageCountdowns[c].style.display = "none";
    }
    var qr = pairing.querySelector(".scoreboard-pairing__qr");
    var own = document.getElementById("hns-qr-countdown");
    var slot = document.getElementById("hns-qr-slot");
    var page = pageRefreshButton(pairing);
    var preparing = !!(page && page.disabled);

    if (!qr) {
      // No code on screen: a QR-sized square with Refresh (or Preparing…) in its place.
      qrKey = "";
      if (!slot) {
        slot = document.createElement("div");
        slot.id = "hns-qr-slot";
        slot.appendChild(refreshButton(pairing));
        var first = pairing.firstElementChild;
        pairing.insertBefore(slot, first);
      }
      if (qrSize) {
        var w = qrSize.width + "px", hgt = qrSize.height + "px";
        if (slot.style.width !== w) slot.style.width = w;
        if (slot.style.height !== hgt) slot.style.height = hgt;
      }
      var slotButton = slot.querySelector("button");
      if (preparing) {
        if (slotButton.textContent !== "Preparing\u2026") slotButton.textContent = "Preparing\u2026";
      } else if (!slotButton.querySelector(".hns-qr-line2")) {
        setExpiredText(slotButton);
      }
      slotButton.disabled = preparing;
      // Keep the countdown line (and so everything below it) where it was.
      if (!own) {
        own = document.createElement("p");
        own.id = "hns-qr-countdown";
        pairing.appendChild(own);
      }
      var waitText = preparing ? "Preparing a new code\u2026" : "QR expired";
      if (own && own.textContent !== waitText) own.textContent = waitText;
      return;
    }
    if (slot) slot.remove();
    if (qr.offsetWidth > 0) qrSize = { width: qr.offsetWidth, height: qr.offsetHeight };

    var svg = qr.querySelector("svg");
    var key = svg ? String(svg.innerHTML.length) + svg.innerHTML.slice(-64) : "";
    if (key !== qrKey) {
      qrKey = key;
      qrShownAt = Date.now();
      qr.classList.remove("hns-expired");
      var oldOverlay = qr.querySelector(".hns-qr-overlay");
      if (oldOverlay) oldOverlay.remove();
    }
    if (!own) {
      own = document.createElement("p");
      own.id = "hns-qr-countdown";
      qr.parentNode.insertBefore(own, qr.nextSibling);
    }
    var left = Math.max(0, Math.ceil((QR_SHOW_MS - (Date.now() - qrShownAt)) / 1000));
    var text = left > 0 ? "Expires in " + Math.floor(left / 60) + ":" + ("0" + (left % 60)).slice(-2) : "QR expired";
    if (own.textContent !== text) own.textContent = text;
    qr.classList.toggle("hns-expired", left === 0);
    if (left === 0 && !qr.querySelector(".hns-qr-overlay")) {
      var overlay = document.createElement("div");
      overlay.className = "hns-qr-overlay";
      overlay.appendChild(refreshButton(pairing));
      qr.appendChild(overlay);
    }
    if (!qrTicker) qrTicker = nativeSetInterval(schedule, 1000);
  }

  function tvLandingPage() {
    var card = document.querySelector(".scoreboard-entry-card");
    if (!card) {
      if (qrTicker) {
        nativeClearInterval(qrTicker);
        qrTicker = null;
      }
      return;
    }
    var heading = card.querySelector(".panel-heading h1");
    if (heading && heading.textContent !== "Open a Scoreboard") heading.textContent = "Open a Scoreboard";
    var intro = card.querySelector(".panel-heading .helper-text");
    var introText = "Pair this screen with the HitnScore Scoring App";
    if (intro && intro.textContent !== introText) intro.textContent = introText;

    // The QR square now says when a code has expired, so the page's red expiry notice is
    // not needed (other errors, e.g. a wrong display code, still show).
    var notices = document.querySelectorAll(".display-shell > .notice.error");
    for (var e = 0; e < notices.length; e++) {
      var hideIt = /expired|qr code/i.test(notices[e].textContent || "");
      var want = hideIt ? "none" : "";
      if (notices[e].style.display !== want) notices[e].style.display = want;
    }

    var pairing = card.querySelector(".scoreboard-pairing");
    card.classList.toggle("hns-qr-mode", !!pairing);
    if (!pairing) return;
    qrPanel(pairing);
    var qr = pairing.querySelector(".scoreboard-pairing__qr");
    // No instructions or expiry text under the QR code (the intro above covers it, and the
    // QR square itself shows Refresh when needed).
    var helps = pairing.querySelectorAll(".helper-text");
    for (var h = 0; h < helps.length; h++) {
      if (!helps[h].classList.contains("hns-hide")) helps[h].classList.add("hns-hide");
    }
    var actions = pairing.querySelector(".scoreboard-shell__actions");
    if (!actions || document.getElementById("hns-code-entry")) return;
    var box = document.createElement("form");
    box.id = "hns-code-entry";
    box.setAttribute("autocomplete", "off");
    var input = document.createElement("input");
    input.maxLength = 12;
    input.placeholder = "Display code";
    input.setAttribute("autocapitalize", "characters");
    input.setAttribute("autocorrect", "off");
    input.setAttribute("aria-label", "Court display code");
    // Just the box: the court opens by itself once all 12 characters are entered.
    input.addEventListener("input", function () {
      var clean = input.value.toUpperCase().replace(/[^A-Z0-9]/g, "");
      if (clean !== input.value) input.value = clean;
      if (clean.length === 12) submitDisplayCode(clean);
    });
    box.appendChild(input);
    box.addEventListener("submit", function (event) {
      event.preventDefault();
      submitDisplayCode(input.value);
    });
    pairing.insertBefore(box, actions);
  }

  // A new TV starts on Standard Scores (the web page's own default is the "standard" layout,
  // which the TV calls Large Scores). A layout someone has chosen is kept.
  try {
    if (!window.localStorage.getItem("rcktscore.scoreboardLayout")) {
      window.localStorage.setItem("rcktscore.scoreboardLayout", "large-scores");
    }
  } catch (ignored) {}

  // 4. All Games: this court's match keeps the main area; the other courts are a narrow
  //    column of small cards on the right, so they never cover the main score.
  var ALL_GAMES_CSS =
    ".display-shell.display-session-active.display-mode-all-games{" +
      "grid-template-columns:minmax(0,1fr) clamp(150px,19vw,230px)!important;" +
      "grid-template-rows:44px minmax(0,1fr) auto!important;column-gap:10px!important;}" +
    ".display-mode-all-games > .public-access-header{grid-column:1 / -1!important;grid-row:1!important;}" +
    ".display-mode-all-games > .scoreboard-card{grid-column:1!important;grid-row:2!important;" +
      "min-height:0!important;height:100%!important;overflow:hidden!important;" +
      // Tight spacing above and below the court name, so the scores get the room.
      "padding:6px 14px 10px!important;gap:6px!important;display:grid!important;" +
      "grid-template-rows:auto minmax(0,1fr)!important;}" +
    ".display-mode-all-games > .scoreboard-card .scoreboard-header{margin:0!important;padding:0!important;min-height:0!important;gap:10px!important;}" +
    ".display-mode-all-games > .scoreboard-card .scoreboard-header h2{font-size:1rem!important;line-height:1.2!important;margin:0!important;}" +
    ".display-mode-all-games > .scoreboard-card .score-series-chip{font-size:0.7rem!important;padding:2px 8px!important;min-height:0!important;}" +
    ".display-mode-all-games > .scoreboard-card .scoreboard-grid{min-height:0!important;}" +
    ".display-mode-all-games > .scoreboard-card .player-card{padding-top:6px!important;padding-bottom:6px!important;}" +
    ".display-mode-all-games > .scoreboard-card .player-games{margin-top:0!important;}" +
    ".display-mode-all-games > .scoreboard-card .player-score{font-size:clamp(7.5rem,45vh,24rem)!important;line-height:0.9!important;}" +
    ".display-mode-all-games > .scoreboard-club-panel{grid-column:2!important;grid-row:2!important;" +
      "min-height:0!important;height:100%!important;padding:8px!important;gap:6px!important;overflow:hidden!important;" +
      "align-content:start!important;}" +
    ".display-mode-all-games > .notice{grid-column:1 / -1!important;grid-row:3!important;margin:0!important;padding:4px 10px!important;font-size:0.75rem!important;}" +
    ".display-mode-all-games > .scoreboard-club-panel .panel-heading{margin:0!important;min-height:0!important;gap:4px!important;}" +
    ".display-mode-all-games > .scoreboard-club-panel .panel-heading h2{font-size:0.8rem!important;margin:0!important;}" +
    ".display-mode-all-games .scoreboard-club-panel__page-indicator{font-size:0.6rem!important;}" +
    ".display-mode-all-games .dashboard-empty{font-size:0.7rem!important;padding:8px!important;}" +
    ".display-mode-all-games .scoreboard-club-grid{display:grid!important;grid-template-columns:1fr!important;" +
      "grid-auto-rows:min-content!important;gap:6px!important;min-height:0!important;overflow:hidden!important;}" +
    ".display-mode-all-games .scoreboard-club-card{padding:6px 8px!important;gap:2px!important;border-radius:10px!important;" +
      "box-shadow:none!important;min-height:0!important;}" +
    ".display-mode-all-games .scoreboard-club-card__top strong{font-size:0.7rem!important;}" +
    ".display-mode-all-games .scoreboard-club-card__player{gap:4px!important;align-items:center!important;}" +
    ".display-mode-all-games .scoreboard-club-card__player-name{font-size:0.65rem!important;white-space:nowrap!important;" +
      "overflow:hidden!important;text-overflow:ellipsis!important;min-width:0!important;}" +
    ".display-mode-all-games .scoreboard-club-card__score-stack{gap:4px!important;}" +
    ".display-mode-all-games .scoreboard-club-card__score-stack strong{font-size:0.85rem!important;line-height:1.1!important;}" +
    ".display-mode-all-games .scoreboard-club-card__score-stack small{font-size:0.6rem!important;}" +
    ".display-mode-all-games .scoreboard-club-card__meta{font-size:0.55rem!important;white-space:nowrap!important;" +
      "overflow:hidden!important;text-overflow:ellipsis!important;}" +
    // Five or more other courts: two narrow columns and a slightly wider panel.
    ".display-shell.display-session-active.display-mode-all-games.hns-many-courts{" +
      "grid-template-columns:minmax(0,1fr) clamp(220px,27vw,340px)!important;}" +
    ".hns-many-courts .scoreboard-club-grid{grid-template-columns:1fr 1fr!important;}";

  // All Games: the more courts are being scored, the smaller their cards, so they always
  // fit their column without scrolling (the main court's score is never shrunk for them).
  function fitAllGames() {
    var shell = document.querySelector(".display-shell");
    var grid = document.querySelector(".display-mode-all-games .scoreboard-club-grid");
    if (!shell) return;
    if (!grid) {
      shell.classList.remove("hns-many-courts");
      return;
    }
    // Other courts: drop the "No completed games yet" line; game scores still show once
    // a game has finished.
    var metas = grid.querySelectorAll(".scoreboard-club-card__meta");
    for (var m = 0; m < metas.length; m++) {
      var empty = /no (completed )?games( completed)?/i.test(metas[m].textContent || "");
      var wantDisplay = empty ? "none" : "";
      if (metas[m].style.display !== wantDisplay) metas[m].style.display = wantDisplay;
    }
    var count = grid.children.length;
    shell.classList.toggle("hns-many-courts", count >= 5);
    grid.style.zoom = "1";
    var panel = grid.parentElement;
    var heading = panel ? panel.querySelector(".panel-heading") : null;
    var available = (panel ? panel.clientHeight : 0) - (heading ? heading.offsetHeight + 8 : 0) - 8;
    var needed = grid.scrollHeight;
    if (available > 0 && needed > available) {
      grid.style.zoom = String(Math.max(0.4, Math.floor((available / needed) * 100) / 100));
    }
  }

  function addStyle() {
    if (document.getElementById("hns-tv-fit")) return;
    var style = document.createElement("style");
    style.id = "hns-tv-fit";
    style.textContent =
      "html,body{overflow:hidden!important;overscroll-behavior:none!important;}" +
      "::-webkit-scrollbar{display:none!important;}" + HEADER_CSS + SCORE_CSS + LARGE_CSS + ALL_GAMES_CSS + PAIRING_CSS;
    (document.head || document.documentElement).appendChild(style);
  }

  var pending = false;
  function fit() {
    pending = false;
    var root = document.documentElement;
    if (!root || !document.body) return;
    addStyle();
    hideRefreshButton();
    renameLayouts();
    tvLandingPage();
    root.style.zoom = "1";
    fitAllGames();
    fitPlayerNames();
    var width = Math.max(root.scrollWidth, document.body.scrollWidth);
    var height = Math.max(root.scrollHeight, document.body.scrollHeight);
    var scale = Math.min(1, window.innerWidth / width, window.innerHeight / height);
    // Small margin so rounding never leaves a 1px scroll.
    if (scale < 1) scale = Math.floor(scale * 1000) / 1000 - 0.005;
    root.style.zoom = String(scale);
    window.scrollTo(0, 0);
  }

  function schedule() {
    if (pending) return;
    pending = true;
    window.requestAnimationFrame(fit);
  }

  function start() {
    schedule();
    // Ignore our own zoom change on <html>, or fitting would trigger itself forever.
    new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var m = mutations[i];
        // Also ignore our own zoom on the All Games grid and the many-courts class.
        var t = m.target && m.target.nodeType === 3 ? m.target.parentNode : m.target;
        if (t && t.id === "hns-qr-countdown") continue;
        var own = m.type === "attributes" && (m.target === document.documentElement ||
          (m.target.classList && (m.target.classList.contains("scoreboard-club-grid") ||
            m.target.classList.contains("player-name-stack") || m.target.tagName === "H3" ||
            m.target.classList.contains("scoreboard-pairing__qr") ||
            (m.attributeName === "class" && m.target.classList.contains("display-shell")))));
        if (!own) { schedule(); return; }
      }
    }).observe(document.documentElement, {
      childList: true, subtree: true, attributes: true, characterData: true
    });
    window.addEventListener("resize", schedule);
    window.addEventListener("load", schedule);
    // Fonts and images arriving late change the size too.
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(schedule);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
