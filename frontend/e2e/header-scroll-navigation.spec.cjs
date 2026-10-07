const { test, expect } = require("@playwright/test");

const session = {
  username: "header@example.com",
  organization_id: 42,
  organization_name: "Header Test Club",
  organization_type: "club",
  plan: "club_essentials",
  role: "admin",
  session_token: "playwright-header-session",
};

const completedMatches = [
  {
    id: 901,
    player1_name: "Alex",
    player1_surname: "Andrews",
    player2_name: "Jamie",
    player2_surname: "Jones",
    winner_side: "player1",
    player1_games_won: 3,
    player2_games_won: 1,
    updated_at: "2026-10-06T18:30:00Z",
    state: { game_history: [{ player1_score: 11, player2_score: 7 }] },
  },
  {
    id: 902,
    player1_name: "Robin",
    player1_surname: "Reed",
    player2_name: "Morgan",
    player2_surname: "Miles",
    winner_side: "player2",
    player1_games_won: 1,
    player2_games_won: 3,
    updated_at: "2026-10-05T17:15:00Z",
    state: { game_history: [{ player1_score: 8, player2_score: 11 }] },
  },
];

function envelope(data) {
  return { success: true, data };
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
  }, session);
  await page.route("**/notifications/42*", async (route) => {
    await route.fulfill({ json: envelope({ notifications: [] }) });
  });
  await page.route("**/dashboard/42*", async (route) => {
    await route.fulfill({ json: envelope({ dashboard: {
      organization: { id: 42, name: "Header Test Club", type: "club", plan: "club_essentials", enabled_sports: ["squash"] },
      active_matches: [],
      scheduled_matches: [],
      recent_matches: completedMatches,
    } }) });
  });
});

test("keeps the signed-in header width fixed while compacting its menu on scroll @header", async ({ page }) => {
  await page.goto("/dashboard");

  const header = page.locator(".club-page-header");
  const startMatch = page.locator(".dashboard-start-hero");
  await expect(header).toBeVisible();
  await expect(page.getByText("Manage live scoring, keep an eye on active courts, and review recent matches.")).toHaveCount(0);
  await expect(page.getByText(session.username, { exact: true })).toHaveCount(0);
  await expect(page.getByText(session.organization_name, { exact: true })).toHaveCount(0);
  await expect(page.getByText(/RcktScore v\d/)).toHaveCount(0);
  await expect(page.getByText(/build \d+/)).toHaveCount(0);
  await expect(startMatch).toBeVisible();
  await expect(startMatch).toHaveCSS("color", "rgb(255, 255, 255)");

  const viewport = page.viewportSize();
  let initialHomeBox = null;
  if (viewport.width > 840) {
    const primaryNavigation = header.getByRole("navigation", { name: "Primary navigation" });
    const homeButton = primaryNavigation.getByRole("button", { name: "Home" });
    const newMatchButton = primaryNavigation.getByRole("button", { name: "Start New Match" });
    await expect(homeButton).toBeVisible();
    await expect(newMatchButton).toBeVisible();
    await expect(header.getByRole("button", { name: "Matches" })).toBeVisible();
    await expect(header.getByRole("button", { name: "Analytics" })).toBeVisible();
    await expect(header.getByRole("button", { name: "Settings" })).toBeVisible();
    await expect(header.getByRole("button", { name: "Help" })).toBeVisible();
    await expect(newMatchButton).toHaveCSS("background-color", "rgba(0, 0, 0, 0)");
    await expect(newMatchButton).toHaveCSS("color", "rgb(18, 116, 208)");
    await expect(newMatchButton).toHaveCSS("border-top-style", "solid");
    await expect(newMatchButton).toHaveCSS("border-top-width", "1px");
    await expect(newMatchButton).toHaveCSS("border-top-color", "rgb(122, 165, 216)");
    await expect(primaryNavigation.getByRole("button")).toHaveCount(6);
    const logoutBox = await header.getByRole("button", { name: "Logout" }).boundingBox();
    const helpLabelBox = await header.getByRole("button", { name: "Help" }).locator(".club-page-header__menu-label").boundingBox();
    expect(Math.abs((logoutBox.x + logoutBox.width) - (helpLabelBox.x + helpLabelBox.width))).toBeLessThanOrEqual(1);
    initialHomeBox = await homeButton.boundingBox();
  }

  if (viewport.width >= 1100) {
    const historyCards = page.locator(".dashboard-list--history.dashboard-list--desktop .dashboard-history-card");
    await expect(historyCards).toHaveCount(2);
    const firstHistoryCard = await historyCards.nth(0).boundingBox();
    const secondHistoryCard = await historyCards.nth(1).boundingBox();
    expect(Math.abs(firstHistoryCard.y - secondHistoryCard.y)).toBeLessThanOrEqual(1);
    expect(secondHistoryCard.x).toBeGreaterThan(firstHistoryCard.x + firstHistoryCard.width);
  }

  const initialBox = await header.boundingBox();
  expect(initialBox.y).toBeLessThanOrEqual(4);
  await page.evaluate(() => {
    document.body.style.minHeight = "2200px";
    window.__headerCompactTransitions = 0;
    const observedHeader = document.querySelector(".club-page-header");
    const observer = new MutationObserver((mutations) => {
      window.__headerCompactTransitions += mutations.filter((mutation) => mutation.attributeName === "class").length;
    });
    observer.observe(observedHeader, { attributes: true, attributeFilter: ["class"] });
    window.__headerObserver = observer;
    window.scrollTo(0, 80);
  });
  await expect(header).toHaveClass(/club-page-header--compact/);
  await page.waitForTimeout(750);
  expect(await page.evaluate(() => window.__headerCompactTransitions)).toBe(1);
  await expect.poll(async () => (await header.boundingBox()).height).toBeLessThan(initialBox.height);
  const compactBox = await header.boundingBox();

  expect(Math.abs(compactBox.width - initialBox.width)).toBeLessThanOrEqual(1);
  expect(compactBox.height).toBeLessThan(initialBox.height);
  expect(compactBox.y).toBeGreaterThanOrEqual(0);
  expect(compactBox.y).toBeLessThanOrEqual(20);

  if (viewport.width > 840) {
    const primaryNavigation = header.getByRole("navigation", { name: "Primary navigation" });
    await expect(primaryNavigation.locator(".club-page-header__menu-label").first()).toBeHidden();
    await expect(primaryNavigation.locator(".club-page-header__menu-icon")).toHaveCount(6);
    await expect(primaryNavigation.locator(".club-page-header__menu-icon").first()).toBeVisible();
    const compactHomeBox = await primaryNavigation.getByRole("button", { name: "Home" }).boundingBox();
    expect(compactHomeBox.width).toBeLessThan(initialHomeBox.width);
    await page.evaluate(() => window.scrollTo(0, 0));
    await expect(header).not.toHaveClass(/club-page-header--compact/);
    await primaryNavigation.getByRole("button", { name: "Start New Match" }).click();
    await expect(page).toHaveURL(/\/match\/new$/);
    await expect(page.getByRole("button", { name: "Back to Dashboard" })).toHaveCount(0);
    await expect(page.getByText("Choose Racket Sport", { exact: true })).toHaveCount(0);
    await expect(page.getByText("Choose the racket sport first, then continue into the correct match setup flow.", { exact: true })).toHaveCount(0);
  }

  await page.evaluate(() => window.__headerObserver?.disconnect());
});
