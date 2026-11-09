const { test, expect } = require("@playwright/test");

if (process.env.E2E_SYSTEM_CHROME === "1") {
  test.use({ channel: "chrome", video: "off" });
}

const session = {
  username: "refresh@example.com",
  organization_id: 42,
  organization_name: "Refresh Test Club",
  organization_type: "club",
  plan: "club_essentials",
  role: "admin",
  enabled_sports: ["squash"],
  available_memberships: [{
    username: "refresh@example.com",
    organization_id: 42,
    organization_name: "Refresh Test Club",
    organization_type: "club",
    plan: "club_essentials",
    role: "admin",
    enabled_sports: ["squash"],
  }],
};

function envelope(data) {
  return { success: true, data };
}

test("keeps the requested page visible while restoring a browser session @auth-refresh", async ({ page }) => {
  await page.addInitScript((storedSession) => {
    window.sessionStorage.setItem("rcktscore.auth", JSON.stringify({ session: storedSession, pendingSelection: null }));
    window.localStorage.setItem("hitnscore.analytics-consent", "denied");
  }, session);

  await page.route("**/session/status", async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 500));
    await route.fulfill({
      json: envelope({ session: { ...session, csrf_token: "refresh-test-csrf" } }),
    });
  });
  await page.route("**/notifications/42*", async (route) => {
    await route.fulfill({ json: envelope({ notifications: [] }) });
  });
  await page.route("**/dashboard/42*", async (route) => {
    await route.fulfill({
      json: envelope({
        dashboard: {
          organization: { id: 42, name: "Refresh Test Club", type: "club", plan: "club_essentials" },
          active_matches: [],
          scheduled_matches: [],
          recent_matches: [],
        },
      }),
    });
  });

  await page.goto("/dashboard");

  await expect(page).toHaveURL(/\/dashboard$/);
  await expect(page.getByText("Restoring your session…")).toBeVisible();
  await expect(page.getByRole("button", { name: "Sign In" })).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Active Matches" })).toBeVisible();
  await expect(page).toHaveURL(/\/dashboard$/);
});
