const { test, expect } = require("@playwright/test");

const session = {
  username: "web-plus@example.com",
  email: "web-plus@example.com",
  first_name: "Plus",
  surname: "Player",
  organization_id: 50003,
  organization_name: "Personal Plus Test",
  organization_type: "personal",
  plan: "personal_plus",
  role: "admin",
  enabled_sports: ["squash", "racketball", "tennis", "padel"],
  session_token: "playwright-plus-session",
};

function envelope(data) {
  return { success: true, data };
}

function scheduledMatch(status = "scheduled") {
  return {
    id: "personal-plus-scheduled-1",
    tenant_id: "50003",
    sport: "squash",
    status,
    court_name: "Personal Match",
    court_alias: "Personal Match",
    player1_name: "Alex",
    player1_surname: "Ace",
    player2_name: "Blair",
    player2_surname: "Backhand",
    score_type: 11,
    best_of: 3,
    created_at: "2026-10-07T10:00:00Z",
    updated_at: "2026-10-07T10:00:00Z",
    state: {
      player1_score: 0,
      player2_score: 0,
      player1_games_won: 0,
      player2_games_won: 0,
      current_game_number: 1,
      current_server: "Alex",
      current_server_side: "player1",
      service_side: "Right",
      score_type: 11,
      best_of: 3,
      tennis_timed_breaks: false,
      game_history: [],
      events: [{ id: "start", event_type: "match_started", payload: {} }],
    },
  };
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
  }, session);
});

test("Personal Plus schedules a match and starts it later from Matches @scheduling", async ({ page }) => {
  let createPayload;
  let activationPayload;
  let created = false;
  let match = scheduledMatch();
  const existingActiveMatch = {
    ...scheduledMatch("active"),
    id: "personal-plus-active-1",
    player1_name: "Current",
    player1_surname: "Player",
    player2_name: "Live",
    player2_surname: "Opponent",
  };

  await page.route("**/organization_settings/50003", async (route) => {
    await route.fulfill({ json: envelope({ organizationSettings: {
      organization: {
        id: 50003,
        org_type: "personal",
        plan: "personal_plus",
        enabled_sports: session.enabled_sports,
        timed_break_defaults: { squash: false, racketball: false, tennis: false, padel: false },
      },
      users: [],
      courts: [],
    } }) });
  });
  await page.route("**/dashboard/50003*", async (route) => {
    await route.fulfill({ json: envelope({ dashboard: {
      organization: { id: 50003, type: "personal", plan: "personal_plus" },
      active_matches: created ? [] : [existingActiveMatch],
      scheduled_matches: created ? [match] : [],
      recent_matches: [],
    } }) });
  });
  await page.route("**/start_match", async (route) => {
    createPayload = route.request().postDataJSON();
    created = true;
    await route.fulfill({ json: envelope({ match }) });
  });
  await page.route("**/start_scheduled_match", async (route) => {
    activationPayload = route.request().postDataJSON();
    match = scheduledMatch("active");
    await route.fulfill({ json: envelope({ match }) });
  });
  await page.route("**/get_score/personal-plus-scheduled-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/new/setup?sport=squash");
  await expect(page.getByLabel("Schedule for Later")).toBeVisible();
  await page.locator("#player1_name").fill("Alex");
  await page.locator("#player1_surname").fill("Ace");
  await page.locator("#player2_name").fill("Blair");
  await page.locator("#player2_surname").fill("Backhand");
  await expect(page.getByRole("button", { name: "Start Match" })).toBeDisabled();
  await page.getByLabel("Schedule for Later").check();
  await expect(page.getByRole("button", { name: "Schedule Match" })).toBeEnabled();
  await page.getByRole("button", { name: "Schedule Match" }).click();

  await expect.poll(() => createPayload).toBeTruthy();
  expect(createPayload).toMatchObject({
    tenant_id: "50003",
    sport: "squash",
    status: "scheduled",
    schedule_match: true,
  });
  await expect(page).toHaveURL(/\/matches#scheduled-matches-section$/);
  await expect(page.getByText("View live and scheduled matches for your organisation in one scrolling list.", { exact: true })).toHaveCount(0);
  await expect(page.getByText("Matches", { exact: true })).toHaveCount(1);
  const matchTabs = page.getByRole("tablist", { name: "Match category" });
  const currentTab = matchTabs.getByRole("tab", { name: "Current", exact: true });
  const scheduledTab = matchTabs.getByRole("tab", { name: "Scheduled", exact: true });
  const historyTab = matchTabs.getByRole("tab", { name: "History", exact: true });
  await expect(currentTab).toBeVisible();
  await expect(scheduledTab).toHaveAttribute("aria-selected", "true");
  await expect(historyTab).toBeVisible();
  await page.emulateMedia({ colorScheme: "dark" });
  await expect(matchTabs).toHaveCSS("background-color", "rgba(16, 42, 67, 0.96)");
  await expect(scheduledTab).toHaveCSS("background-color", "rgb(47, 142, 229)");
  await expect(currentTab).toHaveCSS("color", "rgb(200, 216, 232)");
  await page.emulateMedia({ colorScheme: "light" });
  await expect(page.getByRole("heading", { name: "Scheduled Matches" })).toBeVisible();
  await currentTab.click();
  await expect(page.getByRole("heading", { name: "Active Matches" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Scheduled Matches" })).toHaveCount(0);
  await historyTab.click();
  await expect(page.getByRole("heading", { name: "Match History" })).toBeVisible();
  await expect(page.getByPlaceholder("Search player name, surname, or date")).toBeVisible();
  await scheduledTab.click();
  await expect(page.getByRole("heading", { name: "Scheduled Matches" })).toBeVisible();
  await page.getByRole("button", { name: "Start", exact: true }).click();

  await expect.poll(() => activationPayload).toEqual({ match_id: "personal-plus-scheduled-1" });
  await expect(page).toHaveURL(/\/match\/personal-plus-scheduled-1$/);
});
