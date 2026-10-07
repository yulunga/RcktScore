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
      recent_matches: [],
    } }) });
  });
});

test("keeps the signed-in header width fixed while compacting its menu on scroll @header", async ({ page }) => {
  await page.goto("/dashboard");

  const header = page.locator(".club-page-header");
  const startMatch = page.getByRole("button", { name: "Start New Match" });
  await expect(header).toBeVisible();
  await expect(page.getByText("Manage live scoring, keep an eye on active courts, and review recent matches.")).toHaveCount(0);
  await expect(startMatch).toBeVisible();
  await expect(startMatch).toHaveCSS("color", "rgb(255, 255, 255)");

  const viewport = page.viewportSize();
  if (viewport.width > 840) {
    await expect(header.getByRole("button", { name: "Matches" })).toBeVisible();
    await expect(header.getByRole("button", { name: "Analytics" })).toBeVisible();
    await expect(header.getByRole("button", { name: "Settings" })).toBeVisible();
  }

  const initialBox = await header.boundingBox();
  await page.evaluate(() => {
    document.body.style.minHeight = "2200px";
    window.scrollTo(0, 300);
  });
  await expect(header).toHaveClass(/club-page-header--compact/);
  await expect.poll(async () => (await header.boundingBox()).height).toBeLessThan(initialBox.height);
  const compactBox = await header.boundingBox();

  expect(Math.abs(compactBox.width - initialBox.width)).toBeLessThanOrEqual(1);
  expect(compactBox.height).toBeLessThan(initialBox.height);
  expect(compactBox.y).toBeGreaterThanOrEqual(0);
  expect(compactBox.y).toBeLessThanOrEqual(20);

  if (viewport.width > 840) {
    await expect(header.locator(".club-page-header__menu-label").first()).toBeHidden();
    await expect(header.locator(".club-page-header__menu-icon").first()).toBeVisible();
  }
});
