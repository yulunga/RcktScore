const { test, expect } = require("@playwright/test");

const session = {
  username: "web-tennis@example.com",
  email: "web-tennis@example.com",
  first_name: "Web",
  surname: "Tester",
  organization_id: 50001,
  organization_name: "Web Tennis Test",
  organization_type: "personal",
  plan: "personal_plus",
  role: "admin",
  enabled_sports: ["tennis", "padel"],
  session_token: "playwright-session-token",
};

function envelope(data) {
  return { success: true, data };
}

function freshDoublesMatch() {
  return {
    id: "web-tennis-1",
    tenant_id: "50001",
    sport: "tennis",
    status: "active",
    court_name: "Personal Match",
    player1_name: "Alex / Blair",
    player2_name: "Casey / Drew",
    score_type: 6,
    best_of: 3,
    tennis_no_ad_scoring: true,
    tennis_final_set_match_tiebreak: true,
    state: {
      score_display_mode: "tennis",
      team_format: "doubles",
      tennis_no_ad_scoring: true,
      tennis_final_set_match_tiebreak: true,
      tennis_timed_breaks: true,
      player1_score: 0,
      player2_score: 0,
      player1_score_label: "0",
      player2_score_label: "0",
      player1_games_won: 0,
      player2_games_won: 0,
      player1_set_games: 0,
      player2_set_games: 0,
      current_game_number: 1,
      best_of: 3,
      score_type: 6,
      current_server_side: "player1",
      current_server_participant_id: "team1_player1",
      current_server: "Alex Ace",
      current_receiver_side: "player2",
      current_receiver_participant_id: "team2_player1",
      current_receiver: "Casey Court",
      service_side: "Right",
      game_history: [],
      events: [{ id: "start", event_type: "match_started", payload: {} }],
      tennis_teams: {
        player1: [
          { id: "team1_player1", first_name: "Alex", surname: "Ace", display_name: "Alex Ace", shirt_color: "navy" },
          { id: "team1_player2", first_name: "Blair", surname: "Backhand", display_name: "Blair Backhand", shirt_color: "white" },
        ],
        player2: [
          { id: "team2_player1", first_name: "Casey", surname: "Court", display_name: "Casey Court", shirt_color: "red" },
          { id: "team2_player2", first_name: "Drew", surname: "Deuce", display_name: "Drew Deuce", shirt_color: "green" },
        ],
      },
    },
  };
}

function liveTennisMatch() {
  const match = freshDoublesMatch();
  return {
    ...match,
    id: "web-tennis-live-1",
    state: {
      ...match.state,
      player1_score: 4,
      player2_score: 3,
      player1_score_label: "Ad",
      player2_score_label: "40",
      player1_games_won: 1,
      player2_games_won: 0,
      player1_set_games: 1,
      player2_set_games: 1,
      current_game_number: 2,
      current_server_participant_id: "team1_player2",
      current_server: "Blair Backhand",
      current_receiver_participant_id: "team2_player2",
      current_receiver: "Drew Deuce",
      service_side: "Left",
      game_history: [{ game_number: 1, player1_score: 6, player2_score: 4 }],
      events: [
        { id: "start", event_type: "match_started", payload: {} },
        {
          id: "point-1",
          event_type: "score_point",
          payload: {
            scorer: "player1",
            point_player1_score_label: "Ad",
            point_player2_score_label: "40",
          },
        },
      ],
    },
  };
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
  }, session);
});

