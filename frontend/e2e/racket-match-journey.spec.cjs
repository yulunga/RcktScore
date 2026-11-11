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
    window.localStorage.setItem("hitnscore.analytics-consent", "denied");
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
    await expect(page.getByRole("heading", { name: `${sport === "racketball" ? "Racketball" : "Squash"} Match Setup` })).toBeVisible();
    await expect(page.getByText(/Create a New .* Match/)).toHaveCount(0);
    await expect(page.getByRole("radiogroup", { name: "Player 1 shirt color" })).toHaveCount(0);
    await page.getByRole("button", { name: /Change Player 1 shirt color, currently Blue/ }).click();
    await expect(page.getByRole("radiogroup", { name: "Player 1 shirt color" })).toBeVisible();
    await expect(page.locator(".shirt-color-option").first()).toHaveText("");
    await page.getByRole("radio", { name: "Blue" }).click();
    await expect(page.getByLabel("Timed warm-up and 90-second game breaks")).toBeChecked();
    await page.locator("#player1_name").fill("Alex");
    await page.locator("#player1_surname").fill("Ace");
    await page.locator("#player2_name").fill("Blair");
    await page.locator("#player2_surname").fill("Backhand");
    await expect(page.getByText("Alex", { exact: true }).first()).toBeVisible();
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

test("club setup keeps shirt colours compact and prevents a playing user from refereeing @racket", async ({ page }) => {
  const clubSession = {
    ...session,
    first_name: "Web",
    surname: "Player",
    organization_id: 42,
    organization_name: "Test Club",
    organization_type: "club",
    plan: "club_pro",
  };

  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
  }, clubSession);
  await page.route("**/organization_settings/42", async (route) => {
    await route.fulfill({ json: envelope({ organizationSettings: {
      organization: {
        id: 42,
        org_type: "club",
        plan: "club_pro",
        enabled_sports: ["squash"],
        timed_break_defaults: { squash: false },
      },
      users: [],
      courts: [{ id: 7, court_name: "Court 1", court_alias: "Court 1" }],
    } }) });
  });
  await page.route("**/dashboard/42*", async (route) => {
    await route.fulfill({ json: envelope({ dashboard: { active_matches: [], scheduled_matches: [], recent_matches: [] } }) });
  });

  await page.setViewportSize({ width: 414, height: 896 });
  await page.goto("/match/new/setup?sport=squash");

  await page.locator("#player1_name").fill("Dave");
  await page.locator("#player1_surname").fill("Williams");
  const daveHeading = page.locator(".match-setup-section-title").filter({ hasText: "Dave" }).first();
  await expect(daveHeading.getByRole("button", { name: /Change Dave shirt color/ })).toBeVisible();
  await expect(page.getByText("Dave Shirt", { exact: true })).toHaveCount(0);

  await page.getByLabel("Me", { exact: true }).check();
  await expect(page.locator("#referee_name")).toHaveValue("Web Player");

  await page.locator("#player1_name").fill("Web");
  await page.locator("#player1_surname").fill("Player");
  await expect(page.getByLabel("Me", { exact: true })).toBeDisabled();
  await expect(page.getByLabel("Me", { exact: true })).not.toBeChecked();
  await expect(page.locator("#referee_name")).toHaveValue("");
  await expect(page.getByText("You are listed as a player, so you cannot referee this match.")).toBeVisible();

  const rulesCard = page.locator(".tennis-rules-card");
  await expect(rulesCard.getByLabel("Handicap Match")).toBeVisible();
});

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
  await expect(page.getByRole("heading", { name: "First Server" })).toBeVisible();
});

test("an untimed squash match asks for the opening server before live scoring @racket", async ({ page }) => {
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
  await expect(page.getByRole("heading", { name: "First Server" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Alex Ace", exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Blair Backhand", exact: true })).toBeVisible();
});

