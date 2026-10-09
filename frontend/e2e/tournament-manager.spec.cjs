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
  draws: ["A", "B", "C", "D"].map((grade) => ({ id: `draw-${grade}`, name: `Grade ${grade}`, grade, status: "draft", matches: [] })),
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
  const panels = page.locator(".tournament-manager-grid > .panel");
  const [leftPanel, rightPanel] = await Promise.all([panels.nth(0).boundingBox(), panels.nth(1).boundingBox()]);
  expect(Math.abs(leftPanel.width - rightPanel.width)).toBeLessThan(2);
  expect(rightPanel.height).toBeLessThan(leftPanel.height);
});

test("labels a published tournament as draw ready with an explicit view action @tournament", async ({ page }) => {
  await page.route("**/organizations/77/tournaments", async (route) => route.fulfill({
    json: envelope({ tournaments: [{ ...tournament, status: "draw_published" }] }),
  }));

  await page.goto("/tournaments");

  await expect(page.getByText("Draw ready", { exact: true })).toBeVisible();
  await expect(page.getByText("View Draw", { exact: true })).toBeVisible();
  await expect(page.getByText("draw published", { exact: false })).toHaveCount(0);
});

test("shows event identity in the summary and uses search-first player entry @tournament", async ({ page }) => {
  await page.route(`**/tournaments/${tournament.id}?*`, async (route) => route.fulfill({
    json: envelope({ tournament }),
  }));
  await page.route("**/organizations/77/tournament-players?q=alex", async (route) => route.fulfill({
    json: envelope({ players: ["Alex Player", "Alex Park", "Alex Price", "Alex Palmer", "Alex Porter"].map((name, index) => ({
      player_id: `e1cbcc2a-d9bd-48b4-96c9-5643140d230${index}`,
      user_id: null,
      first_name: "Alex",
      surname: name.split(" ")[1],
      display_name: name,
      email: `alex${index}@example.com`,
      home_club_name: "Away Club",
      relationship: "guest",
    })) }),
  }));

  await page.goto(`/tournaments/${tournament.id}`);

  await expect(page.locator(".club-page-header__page-title")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "All Tournaments" })).toHaveCount(0);
  await expect(page.getByRole("heading", { name: tournament.name })).toBeVisible();
  await expect(page.getByText("Squash · Knockout with Plate", { exact: true })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Event Summary" })).toHaveCount(0);
  const summaryRows = page.locator(".tournament-summary-details > span");
  await expect(summaryRows).toHaveCount(5);
  await expect(summaryRows.nth(0)).toContainText("Venue:");
  await expect(summaryRows.nth(1)).toContainText("Start:");
  await expect(summaryRows.nth(1)).toContainText("End:");
  await expect(summaryRows.nth(2)).toHaveText("Open tournament");
  await expect(summaryRows.nth(3)).toHaveText("Graded tournament");
  await expect(summaryRows.nth(4)).toContainText("Size limit:");
  await expect(page.getByLabel("Country")).toHaveCount(0);
  await expect(page.getByLabel("Seed")).toHaveCount(0);

  await page.getByLabel("Search Players").fill("alex");
  await expect(page.getByRole("button", { name: "Search", exact: true })).toHaveCount(0);
  await expect(page.getByText("Alex Player", { exact: true })).toBeVisible();
  await expect(page.locator(".tournament-search-result")).toHaveCount(4);
  await expect(page.getByText("Alex Porter", { exact: true })).toHaveCount(0);
  await page.getByRole("button", { name: /Alex Player/ }).click();
  await expect(page.locator(".tournament-search-result")).toHaveCount(1);
  await expect(page.getByText("Alex Park", { exact: true })).toHaveCount(0);
  await expect(page.locator(".tournament-ability-option").first()).toContainText("Grade A");
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

test("previews CSV duplicates and locks linked account identity fields @tournament", async ({ page }) => {
  const tournamentWithEntries = {
    ...tournament,
    entry_count: 2,
    entries: [
      {
        id: "11111111-1111-4111-8111-111111111111",
        player_id: "21111111-1111-4111-8111-111111111111",
        first_name: "Alex",
        surname: "Guest",
        display_name: "Alex Guest",
        email: "alex.guest@example.com",
        home_club_name: "Away Club",
        ability_level: 2,
        ability_grade: "B",
        relationship: "guest",
        claim_status: "claimable",
      },
      {
        id: "31111111-1111-4111-8111-111111111111",
        player_id: "41111111-1111-4111-8111-111111111111",
        user_id: "51111111-1111-4111-8111-111111111111",
        first_name: "Casey",
        surname: "Member",
        display_name: "Casey Member",
        email: "casey@example.com",
        home_club_name: "Demo Club",
        ability_level: 3,
        ability_grade: "C",
        relationship: "member",
        claim_status: "linked",
      },
    ],
  };
  await page.route(`**/tournaments/${tournament.id}?*`, async (route) => route.fulfill({
    json: envelope({ tournament: tournamentWithEntries }),
  }));
  await page.route("**/organizations/77/tournament-players?*", async (route) => route.fulfill({
    json: envelope({ players: [] }),
  }));

  await page.goto(`/tournaments/${tournament.id}`);
  await expect(page.getByRole("heading", { name: "Add Players" })).toBeVisible();
  await expect(page.getByText("Grade B", { exact: true })).toHaveCSS("background-color", "rgb(207, 231, 255)");
  await expect(page.getByText("Grade C", { exact: true })).toHaveCSS("background-color", "rgb(204, 239, 217)");
  await page.getByRole("button", { name: "Import Players" }).click();
  await page.locator("#tournament-player-import").setInputFiles({
    name: "players.csv",
    mimeType: "text/csv",
    buffer: Buffer.from([
      "First Name,Surname,Email,Club,Ability",
      "Demo,PlayOne,playone@example.com,Demo Club,2",
      "Demo,PlayOne,playone@example.com,Demo Club,3",
      "Missing,,missing@example.com,Demo Club,1",
    ].join("\n")),
  });
  await expect(page.getByText("Duplicate row in this import", { exact: true })).toBeVisible();
  await expect(page.getByText("First name and surname are required", { exact: true })).toBeVisible();
  await expect(page.getByLabel("Duplicate action for Demo PlayOne")).toBeVisible();

  await page.getByRole("button", { name: "Edit Player" }).nth(1).click();
  await expect(page.getByLabel("Email Address").last()).toBeDisabled();
  await expect(page.getByLabel("Home Club").last()).toBeDisabled();
  await expect(page.getByText("Email and home club come from the existing HitNScore account", { exact: false })).toBeVisible();
});

test("displays a published opening draw and locks entries @tournament", async ({ page }) => {
  const entries = [
    { id: "entry-1", display_name: "Demo PlayOne", first_name: "Demo", surname: "PlayOne", ability_level: 1, ability_grade: "A", relationship: "member", claim_status: "linked" },
    { id: "entry-2", display_name: "Demo PlayTwo", first_name: "Demo", surname: "PlayTwo", ability_level: 1, ability_grade: "A", relationship: "member", claim_status: "linked" },
  ];
  const readyTournament = { ...tournament, graded_enabled: false, entry_count: 2, entries, draws: [{ id: "open-draw", name: "Open Draw", grade: null, status: "draft", matches: [] }] };
  const publishedTournament = {
    ...readyTournament,
    status: "draw_published",
    draws: [{
      id: "open-draw",
      name: "Open Draw",
      grade: null,
      status: "published",
      matches: [{ id: "match-1", round_number: 1, match_number: 1, status: "pending", player1_name: "Demo PlayOne", player2_name: "Demo PlayTwo" }],
    }],
  };
  await page.route(`**/tournaments/${tournament.id}?*`, async (route) => route.fulfill({ json: envelope({ tournament: readyTournament }) }));
  await page.route(`**/tournaments/${tournament.id}/draw`, async (route) => route.fulfill({ json: envelope({ tournament: publishedTournament }) }));

  await page.goto(`/tournaments/${tournament.id}`);
  await page.getByRole("button", { name: "Generate Draw" }).click();

  await expect(page.getByRole("heading", { name: "Open Draw" })).toBeVisible();
  await expect(page.locator(".tournament-bracket-match").getByText("Demo PlayOne", { exact: true })).toBeVisible();
  await expect(page.locator(".tournament-bracket-match").getByText("Demo PlayTwo", { exact: true })).toBeVisible();
  await expect(page.getByText("Player entries are locked because the draw has been published.")).toBeVisible();
  await expect(page.getByLabel("Search Players")).toHaveCount(0);
});

test("repairs a draw-ready tournament when fixture data is missing @tournament", async ({ page }) => {
  const entries = [
    { id: "entry-1", display_name: "Demo PlayOne", first_name: "Demo", surname: "PlayOne", ability_level: 1, ability_grade: "A", relationship: "member", claim_status: "linked" },
    { id: "entry-2", display_name: "Demo PlayTwo", first_name: "Demo", surname: "PlayTwo", ability_level: 1, ability_grade: "A", relationship: "member", claim_status: "linked" },
  ];
  const missingTournament = { ...tournament, status: "draw_published", graded_enabled: false, entry_count: 2, entries, draws: [{ id: "open-draw", name: "Open Draw", grade: null, status: "published", matches: [] }] };
  const repairedTournament = {
    ...missingTournament,
    draws: [{ id: "open-draw", name: "Open Draw", grade: null, status: "published", matches: [{ id: "match-1", round_number: 1, match_number: 1, status: "pending", player1_name: "Demo PlayOne", player2_name: "Demo PlayTwo" }] }],
  };
  await page.route(`**/tournaments/${tournament.id}?*`, async (route) => route.fulfill({ json: envelope({ tournament: missingTournament }) }));
  await page.route(`**/tournaments/${tournament.id}/draw`, async (route) => route.fulfill({ json: envelope({ tournament: repairedTournament }) }));

  await page.goto(`/tournaments/${tournament.id}`);
  await expect(page.getByText("Draw needs rebuilding", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Rebuild Missing Draw" }).click();

  await expect(page.getByText("Draw ready", { exact: true })).toBeVisible();
  await expect(page.locator(".tournament-bracket-match")).toContainText("Demo PlayOne");
});

test("reviews, publishes and safely returns a seeded knockout draw to draft @tournament", async ({ page }) => {
  const entries = [
    { id: "entry-1", display_name: "Seed One", first_name: "Seed", surname: "One", seed: 1, ability_level: 1, ability_grade: "A", relationship: "member", claim_status: "linked" },
    { id: "entry-2", display_name: "Seed Two", first_name: "Seed", surname: "Two", seed: 2, ability_level: 1, ability_grade: "A", relationship: "member", claim_status: "linked" },
    { id: "entry-3", display_name: "Seed Three", first_name: "Seed", surname: "Three", seed: 3, ability_level: 1, ability_grade: "A", relationship: "member", claim_status: "linked" },
    { id: "entry-4", display_name: "Seed Four", first_name: "Seed", surname: "Four", seed: 4, ability_level: 1, ability_grade: "A", relationship: "member", claim_status: "linked" },
  ];
  const draftDraw = {
    ...tournament,
    draw_format: "knockout",
    graded_enabled: false,
    status: "draft",
    entry_count: 4,
    entries,
    draws: [{
      id: "open-draw",
      name: "Open Draw",
      status: "draft",
      matches: [
        { id: "match-1", round_number: 1, match_number: 1, status: "pending", player1_entry_id: "entry-1", player2_entry_id: "entry-4", player1_name: "Seed One", player2_name: "Seed Four" },
        { id: "match-2", round_number: 1, match_number: 2, status: "pending", player1_entry_id: "entry-2", player2_entry_id: "entry-3", player1_name: "Seed Two", player2_name: "Seed Three" },
      ],
    }],
  };
  const publishedDraw = { ...draftDraw, status: "draw_published", public_draw_key: "DRAWKEY23456", public_draw_enabled: true, draws: draftDraw.draws.map((draw) => ({ ...draw, status: "published" })) };
  await page.route(`**/tournaments/${tournament.id}?*`, async (route) => route.fulfill({ json: envelope({ tournament: draftDraw }) }));
  await page.route(`**/tournaments/${tournament.id}/draw/publish`, async (route) => route.fulfill({ json: envelope({ tournament: publishedDraw }) }));
  await page.route(`**/tournaments/${tournament.id}/draw/draft`, async (route) => route.fulfill({ json: envelope({ tournament: draftDraw }) }));

  await page.goto(`/tournaments/${tournament.id}`);
  await expect(page.getByText("Draft draw", { exact: true })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Open Draw — Championship" })).toBeVisible();
  await expect(page.locator(".tournament-bracket-round")).toHaveCount(2);
  await expect(page.getByLabel("Move Seed One in the draw")).toBeVisible();
  await page.getByRole("button", { name: "Publish Draw" }).click();
  await expect(page.getByText("DRAWKEY23456", { exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: "Open Public Draw" })).toBeVisible();

  page.once("dialog", (dialog) => dialog.accept());
  await page.getByRole("button", { name: "Return Draw to Draft" }).click();
  await expect(page.getByText("Draft draw", { exact: true })).toBeVisible();
});

test("opens a published draw without login using its public key @tournament", async ({ page }) => {
  const publicTournament = {
    ...tournament,
    status: "draw_published",
    entries: [],
    draws: [{ id: "open-draw", name: "Open Draw", status: "published", matches: [{ id: "match-1", round_number: 1, player1_name: "Public One", player2_name: "Public Two" }] }],
  };
  await page.route("**/public/tournament-draws/DRAWKEY23456", async (route) => route.fulfill({ json: envelope({ tournament: publicTournament }) }));

  await page.goto("/tournament-draw/DRAWKEY23456");

  await expect(page.getByText("Public Tournament Draw", { exact: true })).toBeVisible();
  await expect(page.getByRole("heading", { name: tournament.name })).toBeVisible();
  await expect(page.locator(".tournament-bracket-match")).toContainText("Public One");
});
