// pwa-install: the install bridge, the service worker and the manifest.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import vm from 'node:vm';

const web = (path) => new URL(`../web/${path}`, import.meta.url);

/** Runs web/install_bridge.js against a fake window. */
async function loadBridge({ standalone = false, iosStandalone = false } = {}) {
  const listeners = {};
  const registered = [];
  const window = {
    addEventListener: (type, fn) => { (listeners[type] ??= []).push(fn); },
    matchMedia: (query) => ({ matches: standalone && query.includes('standalone'), addEventListener() {} }),
    navigator: {
      standalone: iosStandalone,
      serviceWorker: { register: (url, options) => { registered.push([url, options]); return Promise.resolve(); } },
    },
    isSecureContext: true,
    document: { readyState: 'loading' },
  };
  const fire = (type, event = {}) => { for (const fn of listeners[type] ?? []) fn(event); };
  vm.runInNewContext(await readFile(web('install_bridge.js'), 'utf8'), { window, globalThis: window, Promise });
  return { bridge: window.demonInstall, fire, registered };
}

function installEvent(outcome) {
  const event = { prevented: false, prompts: 0 };
  event.preventDefault = () => { event.prevented = true; };
  event.prompt = async () => { event.prompts++; return { outcome }; };
  return event;
}

test('nothing is offered until the browser fires beforeinstallprompt (Safari, Firefox: never)', async () => {
  const { bridge } = await loadBridge();
  assert.deepEqual({ ...bridge.status() }, { available: false, installed: false });
  assert.equal(await bridge.prompt(), 'unavailable');
});

test('beforeinstallprompt is deferred and one prompt() opens the browser approval', async () => {
  const { bridge, fire } = await loadBridge();
  let changes = 0;
  bridge.subscribe(() => changes++);
  const event = installEvent('accepted');
  fire('beforeinstallprompt', event);
  assert.ok(event.prevented, 'the browser mini-infobar is held back');
  assert.equal(bridge.status().available, true);
  assert.equal(await bridge.prompt(), 'accepted');
  assert.equal(event.prompts, 1);
  assert.deepEqual({ ...bridge.status() }, { available: false, installed: true });
  assert.ok(changes >= 2);
  assert.equal(await bridge.prompt(), 'unavailable', 'an event prompts once');
});

test('declining the dialog reports dismissed and leaves nothing to offer', async () => {
  const { bridge, fire } = await loadBridge();
  fire('beforeinstallprompt', installEvent('dismissed'));
  assert.equal(await bridge.prompt(), 'dismissed');
  assert.deepEqual({ ...bridge.status() }, { available: false, installed: false });
});

test('appinstalled and standalone display hide the offer', async () => {
  const { bridge, fire } = await loadBridge();
  fire('beforeinstallprompt', installEvent('accepted'));
  fire('appinstalled');
  assert.deepEqual({ ...bridge.status() }, { available: false, installed: true });
  for (const options of [{ standalone: true }, { iosStandalone: true }]) {
    const { bridge: running, fire: fireRunning } = await loadBridge(options);
    fireRunning('beforeinstallprompt', installEvent('accepted'));
    assert.deepEqual({ ...running.status() }, { available: false, installed: true });
  }
});

test('the bridge registers /sw.js at the root scope after load', async () => {
  const { fire, registered } = await loadBridge();
  assert.equal(registered.length, 0);
  fire('load');
  assert.deepEqual(registered.map(([url, options]) => [url, options.scope]), [['/sw.js', '/']]);
});

/** Runs web/sw.js with a fake worker global. */
async function loadWorker(fetchImpl) {
  const listeners = {};
  const self = {
    addEventListener: (type, fn) => { listeners[type] = fn; },
    skipWaiting() {},
    clients: { claim: async () => {} },
  };
  vm.runInNewContext(await readFile(web('sw.js'), 'utf8'), { self, fetch: fetchImpl, Response, Promise });
  return listeners;
}

test('the service worker has a real fetch handler: navigations network-first, offline notice', async () => {
  let online = true;
  const listeners = await loadWorker(async () => { if (!online) throw new TypeError('offline'); return new Response('live'); });
  assert.equal(typeof listeners.fetch, 'function');
  const respond = (request) => { let answer; listeners.fetch({ request, respondWith: (r) => { answer = r; } }); return answer; };
  assert.equal(await (await respond({ method: 'GET', mode: 'navigate' })).text(), 'live');
  online = false;
  const offline = await respond({ method: 'GET', mode: 'navigate' });
  assert.equal(offline.status, 503);
  assert.match(await offline.text(), /RECONNECT TO PLAY/);
  assert.equal(respond({ method: 'GET', mode: 'cors' }), undefined, 'assets and /api go to the browser');
  assert.equal(respond({ method: 'POST', mode: 'navigate' }), undefined);
});

test('the manifest meets the installability criteria', async () => {
  const manifest = JSON.parse(await readFile(web('manifest.json'), 'utf8'));
  assert.ok(manifest.name && manifest.short_name);
  assert.ok(manifest.start_url && manifest.id);
  assert.ok(['standalone', 'fullscreen', 'minimal-ui'].includes(manifest.display));
  assert.notEqual(manifest.prefer_related_applications, true);
  for (const size of ['192x192', '512x512']) {
    const icon = manifest.icons.find((i) => i.sizes === size && (i.purpose ?? 'any').includes('any'));
    assert.ok(icon, `${size} any-purpose icon`);
    assert.equal(icon.type, 'image/png');
    const png = await readFile(web(icon.src));
    assert.equal(png.readUInt32BE(16), Number(size.split('x')[0]), `${icon.src} width`);
    assert.equal(png.readUInt32BE(20), Number(size.split('x')[1]), `${icon.src} height`);
  }
  const html = await readFile(web('index.html'), 'utf8');
  assert.match(html, /<link rel="manifest" href="manifest.json">/);
  const bridge = html.indexOf('install_bridge.js');
  assert.ok(bridge > 0 && bridge < html.indexOf('<script src="flutter_bootstrap.js"'), 'bridge loads before Flutter');
});

test('Flutter loads without its self-unregistering service worker', async () => {
  const bootstrap = await readFile(web('flutter_bootstrap.js'), 'utf8');
  assert.match(bootstrap, /\{\{flutter_js\}\}/);
  assert.match(bootstrap, /\{\{flutter_build_config\}\}/);
  assert.doesNotMatch(bootstrap, /serviceWorker/);
  assert.ok((await stat(web('sw.js'))).size > 0);
});
