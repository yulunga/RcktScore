const { test, expect } = require("@playwright/test");

if (process.env.E2E_SYSTEM_CHROME === "1") {
  test.use({ channel: "chrome", video: "off" });
}

test("login page loads @smoke", async ({ page }) => {
  await page.goto("/login");

  await expect(page.getByLabel("Username")).toBeVisible();
  await expect(page.getByLabel("Password")).toBeVisible();
  await expect(page.getByRole("button", { name: "Sign In" })).toBeVisible();
  await expect(page.getByRole("link", { name: "View tournament draw" })).toHaveCount(0);
});

for (const viewportSize of [
  { name: "iPhone SE", width: 568, height: 320 },
  { name: "iPhone 16 Pro", width: 852, height: 393 },
  { name: "iPhone 17", width: 874, height: 402 },
  { name: "iPhone Pro Max", width: 932, height: 430 },
]) {
  test(`phone landscape login keeps every sign-in action visible on ${viewportSize.name} @smoke`, async ({ page }) => {
    await page.addInitScript(() => {
      window.localStorage.setItem("hitnscore.analytics-consent", "denied");
    });
    await page.setViewportSize({ width: viewportSize.width, height: viewportSize.height });
    await page.goto("/login");

    const controls = [
      page.getByLabel("Username"),
      page.getByLabel("Password"),
      page.getByRole("button", { name: "Sign In" }),
      page.getByRole("button", { name: "Want In" }),
      page.getByRole("button", { name: "Need Help" }),
    ];

    for (const control of controls) {
      await expect(control).toBeVisible();
      const controlBox = await control.boundingBox();
      expect(controlBox.x).toBeGreaterThanOrEqual(0);
      expect(controlBox.y).toBeGreaterThanOrEqual(0);
      expect(controlBox.x + controlBox.width).toBeLessThanOrEqual(viewportSize.width + 1);
      expect(controlBox.y + controlBox.height).toBeLessThanOrEqual(viewportSize.height + 1);
    }

    expect(await page.evaluate(() => document.scrollingElement.scrollHeight - window.innerHeight)).toBeLessThanOrEqual(1);
  });
}

test("registration and privacy copy use the public product wording @smoke", async ({ page }) => {
  await page.route("**/registration/status?challenge=1", (route) => route.fulfill({
    json: { success: true, data: { enabled: true } },
  }));
  await page.goto("/login?interest=1#want-in");

  await expect(page.getByText(
    "Welcome to HitnScore the racket sport scoring app. Create a free personal account to start scoring matches. We also offer multi-user accounts for Rackets Sports Clubs. Register your interest for a club account and we will be in touch.",
    { exact: true },
  )).toBeVisible();
  await expect(page.locator(".cookie-consent")).toContainText("Optional Analytics");
  await expect(page.locator(".cookie-consent")).not.toContainText("Google Analytics");
});

test("Want In and Need Help use timed login-card overlays @smoke", async ({ page }) => {
  await page.route("**/registration/status?challenge=1", (route) => route.fulfill({
    json: { success: true, data: { enabled: true } },
  }));
  await page.setViewportSize({ width: 402, height: 874 });
  await page.goto("/login");

  const entryLinks = page.locator(".login-help-link");
  const [wantInBox, helpBox] = await Promise.all([
    entryLinks.getByRole("button", { name: "Want In" }).boundingBox(),
    entryLinks.getByRole("button", { name: "Need Help" }).boundingBox(),
  ]);
  expect(Math.abs(wantInBox.y - helpBox.y)).toBeLessThanOrEqual(1);

  await entryLinks.getByRole("button", { name: "Want In" }).click();
  const wantInDialog = page.getByRole("dialog", { name: "Want In" });
  await expect(wantInDialog).toBeVisible();
  await expect(page.getByRole("button", { name: "Close Want In" })).toBeVisible();
  await page.getByRole("button", { name: "Close Want In" }).click();
  await expect(wantInDialog).toHaveCount(0);

  await page.clock.install();
  await entryLinks.getByRole("button", { name: "Need Help" }).click();
  const helpDialog = page.getByRole("dialog", { name: "Need Help?" });
  await expect(helpDialog).toBeVisible();
  await expect(helpDialog.getByRole("button")).toHaveCount(4);
  await expect(helpDialog.getByRole("button", { name: "Ping Us" })).toBeVisible();
  await expect(helpDialog.getByRole("button", { name: "Guides" })).toBeVisible();
  await expect(helpDialog.getByRole("button", { name: "Password Reset" })).toBeVisible();
  await page.clock.fastForward(15001);
  await expect(helpDialog).toHaveCount(0);

  await entryLinks.getByRole("button", { name: "Want In" }).click();
  await expect(wantInDialog).toBeVisible();
  await expect(wantInDialog.getByRole("heading", { name: "Join Hit n Score" })).toBeVisible();
  await page.clock.runFor(1);
  await page.clock.fastForward(15001);
  await expect(wantInDialog).toHaveCount(0);
});

