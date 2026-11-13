const { test, expect } = require("@playwright/test");

function envelope(data) {
  return { success: true, data };
}

const session = {
  username: "club-admin@example.com",
  email: "club-admin@example.com",
  first_name: "Club",
  surname: "Admin",
  organization_id: 50008,
  organization_name: "Club Admin Personal",
  organization_type: "personal",
  plan: "personal_free",
  role: "admin",
  session_token: "playwright-club-admin-session",
  available_memberships: [
    {
      id: 18,
      username: "club-admin@example.com",
      organization_id: 50008,
      organization_name: "Club Admin Personal",
      organization_type: "personal",
      plan: "personal_free",
      role: "admin",
    },
    {
      id: 8,
      username: "club-admin@example.com",
      organization_id: 42,
      organization_name: "Alpha Club",
      organization_type: "club",
      plan: "club_essentials",
      role: "admin",
    },
    {
      id: 9,
      username: "club-admin@example.com",
      organization_id: 43,
      organization_name: "Beta Club",
      organization_type: "club",
      plan: "club_pro",
      role: "admin",
    },
  ],
};

function clubSettings(id, name, plan = "club_essentials") {
  return {
    organization: {
      id,
      organization_name: name,
      org_type: "club",
      plan,
      enabled_sports: ["squash"],
      timed_break_defaults: { squash: false, racketball: false, tennis: false, padel: false },
      association_competitions: [],
      features: {},
    },
    users: [{
      id: 8,
      username: session.username,
      first_name: "Club",
      surname: "Admin",
      role: "admin",
      status: "approved",
    }],
    courts: [],
    competition_catalog: [
      { name: "County League", type: "league" },
      { name: "Regional Inter-club", type: "interclub" },
    ],
  };
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
    window.localStorage.setItem("hitnscore.analytics-consent", "denied");
  }, session);

  await page.route("**/session/status", (route) => route.fulfill({
    json: envelope({ session: { ...session, csrf_token: "playwright-club-admin-csrf" } }),
  }));
  await page.route("**/notifications/**", (route) => route.fulfill({ json: envelope({ notifications: [] }) }));
  await page.route("**/organization_settings/50008", (route) => route.fulfill({
    json: envelope({ organizationSettings: {
      organization: { id: 50008, organization_name: "Club Admin Personal", org_type: "personal", plan: "personal_free" },
      users: [{ username: session.username, first_name: "Club", surname: "Admin", role: "admin", status: "approved" }],
      courts: [],
    } }),
  }));
});

