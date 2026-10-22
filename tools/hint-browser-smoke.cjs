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
  throw new Error('Playwright is required');
}
(async () => {
  const browser = await playwrightModule().chromium.launch({headless:true,args:['--no-sandbox']});
  try {
    for (const [name,viewport] of [['phone',{width:390,height:844}],['landscape',{width:844,height:390}]]) {
      const context = await browser.newContext({viewport});
      await context.addInitScript(() => localStorage.setItem('demonAttack.history', JSON.stringify({autoAdvanceHints:false})));
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror',e=>errors.push(e.message));
      await page.goto(process.env.URL || 'http://127.0.0.1:8765',{waitUntil:'networkidle'});
      await page.waitForTimeout(900);
      const placeholder=page.locator('flt-semantics-placeholder');
      if(await placeholder.count()) await placeholder.first().evaluate(el=>el.click());
      await page.waitForTimeout(200);
      await page.getByRole('button',{name:'START GAME  →',exact:true}).click();
      await page.waitForTimeout(500);
      await page.getByRole('button',{name:'CONTINUE',exact:true}).waitFor();
      await page.waitForTimeout(5000);
      assert.equal(await page.getByRole('button',{name:'CONTINUE',exact:true}).count(),1,'manual hint must not advance');
      await page.screenshot({path:`/tmp/demon-hint-${name}.png`});
      await page.getByRole('button',{name:'FIELD GUIDE',exact:true}).click();
      await page.waitForTimeout(350);
      await page.screenshot({path:`/tmp/demon-guide-${name}.png`});
      assert(await page.getByRole('switch',{name:/Auto-advance hints/}).count(),'guide timing preference is present');
      await page.screenshot({path:`/tmp/demon-guide-${name}.png`});
      await page.getByRole('button',{name:'Close field guide',exact:true}).click();
      await page.getByRole('button',{name:'CONTINUE',exact:true}).click();
      await page.waitForTimeout(300);
      assert.equal(await page.getByRole('button',{name:'CONTINUE',exact:true}).count(),0);
      assert.equal((await page.request.get(new URL('/assets/assets/images/hint-scenes.png',page.url()).href)).status(),200);
      assert.deepEqual(errors,[]);
      console.log(`${name}: illustrated held hint, untimed guide and explicit continuation passed`);
      await context.close();
    }
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
