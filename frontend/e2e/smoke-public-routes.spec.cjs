const { test, expect } = require("@playwright/test");

test("login page loads @smoke", async ({ page }) => {
  await page.goto("/login");

  await expect(page.getByLabel("Username")).toBeVisible();
  await expect(page.getByLabel("Password")).toBeVisible();
  await expect(page.getByRole("button", { name: "Sign In" })).toBeVisible();
  await expect(page.getByRole("link", { name: "View tournament draw" })).toHaveCount(0);
});

test("dashboard redirects anonymous users back to login @smoke", async ({ page }) => {
  await page.goto("/dashboard");

  await expect(page.getByLabel("Username")).toBeVisible();
  await expect(page.getByRole("button", { name: "Sign In" })).toBeVisible();
});

test("help page opens password reset section @smoke", async ({ page }) => {
  await page.goto("/help");

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
  await expect(page.getByRole("link", { name: "HitNScore home" })).toHaveAttribute("href", "https://www.hitnscore.com/");
  await expect(page.getByRole("heading", { name: "View a Tournament Draw" })).toBeVisible();
  await expect(page.getByLabel("Tournament Draw Key")).toBeVisible();
  await expect(page.getByText("Public Tournament Draw", { exact: true })).toHaveCount(0);
});
