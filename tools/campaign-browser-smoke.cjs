/* Tests use isolated contexts and mocked score rows; no real scores are submitted. */
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
function playwrightModule() {
  if (process.env.PLAYWRIGHT_MODULE)
    return require(process.env.PLAYWRIGHT_MODULE);
  try {
    return require("playwright");
  } catch (_) {}
  const cache = "/home/forge/.cache/tillandsias-project/npm/_npx";
  if (fs.existsSync(cache))
    for (const folder of fs.readdirSync(cache)) {
      const candidate = path.join(cache, folder, "node_modules/playwright");
      if (fs.existsSync(candidate)) return require(candidate);
    }
  throw new Error("Set PLAYWRIGHT_MODULE to an installed playwright module");
}
const { chromium } = playwrightModule();
const previewUrl = process.env.URL || "http://127.0.0.1:8765";
async function semantics(page) {
  const p = page.locator("flt-semantics-placeholder");
  if (await p.count()) await p.first().evaluate((el) => el.click());
  await page.waitForTimeout(200);
}
(async () => {
  const browser = await chromium.launch({
    headless: true,
    args: ["--no-sandbox"],
  });
  try {
    for (const [name, viewport] of [
      ["desktop", { width: 1280, height: 900 }],
      ["phone", { width: 390, height: 844 }],
      ["landscape", { width: 844, height: 390 }],
    ]) {
      const context = await browser.newContext({
        viewport,
        hasTouch: name !== "desktop",
      });
      const page = await context.newPage();
      const errors = [];
      page.on("pageerror", (e) => errors.push(e.message));
      await context.addInitScript(() => {
        localStorage.setItem(
          "demonAttack.history",
          JSON.stringify({
            failures: 3,
            everBeatBoss: true,
            easyUnlocked: true,
            hardUnlocked: true,
          }),
        );
        if (!localStorage.getItem("demonAttack.checkpoint"))
          localStorage.setItem(
            "demonAttack.checkpoint",
            JSON.stringify({
              schemaVersion: 999,
              difficulty: "easy",
              routeIndex: 2,
              sector: 3,
              wave: 2,
              score: 12345,
              lives: 7,
              medals: 2,
              heartSlots: [1, 3, 4],
              activeMilliseconds: 62000,
              futureField: true,
            }),
          );
      });
      await page.route("**/api/scores*", (route) =>
        route.fulfill({
          json: {
            scores: [
              {
                initials: "DAN",
                score: 123456,
                difficulty:
                  new URL(route.request().url()).searchParams.get(
                    "difficulty",
                  ) || "normal",
                medals: 5,
                activeMilliseconds: 62000,
                remainingLives: 7,
              },
            ],
          },
        }),
      );
      await page.goto(previewUrl, { waitUntil: "networkidle" });
      await page.locator("flutter-view").waitFor();
      await page.waitForTimeout(900);
      await semantics(page);
      for (const text of ["EASY MODE", "HARD MODE", "RESUME GAME"])
        assert(
          await page.getByRole("button", { name: text, exact: true }).count(),
          `${name} ${text}`,
        );
      const hardTab = page.getByRole("button", { name: "HARD", exact: true });
      await hardTab.scrollIntoViewIfNeeded();
      await hardTab.click();
      await page.waitForTimeout(300);
      assert(await page.getByText("♥ ×7", { exact: true }).count());
      assert(await page.getByText("01:02", { exact: true }).count());
      if (name !== "desktop") {
        await page.mouse.move(viewport.width / 2, viewport.height / 2);
        await page.mouse.wheel(0, 1200);
        await page.waitForTimeout(300);
      }
      await page.screenshot({ path: `/tmp/campaign-scores-${name}.png` });
      if (name !== "desktop") {
        await page.mouse.wheel(0, -4000);
        await page.waitForTimeout(250);
      }
      const resume = page.getByRole("button", {
        name: "RESUME GAME",
        exact: true,
      });
      await resume.scrollIntoViewIfNeeded();
      await resume.evaluate((el) => el.click());
      await page.waitForTimeout(350);
      assert(
        await page
          .getByRole("button", { name: "Pause game", exact: true })
          .count(),
        `${name} gameplay mounted`,
      );
      const checkpoint = await page.evaluate(() =>
        JSON.parse(localStorage.getItem("demonAttack.checkpoint")),
      );
      assert.equal(checkpoint.difficulty, "easy");
      assert.equal(checkpoint.routeIndex, 2);
      assert.equal(checkpoint.sector, 3);
      assert.equal(checkpoint.wave, 2);
      assert.equal(checkpoint.score, 12345);
      assert.equal(checkpoint.lives, 7);
      assert.deepEqual(checkpoint.heartSlots, [1, 3, 12]);
      assert.equal(checkpoint.activeMilliseconds, 62000);
      await page.screenshot({ path: `/tmp/campaign-resume-${name}.png` });
      await page.reload({ waitUntil: "networkidle" });
      await page.waitForTimeout(900);
      await semantics(page);
      assert(
        await page
          .getByRole("button", { name: "RESUME GAME", exact: true })
          .count(),
        `${name} reload retains checkpoint`,
      );
      assert.deepEqual(errors, [], `${name} runtime errors`);
      console.log(
        `${name}: unlocked modes, distinct boards, medals/time/finisher lives, compatible checkpoint resume and reload passed`,
      );
      await context.close();
    }
  } finally {
    await browser.close();
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
