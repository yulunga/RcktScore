const { test, expect } = require("@playwright/test");

const session = {
  username: "club-user@example.com",
  email: "club-user@example.com",
  first_name: "Club",
  surname: "User",
  organization_id: 42,
  organization_name: "Android Test Club",
  organization_type: "club",
  plan: "club_essentials",
  role: "user",
  enabled_sports: ["squash"],
  session_token: "playwright-club-user-session",
};

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
      organization: { id: 42, name: "Android Test Club", type: "club", plan: "club_essentials" },
      active_matches: [],
      scheduled_matches: [],
      recent_matches: [],
    } }) });
  });
  await page.route("**/organization_settings/42", async (route) => {
    await route.fulfill({ json: envelope({ organizationSettings: {
      organization: {
        id: 42,
        organization_name: "Android Test Club",
        org_type: "club",
        plan: "club_essentials",
        enabled_sports: ["squash"],
        timed_break_defaults: { squash: false, racketball: false, tennis: false, padel: false },
        features: {},
      },
      users: [{
        id: 8,
        username: session.username,
        email: session.email,
        first_name: "Club",
        surname: "User",
        role: "user",
        status: "approved",
      }],
      courts: [],
    } }) });
  });
});

test("non-admin club user opens Settings from the Android menu @mobile-settings", async ({ page }) => {
  await page.goto("/dashboard");
  await page.getByRole("button", { name: "Open navigation menu" }).click();
  await page.getByRole("dialog", { name: "Quick navigation" })
    .getByRole("button", { name: "Settings", exact: true })
    .click();

  await expect(page).toHaveURL(/\/settings$/);
  await expect(page.getByRole("heading", { name: "Profile", exact: true })).toBeVisible();
  await expect(page.getByLabel("First Name")).toHaveAttribute("readonly", "");
  await page.getByRole("button", { name: "Association", exact: true }).click();
  await expect(page.getByText("You are in view-only mode. Only organisation admins can manage club settings.")).toBeVisible();
  await expect(page.getByRole("button", { name: /Club Profile/ })).toBeVisible();
  await expect(page.getByRole("button", { name: /Courts/ })).toHaveCount(0);

  await page.getByRole("button", { name: /Club Profile/ }).click();
  await expect(page).toHaveURL(/club=1.*organizationId=42.*tab=organisation/);
  await expect(page.getByRole("button", { name: /Settings Home/ })).toBeVisible();
  await expect(page.getByRole("button", { name: /Courts/ })).toHaveCount(0);

  await page.goto("/settings?club=1&organizationId=42&tab=courts");
  await expect(page).toHaveURL(/tab=organisation/);
  await expect(page.getByRole("button", { name: /Courts/ })).toHaveCount(0);
});
