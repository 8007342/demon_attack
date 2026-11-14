import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { isStudioPath } from '../worker/index.mjs';

test('/studio serves the gallery app; other pages go to the assets as asked', async () => {
  const asked = [];
  const env = { ASSETS: { fetch: async request => { asked.push(new URL(request.url).pathname); return new Response('ok'); } } };
  for (const path of ['/studio', '/studio/', '/console', '/gallery/']) await worker.fetch(new Request(`https://game.test${path}`), env);
  assert.deepEqual(asked, ['/gallery/', '/gallery/', '/console', '/gallery/']);
});

test('isStudioPath matches only the studio address', () => {
  for (const p of ['/studio', '/studio/', '/Studio']) assert.ok(isStudioPath(p), p);
  for (const p of ['/', '/studios', '/gallery/', '/studio/x']) assert.ok(!isStudioPath(p), p);
});
