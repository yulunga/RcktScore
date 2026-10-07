const { test, expect } = require("@playwright/test");

const session = {
  username: "web-racket@example.com",
  email: "web-racket@example.com",
  first_name: "Web",
  surname: "Player",
  organization_id: 50002,
  organization_name: "Web Racket Test",
  organization_type: "personal",
  plan: "personal_plus",
  role: "admin",
  enabled_sports: ["squash", "racketball"],
  session_token: "playwright-racket-session",
};

function envelope(data) {
  return { success: true, data };
}

function freshRacketMatch(sport = "squash", timedBreaks = false) {
  return {
    id: `web-${sport}-1`,
    tenant_id: "50002",
    sport,
    status: "active",
    court_name: "Personal Match",
    player1_name: "Alex",
    player1_surname: "Ace",
    player2_name: "Blair",
    player2_surname: "Backhand",
    score_type: 15,
    best_of: 3,
    handicap_enabled: true,
    player1_offset: -2,
    player2_offset: 3,
    state: {
      player1_score: -2,
      player2_score: 3,
      player1_games_won: 0,
      player2_games_won: 0,
      current_game_number: 1,
      current_server: "Alex",
      current_server_side: "player1",
      service_side: "Right",
      best_of: 3,
      score_type: 15,
      tennis_no_ad_scoring: true,
      tennis_timed_breaks: timedBreaks,
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

for (const sport of ["squash", "racketball"]) {
  test(`creates a personal ${sport} handicap match with Golden Point and the saved timer default @racket`, async ({ page }) => {
    let createPayload;
    const match = freshRacketMatch(sport, true);

    await page.route("**/organization_settings/50002", async (route) => {
      await route.fulfill({ json: envelope({ organizationSettings: {
        organization: {
          id: 50002,
          org_type: "personal",
          plan: "personal_plus",
          enabled_sports: ["squash", "racketball"],
          timed_break_defaults: { squash: true, racketball: true, tennis: false, padel: false },
        },
        users: [],
        courts: [],
      } }) });
    });
    await page.route("**/dashboard/50002*", async (route) => {
      await route.fulfill({ json: envelope({ dashboard: { active_matches: [], scheduled_matches: [], recent_matches: [] } }) });
    });
    await page.route("**/start_match", async (route) => {
      createPayload = route.request().postDataJSON();
      await route.fulfill({ json: envelope({ match }) });
    });
    await page.route(`**/get_score/web-${sport}-1`, async (route) => {
      await route.fulfill({ json: envelope({ match }) });
    });

    await page.goto(`/match/new/setup?sport=${sport}`);
    await expect(page.getByLabel("Timed warm-up and 90-second game breaks")).toBeChecked();
    await page.locator("#player1_name").fill("Alex");
    await page.locator("#player1_surname").fill("Ace");
    await page.locator("#player2_name").fill("Blair");
    await page.locator("#player2_surname").fill("Backhand");
    await page.getByLabel("Handicap Match").check();
    await page.getByLabel("Handicap Option").selectOption("custom");
    await page.getByLabel("Player 1 Starting Score").fill("-2");
    await page.getByLabel("Player 2 Starting Score").fill("3");
    await page.getByLabel("Golden Point at 14-all").check();
    await page.getByRole("button", { name: "Start Match" }).click();

    await expect.poll(() => createPayload).toBeTruthy();
    expect(createPayload).toMatchObject({
      sport,
      handicap_enabled: true,
      player1_offset: -2,
      player2_offset: 3,
      tennis_no_ad_scoring: true,
      tennis_timed_breaks: true,
    });
    await expect(page.getByText("Warm-Up Ready", { exact: true })).toBeVisible();
  });
}

test("Personal Free can create a squash handicap match @racket", async ({ page }) => {
  let createPayload;
  const match = freshRacketMatch("squash", false);
  const personalFreeSession = { ...session, plan: "personal_free" };

  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
  }, personalFreeSession);
  await page.route("**/organization_settings/50002", async (route) => {
    await route.fulfill({ json: envelope({ organizationSettings: {
      organization: {
        id: 50002,
        org_type: "personal",
        plan: "personal_free",
        enabled_sports: ["squash"],
        timed_break_defaults: { squash: false, racketball: false, tennis: false, padel: false },
      },
      users: [],
      courts: [],
    } }) });
  });
  await page.route("**/dashboard/50002*", async (route) => {
    await route.fulfill({ json: envelope({ dashboard: { active_matches: [], scheduled_matches: [], recent_matches: [] } }) });
  });
  await page.route("**/start_match", async (route) => {
    createPayload = route.request().postDataJSON();
    await route.fulfill({ json: envelope({ match }) });
  });
  await page.route("**/get_score/web-squash-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/new/setup?sport=squash");
  await page.locator("#player1_name").fill("Alex");
  await page.locator("#player2_name").fill("Blair");
  await page.getByLabel("Handicap Match").check();
  await page.getByLabel("Handicap Option").selectOption("custom");
  await page.getByLabel("Player 1 Starting Score").fill("-4");
  await page.getByLabel("Player 2 Starting Score").fill("2");
  await page.getByRole("button", { name: "Start Match" }).click();

  await expect.poll(() => createPayload).toBeTruthy();
  expect(createPayload).toMatchObject({
    sport: "squash",
    handicap_enabled: true,
    player1_offset: -4,
    player2_offset: 2,
  });
  await expect(page.locator(".player-card-action")).toHaveCount(2);
});

test("an untimed squash match opens directly on live scoring @racket", async ({ page }) => {
  const match = freshRacketMatch("squash", false);
  await page.addInitScript(() => {
    window.localStorage.setItem("rcktscore.matchTimer.web-squash-1", JSON.stringify({
      phase: "warmup_ready",
      running: false,
      seconds: 60,
      updatedAt: Date.now(),
    }));
  });
  await page.route("**/get_score/web-squash-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/web-squash-1");
  await expect(page.getByText("Warm-Up Ready", { exact: true })).toHaveCount(0);
  await expect(page.locator(".player-card-action")).toHaveCount(2);
  await expect(page.getByText("Match Time", { exact: true })).toBeVisible();
});