test("creates tennis doubles metadata and configures the opening order @tennis", async ({ page }) => {
  let createPayload;
  let openingPayload;
  let match = freshDoublesMatch();

  await page.route("**/organization_settings/50001", async (route) => {
    await route.fulfill({ json: envelope({
      organizationSettings: {
        organization: { id: 50001, org_type: "personal", plan: "personal_plus", enabled_sports: ["tennis"] },
        users: [],
        courts: [],
      },
    }) });
  });
  await page.route("**/dashboard/50001*", async (route) => {
    await route.fulfill({ json: envelope({ dashboard: { active_matches: [], scheduled_matches: [], recent_matches: [] } }) });
  });
  await page.route("**/start_match", async (route) => {
    createPayload = route.request().postDataJSON();
    match = freshDoublesMatch();
    await route.fulfill({ json: envelope({ match }) });
  });
  await page.route("**/get_score/web-tennis-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });
  await page.route("**/event_action", async (route) => {
    openingPayload = route.request().postDataJSON();
    match = {
      ...match,
      state: {
        ...match.state,
        current_server: openingPayload.current_server,
        current_server_side: openingPayload.current_server_side,
        current_server_participant_id: openingPayload.current_server_participant_id,
        current_receiver: openingPayload.current_receiver,
        current_receiver_side: openingPayload.current_receiver_side,
        current_receiver_participant_id: openingPayload.current_receiver_participant_id,
        serve_order: openingPayload.serve_order,
        receiver_deuce_order: openingPayload.receiver_deuce_order,
      },
    };
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/new/setup?sport=tennis");
  await page.getByRole("radio", { name: "Doubles" }).click();
  await page.locator("#player1_name").fill("Alex");
  await page.locator("#player1_surname").fill("Ace");
  await page.locator("#player2_name").fill("Blair");
  await page.locator("#player2_surname").fill("Backhand");
  await page.locator("#player3_name").fill("Casey");
  await page.locator("#player3_surname").fill("Court");
  await page.locator("#player4_name").fill("Drew");
  await page.locator("#player4_surname").fill("Deuce");
  await page.getByLabel("Golden Point at 40-40").check();
  await page.getByLabel("Final-set 10-point match tiebreak").check();
  await page.getByLabel(/Timed breaks/).check();
  await page.getByRole("button", { name: "Start Match" }).click();

  await expect.poll(() => createPayload).toBeTruthy();
  expect(createPayload).toMatchObject({
    sport: "tennis",
    team_format: "doubles",
    team1_player1_name: "Alex",
    team1_player2_name: "Blair",
    team2_player1_name: "Casey",
    team2_player2_name: "Drew",
    team1_player1_shirt_color: "navy",
    team1_player2_shirt_color: "white",
    team2_player1_shirt_color: "blue",
    team2_player2_shirt_color: "red",
    tennis_no_ad_scoring: true,
    tennis_final_set_match_tiebreak: true,
    tennis_timed_breaks: true,
  });

  await page.getByRole("button", { name: "Skip Warm-Up" }).click();
  await expect(page.getByRole("heading", { name: "Opening Serve & Receive" })).toBeVisible();
  await page.getByLabel("Opening server").selectOption("team1_player2");
  await page.getByLabel("Opening receiver").selectOption("team2_player2");
  await page.getByRole("button", { name: "Begin Match" }).click();

  await expect.poll(() => openingPayload).toBeTruthy();
  expect(openingPayload).toMatchObject({
    action_type: "server",
    current_server: "Blair Backhand",
    current_server_side: "player1",
    current_server_participant_id: "team1_player2",
    current_receiver: "Drew Deuce",
    current_receiver_side: "player2",
    current_receiver_participant_id: "team2_player2",
    service_side: "Right",
    serve_order: ["team1_player2", "team2_player1", "team1_player1", "team2_player2"],
  });
  await expect(page.getByTestId("tennis-opening-order")).toBeHidden();
});

test("creates doubles-only Padel and chooses the Golden Point receiver @padel", async ({ page }) => {
  let createPayload;
  let openingPayload;
  let receiverChoicePayload;
  let match = { ...freshDoublesMatch(), id: "web-padel-1", sport: "padel" };

  await page.route("**/organization_settings/50001", async (route) => {
    await route.fulfill({ json: envelope({ organizationSettings: {
      organization: { id: 50001, org_type: "personal", plan: "personal_plus", enabled_sports: ["tennis", "padel"] },
      users: [],
      courts: [],
    } }) });
  });
  await page.route("**/dashboard/50001*", async (route) => {
    await route.fulfill({ json: envelope({ dashboard: { active_matches: [], scheduled_matches: [], recent_matches: [] } }) });
  });
  await page.route("**/start_match", async (route) => {
    createPayload = route.request().postDataJSON();
    await route.fulfill({ json: envelope({ match }) });
  });
  await page.route("**/get_score/web-padel-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });
  await page.route("**/event_action", async (route) => {
    const payload = route.request().postDataJSON();
    if (payload.action_type === "server") {
      openingPayload = payload;
      match = {
        ...match,
        state: {
          ...match.state,
          player1_score: 3,
          player2_score: 3,
          current_server_side: payload.current_server_side,
          current_receiver_side: payload.current_receiver_side,
          receiver_deuce_order: payload.receiver_deuce_order,
          no_ad_deciding_side: null,
        },
      };
    } else if (payload.action_type === "receiver_choice") {
      receiverChoicePayload = payload;
      match = { ...match, state: { ...match.state, no_ad_deciding_side: payload.side, service_side: payload.side } };
    }
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/new/setup?sport=padel");
  await expect(page.getByText("Padel is doubles-only", { exact: false })).toBeVisible();
  await expect(page.getByRole("radio", { name: "Singles" })).toHaveCount(0);
  await page.locator("#player1_name").fill("Alex");
  await page.locator("#player2_name").fill("Blair");
  await page.locator("#player3_name").fill("Casey");
  await page.locator("#player4_name").fill("Drew");
  await page.getByLabel("Golden Point at 40-40").check();
  await page.getByLabel(/Timed breaks/).check();
  await page.getByRole("button", { name: "Start Match" }).click();

  await expect.poll(() => createPayload).toBeTruthy();
  expect(createPayload).toMatchObject({
    sport: "padel",
    team_format: "doubles",
    team1_player1_name: "Alex",
    team1_player2_name: "Blair",
    team2_player1_name: "Casey",
    team2_player2_name: "Drew",
    tennis_no_ad_scoring: true,
    tennis_final_set_match_tiebreak: false,
    tennis_timed_breaks: true,
  });

  await page.getByRole("button", { name: "Skip Warm-Up" }).click();
  await page.getByLabel("Opening server").selectOption("team1_player1");
  await page.getByLabel("Opening receiver").selectOption("team2_player1");
  await page.getByRole("button", { name: "Begin Match" }).click();
  await expect.poll(() => openingPayload).toBeTruthy();

  await expect(page.getByTestId("padel-receiver-choice")).toBeVisible();
  await page.getByRole("button", { name: /Casey Court · Right/ }).click();
  await expect.poll(() => receiverChoicePayload).toMatchObject({ action_type: "receiver_choice", side: "Right" });
  await expect(page.getByTestId("padel-receiver-choice")).toBeHidden();
});

test("presents tennis points, rotation and timed changeovers without racket actions @tennis", async ({ page }) => {
  let scorePayload;
  let scoreCallCount = 0;
  let match = liveTennisMatch();

  await page.route("**/get_score/web-tennis-live-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });
  await page.route("**/score_point", async (route) => {
    scorePayload = route.request().postDataJSON();
    scoreCallCount += 1;
    const setCompleted = scoreCallCount === 2;
    match = {
      ...match,
      state: {
        ...match.state,
        player1_score: 0,
        player2_score: 0,
        player1_score_label: "0",
        player2_score_label: "0",
        player1_games_won: setCompleted ? 1 : match.state.player1_games_won,
        player2_games_won: setCompleted ? 1 : match.state.player2_games_won,
        player1_set_games: setCompleted ? 0 : 2,
        player2_set_games: setCompleted ? 0 : 1,
        current_server_side: "player2",
        current_server_participant_id: "team2_player1",
        current_server: "Casey Court",
        current_receiver_side: "player1",
        current_receiver_participant_id: "team1_player1",
        current_receiver: "Alex Ace",
        service_side: "Right",
        game_history: setCompleted
          ? [...match.state.game_history, { game_number: 2, player1_score: 4, player2_score: 6 }]
          : match.state.game_history,
        events: [
          ...match.state.events,
          {
            id: setCompleted ? "set-2" : "game-3",
            event_type: "score_point",
            payload: {
              scorer: scorePayload.scorer,
              tennis_game_completed: true,
              completed_game_number: setCompleted ? 10 : 3,
              completed_game_player1_games: setCompleted ? 4 : 2,
              completed_game_player2_games: setCompleted ? 6 : 1,
              set_completed: setCompleted,
            },
          },
        ],
      },
    };
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/web-tennis-live-1");
  await expect(page.getByTestId("tennis-scoreboard")).toBeVisible();
  await expect(page.getByTestId("tennis-score-player1")).toContainText("Ad");
  await expect(page.getByTestId("tennis-score-player2")).toContainText("40");
  await expect(page.getByTestId("tennis-serve-status")).toContainText("Serving: Blair Backhand");
  await expect(page.getByTestId("tennis-serve-status")).toContainText("Receiving: Drew Deuce");
  await expect(page.getByTestId("tennis-serve-status")).toContainText("Ad court");
  await expect(page.getByText("Set 1: 6–4")).toBeVisible();
  await expect(page.getByRole("button", { name: "Stroke P1" })).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Let", exact: true })).toHaveCount(0);

  await page.getByTestId("tennis-score-player1").click();
  await expect.poll(() => scorePayload).toBeTruthy();
  expect(scorePayload.match_id).toBe("web-tennis-live-1");
  expect(scorePayload.scorer).toBe("player1");
  expect(scorePayload.client_action_id).toMatch(/^[0-9a-f-]{36}$/i);
  const changeover = page.locator(".overlay-panel", { has: page.getByRole("heading", { name: "Changeover" }) });
  await expect(changeover).toBeVisible();
  await expect(changeover.getByRole("button", { name: "01:30" })).toBeVisible();
  await changeover.getByRole("button", { name: "Skip Break" }).click();
  await expect(page.getByTestId("tennis-serve-status")).toContainText("Serving: Casey Court");
  await expect(page.getByTestId("tennis-serve-status")).toContainText("Deuce court");

  await page.getByTestId("tennis-score-player2").click();
  const setBreak = page.locator(".overlay-panel", { has: page.getByRole("heading", { name: "Set Break" }) });
  await expect(setBreak).toBeVisible();
  await expect(setBreak.getByRole("button", { name: "02:00" })).toBeVisible();
  await setBreak.getByRole("button", { name: "Skip Break" }).click();
});

test("presents tiebreaks and a tennis completion summary @tennis", async ({ page }) => {
  let match = liveTennisMatch();
  match = {
    ...match,
    id: "web-tennis-result-1",
    state: {
      ...match.state,
      is_tie_break: true,
      player1_score: 6,
      player2_score: 5,
      player1_score_label: "6",
      player2_score_label: "5",
      player1_set_games: 6,
      player2_set_games: 6,
    },
  };

  await page.route("**/get_score/web-tennis-result-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/web-tennis-result-1");
  await expect(page.getByText("Tiebreak", { exact: true })).toBeVisible();
  await expect(page.getByTestId("tennis-score-player1")).toContainText("6");
  await expect(page.getByTestId("tennis-score-player2")).toContainText("5");

  match = {
    ...match,
    status: "completed",
    winner_name: "Alex Ace / Blair Backhand",
    state: {
      ...match.state,
      match_complete: true,
      winner_name: "Alex Ace / Blair Backhand",
      is_tie_break: false,
      is_match_tiebreak: false,
      player1_games_won: 2,
      player2_games_won: 1,
    },
  };
  await page.reload();
  await expect(page.getByTestId("tennis-completion-summary")).toContainText("Tennis Match Complete");
  await expect(page.getByTestId("tennis-completion-summary")).toContainText("Alex Ace / Blair Backhand");
  await expect(page.getByTestId("tennis-completion-summary")).toContainText("2–1 sets");
});
