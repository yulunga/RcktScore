const { test, expect } = require("@playwright/test");

const session = {
  username: "admin@democlub.com",
  organization_id: 77,
  organization_name: "Demo Club",
  organization_type: "club",
  plan: "club_essentials",
  role: "admin",
  session_token: "playwright-tournament-session",
};

const tournament = {
  id: "07fd1fc6-4133-4872-b469-112841c49384",
  organization_id: 77,
  name: "2026-Squash Handicap",
  sport: "squash",
  draw_format: "knockout_plate",
  audience: "open",
  graded_enabled: true,
  draw_size_limit: 32,
  status: "draft",
  venue_name: "Demo Club",
  starts_on: "2026-11-01",
  ends_on: "2026-11-02",
  entry_count: 0,
  entries: [],
  draws: ["A", "B", "C", "D"].map((grade) => ({ name: `Grade ${grade}`, grade, status: "draft" })),
};

function envelope(data) {
  return { success: true, data };
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
  }, session);
  await page.route("**/notifications/77*", async (route) => route.fulfill({ json: envelope({ notifications: [] }) }));
  await page.route("**/organization_settings/77", async (route) => route.fulfill({ json: envelope({
    organizationSettings: {
      organization: {
        id: 77,
        organization_name: "Demo Club",
        org_type: "club",
        features: { tournament_manager: { web_enabled: true } },
      },
      users: [],
      courts: [],
    },
  }) }));
  await page.route("**/organizations/77/tournaments", async (route) => route.fulfill({
    json: envelope({ tournaments: [tournament] }),
  }));
});

test("uses the standard header and exposes persisted tournament options @tournament", async ({ page }) => {
  await page.goto("/tournaments");

  await expect(page.locator(".club-page-header__page-title")).toHaveCount(0);
  await expect(page.getByText("Create tournament events and build a reusable player list", { exact: false })).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Back to Settings" })).toHaveCount(0);
  await expect(page.getByLabel("Tournament Access")).toBeVisible();
  await expect(page.getByText("Graded tournament", { exact: true })).toBeVisible();
  await expect(page.getByText("Limit draw size", { exact: true })).toBeVisible();
});

test("shows event identity in the summary and uses search-first player entry @tournament", async ({ page }) => {
  await page.route(`**/tournaments/${tournament.id}?*`, async (route) => route.fulfill({
    json: envelope({ tournament }),
  }));
  await page.route("**/organizations/77/tournament-players?q=alex", async (route) => route.fulfill({
    json: envelope({ players: [{
      player_id: "e1cbcc2a-d9bd-48b4-96c9-5643140d23ef",
      user_id: null,
      first_name: "Alex",
      surname: "Player",
      display_name: "Alex Player",
      email: "alex@example.com",
      home_club_name: "Away Club",
      relationship: "guest",
    }] }),
  }));

  await page.goto(`/tournaments/${tournament.id}`);

  await expect(page.locator(".club-page-header__page-title")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "All Tournaments" })).toHaveCount(0);
  await expect(page.getByRole("heading", { name: tournament.name })).toBeVisible();
  await expect(page.getByText("Squash · Knockout with Plate", { exact: true })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Event Summary" })).toHaveCount(0);
  await expect(page.getByLabel("Country")).toHaveCount(0);
  await expect(page.getByLabel("Seed")).toHaveCount(0);

  await page.getByLabel("Search Players").fill("alex");
  await expect(page.getByRole("button", { name: "Search", exact: true })).toHaveCount(0);
  await expect(page.getByText("Alex Player", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: /Alex Player/ }).click();
  await expect(page.getByText("Racket up is this way", { exact: true })).toBeVisible();
  await expect(page.getByText("Advanced player", { exact: true })).toBeVisible();
  const manualButton = page.getByRole("button", { name: "Add Player Manually" });
  await expect(manualButton).toBeVisible();
  await expect(manualButton).toHaveCSS("background-color", "rgb(18, 116, 208)");
  await expect(manualButton).toHaveCSS("border-radius", "999px");

  const summaryPanels = page.locator(".tournament-summary-grid > .panel");
  const managerPanels = page.locator(".tournament-manager-grid > .panel");
  const [summaryLeft, summaryRight, managerLeft, managerRight] = await Promise.all([
    summaryPanels.nth(0).boundingBox(),
    summaryPanels.nth(1).boundingBox(),
    managerPanels.nth(0).boundingBox(),
    managerPanels.nth(1).boundingBox(),
  ]);
  expect(Math.abs(summaryLeft.x - managerLeft.x)).toBeLessThan(2);
  expect(Math.abs(summaryRight.x - managerRight.x)).toBeLessThan(2);
  expect(Math.abs(summaryLeft.width - managerLeft.width)).toBeLessThan(2);
});
