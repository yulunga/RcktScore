const { test, expect } = require("@playwright/test");

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
      page.getByRole("link", { name: "Need help?" }),
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
  await page.goto("/login?interest=1#want-in");

  await expect(page.getByText(
    "Welcome to HitnScore the racket sport scoring app. Create a free personal account to start scoring matches. We also offer multi-user accounts for Rackets Sports Clubs. Register your interest for a club account and we will be in touch.",
    { exact: true },
  )).toBeVisible();
  await expect(page.locator(".cookie-consent")).toContainText("Optional Analytics");
  await expect(page.locator(".cookie-consent")).not.toContainText("Google Analytics");
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
