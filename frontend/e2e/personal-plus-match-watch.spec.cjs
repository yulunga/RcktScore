const { test, expect } = require("@playwright/test");

const session = {
  username: "watcher@example.com",
  email: "watcher@example.com",
  first_name: "Remote",
  surname: "Viewer",
  organization_id: 50003,
  organization_name: "Personal Plus Test",
  organization_type: "personal",
  plan: "personal_plus",
  role: "admin",
  enabled_sports: ["squash", "racketball", "tennis", "padel"],
  session_token: "playwright-watch-session",
};

function envelope(data) {
  return { success: true, data };
}

function remoteMatch(status = "active") {
  const finished = status === "completed";
  return {
    id: "remote-match-1",
    sport: "squash",
    status,
    player1_name: "Jamie",
    player1_surname: "Drive",
    player2_name: "Morgan",
    player2_surname: "Drop",
    player1_games_won: finished ? 3 : 1,
    player2_games_won: finished ? 1 : 0,
    state: {
      player1_score: finished ? 11 : 7,
      player2_score: finished ? 8 : 5,
      player1_games_won: finished ? 3 : 1,
      player2_games_won: finished ? 1 : 0,
      match_complete: finished,
      events: [{
        id: "point-1",
        event_type: "score_point",
        created_at: "2026-10-17T12:00:00Z",
        summary: "Jamie won the point",
        payload: { scorer: "player1", player1_score: 7, player2_score: 5 },
      }],
    },
  };
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
  }, session);
});

test("Personal Plus opens a live match code and saves it to Viewed Matches @watch-match", async ({ page }) => {
  let saved = false;
  const match = remoteMatch();

  await page.route("**/dashboard/50003*", async (route) => {
    await route.fulfill({ json: envelope({ dashboard: {
      organization: { id: 50003, type: "personal", plan: "personal_plus" },
      active_matches: [],
      scheduled_matches: [],
      recent_matches: [],
      viewed_matches: [],
    } }) });
  });
  await page.route("**/match_watch/lookup", async (route) => {
    expect(route.request().postDataJSON()).toEqual({ organization_id: 50003, code: "ABCD2345" });
    await route.fulfill({ json: envelope({ watch: { code: "ABCD2345", saved, finished: false, match } }) });
  });
  await page.route("**/match_watch/save", async (route) => {
    expect(route.request().postDataJSON()).toEqual({ organization_id: 50003, code: "ABCD2345" });
    saved = true;
    await route.fulfill({ json: envelope({ watch: { code: "ABCD2345", saved, finished: false, match } }) });
  });

  await page.goto("/matches");
  await page.getByLabel("Match viewing code").fill("abcd-2345");
  await page.getByRole("button", { name: "Watch Match" }).click();

  await expect(page).toHaveURL(/\/matches\/watch\/ABCD2345$/);
  await expect(page.getByRole("heading", { name: "Watching live match" })).toBeVisible();
  await expect(page.getByText("Jamie Drive").first()).toBeVisible();
  await expect(page.getByText("Morgan Drop").first()).toBeVisible();
  await page.getByRole("button", { name: "Add to Viewed Matches" }).click();
  await expect(page.getByText("Added to Viewed Matches")).toBeVisible();
});

test("a completed viewing code shows the result and timeline @watch-match", async ({ page }) => {
  const match = remoteMatch("completed");
  await page.route("**/match_watch/lookup", async (route) => {
    await route.fulfill({ json: envelope({ watch: {
      code: "WXYZ6789",
      saved: true,
      finished: true,
      match,
    } }) });
  });

  await page.goto("/matches/watch/WXYZ6789");
  await expect(page.getByRole("heading", { name: "This match has finished" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Result Timeline" })).toBeVisible();
  await expect(page.getByText("Jamie won the point")).toBeVisible();
  await expect(page.getByText("Added to Viewed Matches")).toBeVisible();
});