test("club admins choose a managed club and assign league fixtures @club-settings", async ({ page }) => {
  const settingsByClub = {
    42: clubSettings(42, "Alpha Club"),
    43: clubSettings(43, "Beta Club", "club_pro"),
  };
  const updates = [];

  await page.route(/\/organization_settings\/(42|43)$/, (route) => {
    const id = Number(route.request().url().split("/").at(-1));
    return route.fulfill({ json: envelope({ organizationSettings: settingsByClub[id] }) });
  });
  await page.route("**/organization_details/42", async (route) => {
    const update = route.request().postDataJSON();
    updates.push(update);
    settingsByClub[42].organization.association_competitions = update.association_competitions;
    await route.fulfill({ json: envelope({ organizationSettings: settingsByClub[42] }) });
  });

  await page.goto("/settings");
  const menu = page.getByRole("region", { name: "Settings sections" });
  await expect(menu).toBeVisible();
  await expect(menu.getByRole("button")).toHaveCount(5);
  const menuLabels = await menu.getByRole("button").allTextContents();
  expect(menuLabels).toEqual(["Profile", "Association", "Club Management", "Subscription", "App Settings"]);

  await menu.getByRole("button", { name: "Club Management" }).click();
  await expect(page).toHaveURL(/section=club-management/);
  await expect(page.getByRole("heading", { name: "Club Management" })).toBeVisible();
  await expect(page.locator(".settings-association-card")).toHaveCount(2);

  await page.locator(".settings-association-card", { hasText: "Alpha Club" })
    .getByRole("button", { name: "Open Club Management" }).click();
  await expect(page).toHaveURL(/club=1.*organizationId=42.*tab=organisation/);

  await page.getByRole("button", { name: /Leagues/ }).click();
  await expect(page).toHaveURL(/tab=leagues/);
  await expect(page.locator(".settings-league-group__toggle .settings-expand-icon")).toHaveCount(2);
  await page.getByRole("button", { name: /Inter-club leagues/ }).click();
  await expect(page.getByRole("button", { name: "Add Inter-club leagues" })).toBeVisible();
  await page.getByRole("button", { name: /Club leagues/ }).click();
  await page.getByRole("button", { name: "Add Club leagues" }).click();
  await page.getByLabel("League name").fill("County League");
  await page.getByRole("button", { name: "Save League" }).click();
  await expect(page.getByRole("button", { name: "Hide County League" })).toBeVisible();

  await expect(page.getByRole("button", { name: "Hide divisions for County League" })).toBeVisible();
  await page.getByLabel("Division name").fill("Division 1");
  await page.getByRole("button", { name: "Add Division" }).click();

  await page.getByLabel("Game date").fill("2027-02-12");
  await page.getByLabel("Opposition").fill("North Club");
  await page.getByRole("button", { name: "Add Game" }).click();
  await expect(page.getByText("12 Feb 2027")).toBeVisible();
  await expect(page.getByText("North Club")).toBeVisible();
  expect(updates.at(-1).association_competitions).toEqual([
    {
      name: "County League",
      type: "league",
      divisions: [{
        name: "Division 1",
        fixtures: [{ date: "2027-02-12", opposition: "North Club" }],
      }],
    },
  ]);

  await page.getByRole("button", { name: "Delete County League" }).click();
  const deleteDialog = page.getByRole("dialog", { name: "Delete County League?" });
  await expect(deleteDialog).toBeVisible();
  await expect(deleteDialog.getByRole("button", { name: "Delete League" })).toBeDisabled();
  await deleteDialog.getByLabel("Type DELETE to confirm").fill("DELETE");
  await deleteDialog.getByRole("button", { name: "Delete League" }).click();
  await expect(deleteDialog).toHaveCount(0);
  await expect(page.getByText("County League", { exact: true })).toHaveCount(0);
  expect(updates.at(-1).association_competitions).toEqual([]);
});

test("Club Management opens the only administered club directly @club-settings", async ({ page }) => {
  const singleClubSession = {
    ...session,
    available_memberships: session.available_memberships.filter((membership) => membership.organization_id !== 43),
  };
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
  }, singleClubSession);
  await page.unroute("**/session/status");
  await page.route("**/session/status", (route) => route.fulfill({
    json: envelope({ session: { ...singleClubSession, csrf_token: "playwright-club-admin-csrf" } }),
  }));
  await page.route("**/organization_settings/42", (route) => route.fulfill({
    json: envelope({ organizationSettings: clubSettings(42, "Alpha Club") }),
  }));

  await page.goto("/settings");
  const menu = page.getByRole("region", { name: "Settings sections" });
  await menu.getByRole("button", { name: "Club Management" }).click();
  await expect(page).toHaveURL(/club=1.*organizationId=42.*tab=organisation/);
  await expect(page.getByRole("heading", { name: "Organisation Details" })).toBeVisible();
});

test("disabled subscriptions stay visible but cannot be opened @club-settings", async ({ page }) => {
  const disabledSession = {
    ...session,
    subscription_access_enabled: false,
    available_memberships: session.available_memberships.map((membership) => ({
      ...membership,
      subscription_access_enabled: false,
    })),
  };
  await page.unroute("**/session/status");
  await page.route("**/session/status", (route) => route.fulfill({
    json: envelope({ session: { ...disabledSession, csrf_token: "playwright-club-admin-csrf" } }),
  }));

  await page.goto("/settings?section=subscription");
  const subscription = page.getByRole("button", { name: "Subscription" });
  await expect(subscription).toBeVisible();
  await expect(subscription).toBeDisabled();
  await expect(page).toHaveURL(/section=subscription/);
  await expect(page.getByRole("heading", { name: "Profile", exact: true })).toBeVisible();
});