test("groups racket decisions and confirms an early draw before showing the summary @racket", async ({ page }) => {
  let endPayload;
  let match = freshRacketMatch("squash", false);
  match.state.events.push({ id: "server", event_type: "server", payload: { current_server_side: "player1", service_side: "Right" } });
  await page.route("**/get_score/web-squash-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });
  await page.route("**/end_match", async (route) => {
    endPayload = route.request().postDataJSON();
    match = {
      ...match,
      status: "completed",
      ended_early: true,
      winner_side: null,
      state: { ...match.state, match_complete: true, ended_early: true, winner_side: null },
    };
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/web-squash-1");
  await page.getByLabel("Match actions").click();
  await expect(page.getByRole("button", { name: "No Let" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Yes Let" })).toBeVisible();
  const strokeButtons = page.locator(".match-action-decisions__row").nth(1).getByRole("button");
  await expect(strokeButtons).toHaveText(["Blair Backhand", "Alex Ace"]);
  await page.getByRole("button", { name: /End Match Early/ }).click();
  await page.getByRole("radio", { name: "Draw / no winner" }).click();
  await page.getByRole("button", { name: "End Match", exact: true }).click();

  await expect.poll(() => endPayload).toBeTruthy();
  expect(endPayload.winner_side).toBe("draw");
  await expect(page.getByTestId("match-completed-summary")).toContainText("Draw / no winner");
  await expect(page.getByRole("button", { name: "Close completed match" })).toBeVisible();
});

test("fits racket scoring controls and point order into tablet landscape without page scrolling @racket", async ({ page }) => {
  const match = freshRacketMatch("squash", false);
  match.state.events.push({ id: "server", event_type: "server", payload: { current_server_side: "player1", service_side: "Right" } });
  await page.setViewportSize({ width: 1024, height: 600 });
  await page.route("**/get_score/web-squash-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/web-squash-1");
  await expect(page.locator(".club-page-header--match")).toHaveClass(/club-page-header--compact/);
  await expect(page.getByText("Match Timer", { exact: true })).toBeVisible();
  await expect(page.getByLabel("Match actions")).toBeVisible();
  await expect(page.getByLabel("Undo last action")).toBeVisible();
  await expect(page.getByLabel("Game settings")).toBeVisible();
  await expect(page.getByLabel("Point order")).toBeVisible();

  const viewport = page.viewportSize();
  for (const locator of [
    page.locator(".scoreboard-card"),
    page.locator(".match-timer-panel"),
    page.getByLabel("Undo last action"),
    page.getByLabel("Match actions"),
    page.getByLabel("Point order"),
  ]) {
    const box = await locator.boundingBox();
    expect(box).toBeTruthy();
    expect(box.y).toBeGreaterThanOrEqual(0);
    expect(box.y + box.height).toBeLessThanOrEqual(viewport.height + 1);
  }

  expect(await page.evaluate(() => document.scrollingElement.scrollHeight)).toBeLessThanOrEqual(viewport.height + 1);
});

test("uses a full-height native-style point rail on iPhone portrait @racket", async ({ page }) => {
  const match = freshRacketMatch("squash", false);
  match.state.events.push(
    { id: "server", event_type: "server", payload: { current_server_side: "player1", service_side: "Right" } },
    { id: "point-1", event_type: "score_point", payload: { scorer: "player1", player1_score: 1, current_server_side: "player1", service_side: "Left" } },
    { id: "point-2", event_type: "score_point", payload: { scorer: "player2", player2_score: 1, current_server_side: "player2", service_side: "Right" } },
  );
  await page.setViewportSize({ width: 402, height: 874 });
  await page.route("**/get_score/web-squash-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/web-squash-1");
  await expect(page.getByText("Match Details", { exact: true })).toHaveCount(0);
  await expect(page.locator(".scoreboard-point-marker--player1").first()).toHaveCSS("color", "rgb(18, 116, 208)");
  await expect(page.locator(".scoreboard-point-marker--player2").first()).toHaveCSS("color", "rgb(236, 61, 151)");
  await expect(page.locator(".match-control-grid__actions-icon path")).toHaveCount(3);

  const [gridBox, railBox, leftCardBox, rightCardBox] = await Promise.all([
    page.locator(".scoreboard-grid").boundingBox(),
    page.getByLabel("Point order").boundingBox(),
    page.locator(".player-card").nth(0).boundingBox(),
    page.locator(".player-card").nth(1).boundingBox(),
  ]);
  expect(railBox.x).toBeGreaterThanOrEqual(leftCardBox.x + leftCardBox.width - 1);
  expect(railBox.x + railBox.width).toBeLessThanOrEqual(rightCardBox.x + 1);
  expect(railBox.y).toBeGreaterThanOrEqual(gridBox.y);
  expect(railBox.y + railBox.height).toBeLessThanOrEqual(gridBox.y + gridBox.height + 1);
  expect(leftCardBox.height).toBeGreaterThanOrEqual(380);
  expect(rightCardBox.height).toBeGreaterThanOrEqual(380);
});

for (const viewportSize of [
  { name: "iPhone SE", width: 568, height: 320 },
  { name: "iPhone Pro Max", width: 932, height: 430 },
]) {
  test(`fits racket scoring into ${viewportSize.name} landscape without page scrolling @racket`, async ({ page }) => {
    const match = freshRacketMatch("squash", false);
    match.state.events.push({ id: "server", event_type: "server", payload: { current_server_side: "player1", service_side: "Right" } });
    await page.setViewportSize({ width: viewportSize.width, height: viewportSize.height });
    await page.route("**/get_score/web-squash-1", async (route) => {
      await route.fulfill({ json: envelope({ match }) });
    });

    await page.goto("/match/web-squash-1");
    await expect(page.locator(".club-page-header--match")).toBeVisible();
    await expect(page.getByText("Match Timer", { exact: true })).toBeVisible();
    await expect(page.getByLabel("Match actions")).toBeVisible();
    await expect(page.getByLabel("Undo last action")).toBeVisible();
    await expect(page.getByLabel("Game settings")).toBeVisible();
    await expect(page.getByLabel("Point order")).toBeVisible();

    const viewport = page.viewportSize();
    for (const locator of [
      page.locator(".club-page-header--match"),
      page.locator(".scoreboard-card"),
      page.locator(".match-timer-panel"),
      page.getByLabel("Match actions"),
      page.getByLabel("Undo last action"),
      page.getByLabel("Game settings"),
      page.getByLabel("Point order"),
    ]) {
      const box = await locator.boundingBox();
      expect(box).toBeTruthy();
      expect(box.y).toBeGreaterThanOrEqual(0);
      expect(box.y + box.height).toBeLessThanOrEqual(viewport.height + 1);
    }

    const pageOverflow = await page.evaluate(() => (
      document.scrollingElement.scrollHeight - document.scrollingElement.clientHeight
    ));
    expect(pageOverflow).toBeLessThanOrEqual(1);
  });
}
