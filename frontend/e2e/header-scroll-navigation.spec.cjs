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
  ...Array.from({ length: 23 }, (_, index) => ({
    id: 903 + index,
    sport: index % 2 === 0 ? "squash" : "tennis",
    player1_name: `Player${index + 3}`,
    player1_surname: "One",
    player2_name: `Opponent${index + 3}`,
    player2_surname: "Two",
    winner_side: index % 2 === 0 ? "player1" : "player2",
    player1_games_won: index % 2 === 0 ? 3 : 1,
    player2_games_won: index % 2 === 0 ? 1 : 3,
    updated_at: new Date(Date.UTC(2026, 8, 30 - index, 18, 0)).toISOString(),
    state: { game_history: [{ player1_score: 11, player2_score: 8 }] },
  })),
];

function envelope(data) {
  return { success: true, data };
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
    window.localStorage.setItem("hitnscore.analytics-consent", "denied");
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
  await page.route("**/organization_settings/42", async (route) => {
    await route.fulfill({ json: envelope({ organizationSettings: {
      organization: {
        id: 42,
        organization_name: "Header Test Club",
        org_address: "1 Court Road",
        org_contact: "Header Tester",
        type: "club",
        features: {},
      },
      users: [{
        id: 7,
        username: session.username,
        role: "admin",
        status: "approved",
        first_name: "Header",
        surname: "Tester",
        telephone: "01234 567890",
        city_location: "London",
        country: "United Kingdom",
      }, {
        id: 8,
        username: "zoe@example.com",
        role: "user",
        status: "approved",
        first_name: "Zoe",
        surname: "Alpha",
      }, {
        id: 9,
        username: "alex@example.com",
        role: "user",
        status: "approved",
        first_name: "Alex",
        surname: "Zephyr",
      }],
      courts: [],
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
  await expect(startMatch.locator("strong")).toHaveCSS("font-weight", "700");

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
    await expect(historyCards).toHaveCount(6);
    const firstHistoryCard = await historyCards.nth(0).boundingBox();
    const secondHistoryCard = await historyCards.nth(1).boundingBox();
    const fifthHistoryCard = await historyCards.nth(4).boundingBox();
    const sixthHistoryCard = await historyCards.nth(5).boundingBox();
    expect(Math.abs(firstHistoryCard.y - secondHistoryCard.y)).toBeLessThanOrEqual(1);
    expect(secondHistoryCard.x).toBeGreaterThan(firstHistoryCard.x + firstHistoryCard.width);
    expect(Math.abs(fifthHistoryCard.y - sixthHistoryCard.y)).toBeLessThanOrEqual(1);
    expect(sixthHistoryCard.x).toBeGreaterThan(fifthHistoryCard.x + fifthHistoryCard.width);
    await expect(page.getByRole("heading", { name: "Recent Matches" })).toBeVisible();
    await expect(historyCards.nth(0).locator(".dashboard-history-card__date-tile small")).toHaveText(/^\d{2}:\d{2}$/);
    await expect(historyCards.nth(0).locator(".dashboard-history-card__player-name--winner")).toHaveCSS("text-decoration-line", "none");
    await expect(page.getByRole("button", { name: "Completed matches page 4" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Completed matches page 5" })).toHaveCount(0);
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
    await expect(page).toHaveURL(/\/dashboard#new-match$/);
    await expect(primaryNavigation.getByRole("button", { name: "Start New Match" })).toHaveAttribute("aria-current", "page");
    await expect(primaryNavigation.getByRole("button", { name: "Matches" })).not.toHaveAttribute("aria-current", "page");
    await expect(page.getByRole("dialog", { name: "Choose Racket Sport" })).toBeVisible();
    await page.getByRole("button", { name: "Close" }).click();
    await expect(page).toHaveURL(/\/dashboard$/);
    await startMatch.click();
    await expect(page.getByRole("dialog", { name: "Choose Racket Sport" })).toBeVisible();
  } else {
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.getByRole("button", { name: "Open navigation menu" }).click();
    const quickNavigation = page.getByRole("dialog", { name: "Quick navigation" });
    const menuItems = quickNavigation.locator(".mobile-fab-menu-sheet__item");
    await expect(menuItems).toHaveCount(6);
    const menuBoxes = await menuItems.evaluateAll((items) => items.map((item) => item.getBoundingClientRect().top));
    expect(Math.max(...menuBoxes) - Math.min(...menuBoxes)).toBeLessThanOrEqual(1);
    await quickNavigation.getByRole("button", { name: "Settings", exact: true }).click();
    await expect(page).toHaveURL(/\/settings$/);
  }

  await page.evaluate(() => window.__headerObserver?.disconnect());
});

test("opens all recent matches from the heading on the Matches history tab @header", async ({ page }) => {
  await page.goto("/dashboard");
  await expect(page.getByRole("button", { name: "View all" })).toHaveCount(0);
  await page.getByRole("link", { name: "Recent Matches" }).click();
  await expect(page).toHaveURL(/\/matches#match-history-section$/);
  await expect(page.getByRole("tab", { name: "History", exact: true })).toHaveAttribute("aria-selected", "true");
  await expect(page.getByRole("heading", { name: "Match History" })).toBeVisible();
  const historyCards = page.locator(".dashboard-list--history.dashboard-list--desktop .dashboard-history-card");
  await expect(historyCards).toHaveCount(20);
  if (page.viewportSize().width >= 1100) {
    await expect(page.locator(".dashboard-carousel--mobile")).toBeHidden();
    await page.evaluate(() => document.fonts.ready);
    const [tenthRowLeft, tenthRowRight] = await historyCards.evaluateAll((cards) => (
      cards.slice(18, 20).map((card) => {
        const box = card.getBoundingClientRect();
        return { x: box.x, y: box.y, width: box.width };
      })
    ));
    expect(Math.abs(tenthRowLeft.y - tenthRowRight.y)).toBeLessThanOrEqual(1);
    expect(tenthRowRight.x).toBeGreaterThan(tenthRowLeft.x + tenthRowLeft.width);
  } else {
    await expect(page.locator(".dashboard-list--history.dashboard-list--desktop")).toBeHidden();
    await expect(page.locator(".dashboard-carousel--mobile")).toBeVisible();
  }
  await expect(page.getByRole("button", { name: "Completed matches page 2" })).toBeVisible();
  await page.getByRole("button", { name: "Completed matches page 2" }).click();
  await expect(historyCards).toHaveCount(5);
});

test("opens Current and Scheduled matches from their dashboard headings @header", async ({ page }) => {
  await page.goto("/dashboard");
  await page.getByRole("link", { name: "Active Matches" }).click();
  await expect(page).toHaveURL(/\/matches#active-matches-section$/);
  await expect(page.getByRole("tab", { name: "Current", exact: true })).toHaveAttribute("aria-selected", "true");

  await page.goto("/dashboard");
  await page.getByRole("link", { name: "Scheduled Matches" }).click();
  await expect(page).toHaveURL(/\/matches#scheduled-matches-section$/);
  await expect(page.getByRole("tab", { name: "Scheduled", exact: true })).toHaveAttribute("aria-selected", "true");
});

test("opens and updates the signed-in club admin profile from the header @header", async ({ page }) => {
  let submittedProfile = null;
  await page.route("**/personal_profile/42", async (route) => {
    submittedProfile = route.request().postDataJSON();
    await route.fulfill({ json: envelope({ organizationSettings: {
      organization: { id: 42, organization_name: "Header Test Club", type: "club", features: {} },
      users: [{
        id: 7,
        username: session.username,
        role: "admin",
        status: "approved",
        first_name: submittedProfile.first_name,
        surname: submittedProfile.surname,
        telephone: submittedProfile.telephone,
        city_location: submittedProfile.city_location,
        country: submittedProfile.country,
      }],
      courts: [],
    } }) });
  });

  await page.goto("/dashboard");
  const profileButton = page.getByRole("button", { name: `Profile: ${session.username}` });
  await expect(profileButton).toBeVisible();
  await expect(profileButton).toHaveAttribute("title", session.username);
  await profileButton.click();

  await expect(page).toHaveURL(/\/profile$/);
  await expect(page.getByRole("heading", { name: "Your Profile" })).toBeVisible();
  await expect(page.getByLabel("Email / Username")).toHaveValue(session.username);
  await expect(page.getByLabel("Email / Username")).toBeEditable();
  await expect(page.getByLabel("First name")).toHaveValue("Header");
  await page.getByLabel("Telephone").fill("020 7946 0100");
  await page.getByLabel("Country").selectOption("France");
  await page.getByRole("button", { name: "Save Profile" }).click();

  await expect(page.getByText("Your profile has been updated.")).toBeVisible();
  expect(submittedProfile.telephone).toBe("020 7946 0100");
  expect(submittedProfile.country).toBe("France");
});

test("returns to login with the new address after a profile email change @header", async ({ page }) => {
  const nextEmail = "updated-header@example.com";
  await page.route("**/personal_profile/42", async (route) => {
    const submittedProfile = route.request().postDataJSON();
    await route.fulfill({ json: envelope({ organizationSettings: {
      organization: { id: 42, organization_name: "Header Test Club", type: "club", features: {} },
      users: [{
        id: 7,
        username: submittedProfile.email,
        role: "admin",
        status: "approved",
        first_name: submittedProfile.first_name,
        surname: submittedProfile.surname,
        telephone: submittedProfile.telephone,
        city_location: submittedProfile.city_location,
        country: submittedProfile.country,
      }],
      courts: [],
    } }) });
  });
  await page.route("**/logout", async (route) => {
    await route.fulfill({ json: envelope({}) });
  });

  await page.goto("/profile");
  await page.getByLabel("Email / Username").fill(nextEmail);
  await page.getByRole("button", { name: "Save Profile" }).click();

  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByText(`Email updated. Sign in again using ${nextEmail}.`)).toBeVisible();
});

test("opens the shared sport chooser from the responsive new-match menu action @header", async ({ page }) => {
  await page.goto("/dashboard");

  if (page.viewportSize().width > 840) {
    await page.getByRole("navigation", { name: "Primary navigation" })
      .getByRole("button", { name: "Start New Match" })
      .click();
  } else {
    await page.getByRole("button", { name: "Open navigation menu" }).click();
    await page.getByRole("dialog", { name: "Quick navigation" })
      .getByRole("button", { name: "Start New Match" })
      .click();
  }

  await expect(page).toHaveURL(/\/dashboard#new-match$/);
  await expect(page.getByRole("dialog", { name: "Choose Racket Sport" })).toBeVisible();
});

test("does not repeat the Home button in organisation settings tabs @header", async ({ page }) => {
  await page.goto("/settings");
  await expect(page.locator(".root-admin-tab-row")).toBeVisible();
  await expect(page.locator(".root-admin-tab-row").getByRole("button", { name: "Back to dashboard" })).toHaveCount(0);
  await expect(page.locator(".root-admin-tab-row").getByRole("button", { name: "Organisation", exact: true })).toBeVisible();
});

test("uses a club-member primary contact and searchable surname-sorted users @header", async ({ page }) => {
  let submittedOrganization = null;
  await page.route("**/organization_details/42", async (route) => {
    submittedOrganization = route.request().postDataJSON();
    await route.fulfill({ json: envelope({}) });
  });

  await page.goto("/settings");
  const clubName = page.getByLabel("Club Name");
  const address = page.getByLabel("Address");
  const primaryContact = page.getByLabel("Primary Contact");
  const [clubBox, addressBox, contactBox] = await Promise.all([
    clubName.boundingBox(),
    address.boundingBox(),
    primaryContact.boundingBox(),
  ]);
  expect(addressBox.y).toBeGreaterThan(clubBox.y);
  expect(contactBox.y).toBeGreaterThan(addressBox.y);

  await primaryContact.fill("Nobody Missing");
  await expect(page.getByText("The primary contact must first be added", { exact: false })).toBeVisible();
  await primaryContact.fill("Alex Zeph");
  await page.getByRole("option", { name: /Alex Zephyr/ }).click();
  await page.getByRole("button", { name: "Save Organisation Details" }).click();
  await expect(page.getByText("Organisation details updated.")).toBeVisible();
  expect(submittedOrganization.org_contact).toBe("Alex Zephyr");

  await page.getByRole("button", { name: "Users", exact: true }).click();
  const addUserToggle = page.getByRole("button", { name: "Add User", exact: true }).first();
  await expect(addUserToggle).toHaveAttribute("aria-expanded", "false");
  await expect(page.getByLabel("First Name")).toHaveCount(0);
  await addUserToggle.click();
  await expect(page.getByLabel("First Name")).toBeVisible();

  const userCards = page.locator(".dashboard-list .dashboard-item");
  await expect(userCards).toHaveCount(3);
  await expect(userCards.nth(0)).toContainText("Zoe Alpha");
  await expect(userCards.nth(1)).toContainText("Header Tester");
  await expect(userCards.nth(2)).toContainText("Alex Zephyr");
  await page.getByLabel("Search Users").fill("Zephyr");
  await expect(userCards).toHaveCount(1);
  await expect(userCards.first()).toContainText("Alex Zephyr");
});
