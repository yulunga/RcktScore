const { test, expect } = require("@playwright/test");

const session = {
  username: "history@example.com",
  organization_id: 50002,
  organization_name: "History Test",
  organization_type: "personal",
  plan: "personal_plus",
  role: "admin",
  session_token: "playwright-history-session",
};

function envelope(data) {
  return { success: true, data };
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
  }, session);
  await page.route("**/notifications/50002*", async (route) => {
    await route.fulfill({ json: envelope({ notifications: [] }) });
  });
});

test("shows a dedicated Squash historic match with game durations and a structured timeline @history", async ({ page }) => {
  const match = {
    id: "historic-squash-1",
    sport: "squash",
    status: "completed",
    created_at: "2026-09-20T09:00:00Z",
    completed_at: "2026-09-20T09:32:00Z",
    match_duration_seconds: 1920,
    court_name: "Court 1",
    player1_name: "Alex",
    player1_surname: "Ace",
    player2_name: "Blair",
    player2_surname: "Backhand",
    referee_name: "Sam Referee",
    score_type: 15,
    best_of: 3,
    handicap_enabled: true,
    player1_offset: -2,
    player2_offset: 2,
    state: {
      player1_games_won: 2,
      player2_games_won: 0,
      best_of: 3,
      score_type: 15,
      match_duration_seconds: 1920,
      game_history: [
        { game_number: 1, player1_score: 15, player2_score: 10 },
        { game_number: 2, player1_score: 15, player2_score: 12 },
      ],
      events: [
        { id: "start", event_type: "match_started", created_at: "2026-09-20T09:00:00Z", payload: {} },
        { id: "g1-1", event_type: "score_point", created_at: "2026-09-20T09:02:00Z", payload: { game_number: 1, scorer: "player1", player1_score: 1, player2_score: 2, current_server_side: "player1", service_side: "Right" } },
        { id: "g1-2", event_type: "stroke", created_at: "2026-09-20T09:12:00Z", payload: { game_number: 1, scorer: "player1", player1_score: 15, player2_score: 10, current_server_side: "player1", service_side: "Left" } },
        { id: "g2-1", event_type: "score_point", created_at: "2026-09-20T09:16:00Z", payload: { game_number: 2, scorer: "player2", player1_score: 3, player2_score: 4, current_server_side: "player2", service_side: "Right" } },
        { id: "g2-2", event_type: "score_point", created_at: "2026-09-20T09:31:00Z", payload: { game_number: 2, scorer: "player1", player1_score: 15, player2_score: 12, current_server_side: "player1", service_side: "Left" } },
      ],
    },
  };

  await page.route("**/get_score/historic-squash-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/historic-squash-1/history");
  await expect(page.getByTestId("historic-match-page")).toBeVisible();
  await expect(page.getByText("Squash", { exact: true })).toBeVisible();
  await expect(page.getByText("Handicap -2 | 2 • Best of 3 games • PAR-15")).toBeVisible();
  await expect(page.getByText(/20 Sep(?:t)? 2026/)).toBeVisible();
  await expect(page.getByText("10:00")).toBeVisible();
  await expect(page.getByText("32:00")).toBeVisible();
  await expect(page.getByText("Game 1", { exact: true })).toBeVisible();
  await expect(page.getByText("Stroke to", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: /Match Time/ }).click();
  const durations = page.getByTestId("historic-segment-durations");
  await expect(durations).toContainText("Game 1");
  await expect(durations).toContainText("10:00");
  await expect(durations).toContainText("Game 2");
  await expect(durations).toContainText("15:00");
});

test("uses tennis terminology, point labels, and separate game/set dividers @history", async ({ page }) => {
  const match = {
    id: "historic-tennis-1",
    sport: "tennis",
    status: "completed",
    created_at: "2026-09-21T13:00:00Z",
    match_duration_seconds: 3600,
    court_name: "Centre Court",
    player1_name: "Alex",
    player1_surname: "Ace",
    player2_name: "Blair",
    player2_surname: "Backhand",
    best_of: 3,
    state: {
      score_display_mode: "tennis",
      player1_games_won: 2,
      player2_games_won: 0,
      best_of: 3,
      score_type: 6,
      tennis_no_ad_scoring: false,
      match_duration_seconds: 3600,
      game_history: [
        { game_number: 1, player1_score: 6, player2_score: 4 },
        { game_number: 2, player1_score: 7, player2_score: 5 },
      ],
      events: [
        { id: "start", event_type: "match_started", created_at: "2026-09-21T13:00:00Z", payload: {} },
        { id: "s1-p1", event_type: "score_point", created_at: "2026-09-21T13:02:00Z", payload: { game_number: 1, scorer: "player1", point_player1_score_label: "15", point_player2_score_label: "0" } },
        { id: "s1-game", event_type: "score_point", created_at: "2026-09-21T13:27:00Z", payload: { game_number: 1, scorer: "player1", point_player1_score_label: "Game", point_player2_score_label: "30", tennis_game_completed: true, completed_game_player1_games: 6, completed_game_player2_games: 4, set_completed: true } },
        { id: "s2-p1", event_type: "score_point", created_at: "2026-09-21T13:31:00Z", payload: { game_number: 2, scorer: "player2", point_player1_score_label: "40", point_player2_score_label: "Ad" } },
        { id: "s2-game", event_type: "score_point", created_at: "2026-09-21T14:00:00Z", payload: { game_number: 2, scorer: "player1", point_player1_score_label: "Game", point_player2_score_label: "40", tennis_game_completed: true, completed_game_player1_games: 7, completed_game_player2_games: 5, set_completed: true, match_completed: true } },
      ],
    },
  };

  await page.route("**/get_score/historic-tennis-1", async (route) => {
    await route.fulfill({ json: envelope({ match }) });
  });

  await page.goto("/match/historic-tennis-1/history");
  await expect(page.getByText("Tennis", { exact: true })).toBeVisible();
  await expect(page.getByText("Best of 3 sets • Advantage scoring")).toBeVisible();
  await expect(page.getByText("Set 1", { exact: true })).toBeVisible();
  await expect(page.getByText("40–Ad", { exact: true })).toBeVisible();
  await expect(page.getByTestId("historic-game-divider")).toHaveCount(2);
  await expect(page.getByTestId("historic-set-divider")).toHaveCount(1);
  await expect(page.getByText("Game, Set and Match", { exact: true })).toBeVisible();
});
