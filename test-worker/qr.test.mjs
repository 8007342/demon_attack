import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { isQrPath } from '../worker/index.mjs';

test('/qr serves the poster page; the game stays on /', async () => {
  const asked = [];
  const env = { ASSETS: { fetch: async request => { asked.push(new URL(request.url).pathname); return new Response('ok'); } } };
  for (const path of ['/qr', '/qr/', '/QR', '/']) await worker.fetch(new Request(`https://game.test${path}`), env);
  assert.deepEqual(asked, ['/qr/', '/qr/', '/qr/', '/']);
});

test('isQrPath matches only the poster address', () => {
  for (const p of ['/qr', '/qr/', '/Qr']) assert.ok(isQrPath(p), p);
  for (const p of ['/', '/qrs', '/qr/poster-portrait.jpg', '/studio']) assert.ok(!isQrPath(p), p);
});
