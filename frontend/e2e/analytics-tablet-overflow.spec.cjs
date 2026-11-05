const path = require("path");
const { expect, test } = require("@playwright/test");

if (process.env.E2E_SYSTEM_CHROME === "1") {
  test.use({ channel: "chrome", video: "off" });
}

test("analytics heatmap scrolls internally without widening tablet portrait page", async ({ page }) => {
  await page.setViewportSize({ width: 744, height: 1133 });
  const cells = Array.from({ length: 24 }, () => "<span></span>").join("");
  const rows = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    .map((day) => `<div class="analytics-heatmap__row"><strong>${day}</strong><div class="analytics-heatmap__cells">${cells}</div></div>`)
    .join("");

  await page.setContent(`
    <main class="page-shell stack">
      <div class="matches-category-switch analytics-category-switch">
        <button>App</button><button>Player</button><button class="active">Club</button>
      </div>
      <section class="panel stack analytics-club-panel">
        <div class="performance-stat-grid">
          <article class="performance-stat-card"><span>Club matches scored</span><strong>48</strong></article>
          <article class="performance-stat-card"><span>Active club members</span><strong>Not tracked</strong></article>
        </div>
        <section class="analytics-subpanel stack">
          <div class="panel-heading"><h2>Club Usage Heatmap</h2></div>
          <div class="analytics-heatmap">${rows}</div>
        </section>
      </section>
    </main>
  `);
  await page.addStyleTag({ path: path.join(__dirname, "../src/styles.css") });

  const widths = await page.evaluate(() => {
    const heatmap = document.querySelector(".analytics-heatmap");
    return {
      viewport: window.innerWidth,
      document: document.documentElement.scrollWidth,
      heatmapClient: heatmap.clientWidth,
      heatmapScroll: heatmap.scrollWidth,
    };
  });

  expect(widths.document).toBe(widths.viewport);
  expect(widths.heatmapScroll).toBeGreaterThan(widths.heatmapClient);
});