test("paused Want In registers interest and keeps sign-in available @smoke", async ({ page }) => {
  await page.route("**/registration/status?challenge=1", (route) => route.fulfill({
    json: {
      success: true,
      data: {
        enabled: false,
        message: "Please register your interest.",
        challenge: { prompt: "Human check: what is 2 + 3?", token: "challenge-token" },
      },
    },
  }));
  await page.route("**/registration/interest", (route) => route.fulfill({
    status: 202,
    json: { success: true, data: { accepted: true } },
  }));

  await page.goto("/login");
  await page.getByRole("button", { name: "Essential only" }).click();
  await page.getByRole("button", { name: "Want In" }).click();
  await expect(page.getByText("Please register your interest.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Sign In" })).toBeEnabled();
  await page.getByLabel("First name").fill("Sam");
  await page.getByLabel("Surname").fill("Smith");
  await page.getByLabel("Email address").fill("sam@example.com");
  await page.getByLabel("App Use").selectOption("club");
  await expect(page.getByLabel("Club name")).toHaveCount(0);
  await page.getByLabel("Human check: what is 2 + 3?").fill("5");

  const requestPromise = page.waitForRequest("**/registration/interest");
  await page.getByRole("button", { name: "Register interest", exact: true }).click();
  expect((await requestPromise).postDataJSON()).toMatchObject({
    first_name: "Sam", surname: "Smith", email: "sam@example.com", use_type: "club",
    challenge_token: "challenge-token", challenge_answer: "5",
  });
  await expect(page.getByText(/Thanks for registering your interest/)).toBeVisible();
});

test("Ground Control saves Services and shows the traffic-light status @smoke", async ({ page }) => {
  await page.route("**/root_admin/session/status", (route) => route.fulfill({
    json: { success: true, data: { rootAdminSession: { username: "Admin", csrf_token: "test-csrf" } } },
  }));
  await page.route("**/root_admin/services", (route) => route.fulfill({
    json: { success: true, data: route.request().method() === "GET" ? {
      status: "green",
      services: {
        public_registration: { enabled: true, message: "Please register your interest." },
        subscriptions: { enabled: true, exceptions: [] },
      },
    } : { ...route.request().postDataJSON(), status: "orange" } },
  }));

  await page.goto("/rckscoreAdmin/services");
  await page.getByRole("button", { name: "Essential only" }).click();
  const light = page.getByRole("link", { name: "Services: all enabled" });
  await expect(light).toHaveAttribute("data-status", "green");
  await expect(page.locator(".root-admin-session-nav a").nth(-2)).toHaveAccessibleName("Settings");

  await page.getByLabel("Message when registration is paused").fill("Join our waiting list.");
  await page.getByRole("switch", { name: "Enable subscription menus" }).uncheck();
  await page.getByLabel("Subscription access exceptions").fill("tester@example.com");
  const requestPromise = page.waitForRequest("**/root_admin/services");
  await page.getByRole("button", { name: "Save Services", exact: true }).click();
  const request = await requestPromise;
  expect(request.postDataJSON()).toEqual({
    status: "green",
    services: {
      public_registration: { enabled: true, message: "Join our waiting list." },
      subscriptions: { enabled: false, exceptions: ["tester@example.com"] },
    },
  });
  expect(request.headers()["x-csrf-token"]).toBe("test-csrf");
  await expect(page.getByRole("link", { name: "Services: partly disabled" })).toHaveAttribute("data-status", "orange");
});

test("email confirmation validates its link and enforces the password checklist @smoke", async ({ page }) => {
  await page.route("**/password_reset/validate", async (route) => {
    await route.fulfill({ json: { success: true, data: { valid: true } } });
  });
  await page.goto("/help?mode=confirm-email&token=valid-test-token");

  await expect(page.getByRole("heading", { name: "Email Address Confirmed" })).toBeVisible();
  await expect(page.getByText("Your email address has been confirmed.", { exact: false })).toBeVisible();
  const requirements = page.getByRole("list", { name: "Password requirements" });
  await expect(requirements).toContainText("One uppercase letter");
  await expect(requirements).toContainText("One number");
  await expect(requirements).toContainText("One symbol");
  await expect(requirements).toContainText("No common or easily guessed words");
});

test("dashboard redirects anonymous users back to login @smoke", async ({ page }) => {
  await page.goto("/dashboard");

  await expect(page.getByLabel("Username")).toBeVisible();
  await expect(page.getByRole("button", { name: "Sign In" })).toBeVisible();
});

