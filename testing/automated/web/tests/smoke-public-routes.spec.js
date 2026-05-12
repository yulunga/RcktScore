const { test, expect } = require("@playwright/test");

test("login page loads @smoke", async ({ page }) => {
  await page.goto("/login");

  await expect(page.getByLabel("Username")).toBeVisible();
  await expect(page.getByLabel("Password")).toBeVisible();
  await expect(page.getByRole("button", { name: "Sign In" })).toBeVisible();
});

test("dashboard redirects anonymous users back to login @smoke", async ({ page }) => {
  await page.goto("/dashboard");

  await expect(page.getByLabel("Username")).toBeVisible();
  await expect(page.getByRole("button", { name: "Sign In" })).toBeVisible();
});

test("help page opens password reset section @smoke", async ({ page }) => {
  await page.goto("/help");

  await expect(page.getByRole("heading", { name: "Password Reset" })).toBeVisible();
  await expect(page.getByLabel("Account email")).toBeVisible();
});

test("display page loads the scoreboard entry experience @smoke", async ({ page }) => {
  await page.goto("/display");

  await expect(page.getByRole("heading", { name: "Open A Court Scoreboard" })).toBeVisible();
  await expect(page.getByLabel("Display Code")).toBeVisible();
  await expect(page.getByRole("button", { name: "Open Scoreboard" })).toBeVisible();
  await expect(page.getByText("Enter a court display code to open the live scoreboard.")).toBeVisible();
});
