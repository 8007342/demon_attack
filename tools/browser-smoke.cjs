/* Run after flutter build web and serving build/web. No npm install required. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

function playwrightModule() {
  if (process.env.PLAYWRIGHT_MODULE) return require(process.env.PLAYWRIGHT_MODULE);
  try { return require('playwright'); } catch (_) {}
  const cache = '/home/forge/.cache/tillandsias-project/npm/_npx';
  for (const folder of fs.readdirSync(cache)) {
    const candidate = path.join(cache, folder, 'node_modules/playwright');
    if (fs.existsSync(candidate)) return require(candidate);
  }
  throw new Error('Set PLAYWRIGHT_MODULE to an installed playwright module');
}

async function semantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) {
    await placeholder.first().evaluate(el => el.click());
  }
  await page.waitForTimeout(250);
}

async function textVisible(page, value) {
  return page.getByText(value, {exact: false}).first().isVisible().catch(() => false);
}

(async () => {
  const {chromium} = playwrightModule();
  const browser = await chromium.launch({headless: true, args: ['--no-sandbox']});
  const errors = [];
  try {
    for (const [name, viewport] of [
      ['desktop', {width: 1280, height: 900}],
      ['phone', {width: 390, height: 844}],
    ]) {
      const context = await browser.newContext({viewport, hasTouch: name === 'phone'});
      const page = await context.newPage();
      const midi = [];
      const scoreLoads = [];
      page.on('response', response => {
        if (new URL(response.url()).pathname === '/api/scores' && response.request().method() === 'GET') scoreLoads.push(response);
      });
      page.on('response', response => { if (response.url().endsWith('.mid')) midi.push({url: response.url(), status: response.status()}); });
      page.on('pageerror', error => errors.push(`${name}: ${error.message}`));
      page.on('console', message => {
        if (message.type() === 'error') errors.push(`${name}: ${message.text()}`);
      });
      await page.goto(process.env.URL || 'http://127.0.0.1:8765', {waitUntil: 'networkidle'});
      await page.locator('flt-glass-pane, flutter-view').first().waitFor({state: 'attached'});
      await page.waitForTimeout(1800);
      await semantics(page);
      assert(scoreLoads.length > 0, `${name}: landing should automatically request global scores`);
      assert.equal(scoreLoads.at(-1).status(), 200, `${name}: landing score GET must succeed`);
      const board = await scoreLoads.at(-1).json();
      assert(Array.isArray(board.scores) && board.scores.length <= 10, `${name}: bounded Top10 response`);
      assert.equal(await page.getByRole('button', {name: 'TOP 10 SCORES', exact: true}).count(), 0, `${name}: no separate leaderboard navigation`);
      assert(await textVisible(page, 'START GAME'), `${name}: inline scores preserve immediate Start`);
      const foundInitials = new Set();
      let boardHeading = await textVisible(page, 'TOP 10');
      for (let step = 0; step < (name === 'phone' ? 5 : 1); step++) {
        for (const entry of board.scores) if (await page.getByText(entry.initials, {exact: true}).count()) foundInitials.add(entry.initials);
        boardHeading ||= await textVisible(page, 'TOP 10');
        if (name === 'phone') { await page.mouse.move(viewport.width / 2, viewport.height / 2); await page.mouse.wheel(0, 330); await page.waitForTimeout(150); }
      }
      assert(boardHeading, `${name}: Top10 belongs directly on landing`);
      for (const entry of board.scores) assert(foundInitials.has(entry.initials), `${name}: landing scroll includes score initials ${entry.initials}`);
      await page.screenshot({path: `/tmp/demon-board-${name}.png`});
      if (name === 'phone') { await page.mouse.wheel(0, -4000); await page.waitForTimeout(200); }
      await page.mouse.click(12, viewport.height - 12);
      await page.screenshot({path: `/tmp/demon-title-${name}.png`});
      if (name === 'desktop') await page.screenshot({path: '/tmp/demon-title.png'});
      await page.keyboard.press('Enter');
      await page.waitForTimeout(500);
      await semantics(page);
      assert(!(await textVisible(page, 'START GAME')), `${name}: Enter should start the game`);
      assert(await page.getByRole('button', {name: 'Pause game', exact: true}).count(), `${name}: gameplay HUD should be mounted`);
      await page.locator('flt-semantics-host').evaluate(el => { el.style.pointerEvents = 'none'; for (const child of el.querySelectorAll('*')) child.style.pointerEvents = 'none'; });
      // Pointer down gives Flutter's Focus node keyboard ownership after semantics activation.
      await page.mouse.click(viewport.width / 2, viewport.height - 65);
      await page.waitForTimeout(2400);
      // A brief movement check exercises key-down and key-up independently.
      await page.keyboard.down('ArrowRight');
      await page.waitForTimeout(240);
      await page.keyboard.up('ArrowRight');
      await page.keyboard.down('ArrowLeft');
      await page.waitForTimeout(180);
      await page.keyboard.up('ArrowLeft');
      await page.keyboard.press('p');
      await page.waitForTimeout(150);
      await semantics(page);
      await page.screenshot({path: `/tmp/demon-pause-${name}.png`});
      assert(await textVisible(page, 'SIGNAL PAUSED'), `${name}: P should pause the game`);
      await page.keyboard.press('p');
      await page.waitForTimeout(150);
      assert(!(await textVisible(page, 'SIGNAL PAUSED')), `${name}: P should resume the game`);
      const controller = page.getByLabel('Ship controller. Drag left or right to move. Automatic firing.', {exact: true});
      let bounds = await controller.count() ? await controller.first().boundingBox().catch(() => null) : null;
      bounds ||= {x: viewport.width / 2 - Math.min(240, viewport.width / 2 - 15),
        y: viewport.height - 118, width: Math.min(480, viewport.width - 30), height: 108};
      const x = bounds.x + bounds.width * .3, y = bounds.y + bounds.height * .5;
      if (name === 'phone') {
        const session = await context.newCDPSession(page);
        await session.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [{x, y}]});
        for (let i = 1; i <= 6; i++) {
          await session.send('Input.dispatchTouchEvent', {type: 'touchMove', touchPoints: [{x: x + bounds.width * .4 * i / 6, y}]});
        }
        await session.send('Input.dispatchTouchEvent', {type: 'touchEnd', touchPoints: []});
      } else {
        await page.mouse.move(x, y);
        await page.mouse.down();
        await page.mouse.move(x + bounds.width * .4, y, {steps: 8});
        await page.mouse.up();
      }
      await page.screenshot({path: `/tmp/demon-play-${name}.png`});
      if (name === 'desktop') await page.screenshot({path: '/tmp/demon-play.png'});
      assert(midi.length > 0, `${name}: MIDI soundtrack should be requested`);
      assert(midi.every(response => response.status === 200), `${name}: MIDI responses should succeed: ${JSON.stringify(midi)}`);
      assert(await page.evaluate(() => typeof window.demonAudio?.unlock === 'function'), `${name}: synthesizer should be loaded`);
      console.log(`${name}: inline Top10 GET, title, Enter start, arrows, P pause/resume, controller drag passed; ${midi.length} MIDI responses succeeded`);
      await context.close();
    }
    assert.deepEqual(errors, [], 'Browser runtime/console errors');
    console.log('No browser runtime exceptions or console errors. Screenshots: /tmp/demon-{title,play}-{desktop,phone}.png');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