test("help page opens password reset section @smoke", async ({ page }) => {
  await page.goto("/help");

  await expect(page.getByRole("heading", { name: "Getting started" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Accounts & access" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Matches & scoring" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Live sharing & displays" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Insights, tournaments & settings" })).toBeVisible();
  await expect(page.getByRole("searchbox")).toHaveCount(0);

  await page.getByRole("button", { name: /Live score viewing/ }).click();
  await expect(page).toHaveURL(/section=live-viewing/);
  await expect(page.getByRole("heading", { name: "Live score viewing" })).toBeVisible();
  await expect(page.getByText("It does not currently broadcast live video or audio.", { exact: false })).toBeVisible();
  await page.getByRole("button", { name: "Back to Help Centre" }).click();

  const footer = page.locator(".public-site-footer");
  await expect(footer).toBeVisible();
  await expect(footer.getByRole("link", { name: "HitNScore home" })).toHaveAttribute("href", "https://www.hitnscore.com/");
  await expect(footer.getByText("Racket-sport scoring for players and clubs.")).toBeVisible();
  await expect(footer.getByRole("link", { name: "HitNScore on the App Store, coming soon" })).toBeVisible();
  await expect(footer.getByRole("link", { name: "Tournament draw" })).toHaveAttribute("href", "/tournament-draw");
  await expect(footer.getByRole("link", { name: "Scoreboard display" })).toHaveAttribute("href", "/scoreboard");
  await expect(footer.getByRole("link", { name: "Help & feedback" })).toHaveAttribute("href", "/help");
  await expect(footer.getByRole("link", { name: "Privacy & terms" })).toHaveAttribute("href", "/help?section=privacy");
  await expect(footer.getByRole("link", { name: "Cookie settings" })).toHaveAttribute("href", "/help?section=cookies");

  await page.getByRole("button", { name: "Reset Password" }).click();
  await expect(page.getByRole("heading", { name: "Password Reset" })).toBeVisible();
  await expect(page.getByLabel("Account email")).toBeVisible();
});

test("display page loads the scoreboard entry experience @smoke", async ({ page }) => {
  await page.goto("/display");

  const scoreboardHeaderBox = await page.locator(".public-access-header").boundingBox();
  expect(scoreboardHeaderBox.x).toBeCloseTo(0, 0);
  expect(scoreboardHeaderBox.width).toBeCloseTo(page.viewportSize().width, 0);
  await expect(page.getByRole("heading", { name: "Open a Court Scoreboard" })).toBeVisible();
  await expect(page.getByText("Live Scoreboard", { exact: true })).toBeVisible();
  await expect(page.locator(".public-access-header__brand-stack small")).toHaveCSS("font-weight", "600");
  await expect(page.getByLabel("Scoreboard Display Code")).toBeVisible();
  await expect(page.getByRole("button", { name: "Open Scoreboard" })).toBeVisible();
  await expect(page.getByText("Enter a court display code to open the live scoreboard.")).toHaveCount(0);

  const scoreboardEntryBox = await page.locator(".scoreboard-entry-card").boundingBox();
  const viewport = page.viewportSize();
  expect(scoreboardEntryBox.width).toBeLessThanOrEqual(620);
  expect(scoreboardEntryBox.height).toBeLessThan(400);
  expect(scoreboardEntryBox.x + (scoreboardEntryBox.width / 2)).toBeCloseTo(viewport.width / 2, 0);
  const availableContentCentre = scoreboardHeaderBox.height
    + ((viewport.height - scoreboardHeaderBox.height) / 2);
  expect(Math.abs(
    scoreboardEntryBox.y + (scoreboardEntryBox.height / 2) - availableContentCentre,
  )).toBeLessThan(20);
});

test("public tournament page uses the compact public entry experience @smoke", async ({ page }) => {
  await page.goto("/tournament-draw");

  const tournamentHeaderBox = await page.locator(".public-access-header").boundingBox();
  expect(tournamentHeaderBox.x).toBeCloseTo(0, 0);
  expect(tournamentHeaderBox.width).toBeCloseTo(page.viewportSize().width, 0);
  await expect(page.getByText("Tournament", { exact: true })).toBeVisible();
  await expect(page.locator(".public-access-header__brand-stack small")).toHaveCSS("font-weight", "600");
  await expect(page.getByRole("link", { name: "HitNScore home" })).toHaveAttribute("href", "https://www.hitnscore.com/");
  await expect(page.getByRole("heading", { name: "View a Tournament Draw" })).toBeVisible();
  await expect(page.getByLabel("Tournament Draw Key")).toBeVisible();
  await expect(page.getByText("Public Tournament Draw", { exact: true })).toHaveCount(0);
});

test("public tournament entry does not overflow a large desktop viewport @smoke", async ({ page }) => {
  await page.setViewportSize({ width: 2560, height: 1440 });
  await page.goto("/tournament-draw");

  const layout = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(layout.scrollWidth).toBeLessThanOrEqual(layout.clientWidth);

  const headerBox = await page.locator(".public-access-header").boundingBox();
  expect(headerBox.x).toBeCloseTo(0, 0);
  expect(headerBox.width).toBeCloseTo(layout.clientWidth, 0);
});
