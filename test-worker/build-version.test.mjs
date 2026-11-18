// build-version: the version stamp script (scripts/build-version.mjs) and
// the /version endpoint (openspec/changes/build-version).
import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import worker from '../worker/index.mjs';
import { isVersionPath } from '../worker/version.mjs';
import {
  countDailyBuilds,
  epochMajor,
  formatVersion,
  localDay,
  resolveBuildVersion,
} from '../scripts/build-version.mjs';

const cases = JSON.parse(readFileSync(new URL('../test/fixtures/build_version_cases.json', import.meta.url), 'utf8')).cases;

test('the major is years since 1970: 2026 is 56', () => {
  assert.equal(epochMajor(2026), 56);
  assert.equal(epochMajor(2027), 57);
});

test('formatVersion matches the shared cases', () => {
  for (const c of cases) assert.equal(formatVersion(c), c.version, JSON.stringify(c));
});

test('the day is the committer-local date, not UTC', () => {
  // PR #7's merge: 01:53 UTC on the 17th, but the 16th where it was merged.
  assert.equal(localDay('2026-11-16T17:53:59-08:00'), '2026-11-16');
  assert.equal(localDay('2026-11-17T08:21:59-08:00'), '2026-11-17');
});

test('countDailyBuilds counts the leading run on one day', () => {
  const c = (iso, root = false) => ({ iso, root });
  assert.deepEqual(
    countDailyBuilds([c('2026-11-17T09:00:00-08:00'), c('2026-11-17T08:00:00-08:00'), c('2026-11-16T17:53:59-08:00')]),
    { day: '2026-11-17', build: 2, exact: true },
  );
  assert.deepEqual(countDailyBuilds([c('2026-11-17T08:00:00-08:00', true)]), { day: '2026-11-17', build: 1, exact: true });
  assert.deepEqual(countDailyBuilds([c('2026-11-17T08:00:00-08:00')]), { day: '2026-11-17', build: 1, exact: false });
});

// A throwaway repository shaped like main on 2026-11-15..17.
function fixtureRepo() {
  const dir = mkdtempSync(join(tmpdir(), 'build-version-'));
  const env = { ...process.env, GIT_AUTHOR_NAME: 't', GIT_AUTHOR_EMAIL: 't@t', GIT_COMMITTER_NAME: 't', GIT_COMMITTER_EMAIL: 't@t' };
  const git = (args, extra = {}) => execFileSync('git', args, { cwd: dir, env: { ...env, ...extra }, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
  git(['init', '-q', '-b', 'main']);
  const dates = ['2026-11-15T09:40:08-08:00', '2026-11-16T17:50:35-08:00', '2026-11-16T17:53:59-08:00', '2026-11-17T08:21:59-08:00'];
  dates.forEach((date, i) => {
    writeFileSync(join(dir, 'f'), String(i));
    git(['add', 'f']);
    git(['commit', '-q', '-m', `c${i}`], { GIT_COMMITTER_DATE: date, GIT_AUTHOR_DATE: date });
  });
  return { dir, git };
}

test('resolveBuildVersion numbers main builds per committer-local day', () => {
  const { dir, git } = fixtureRepo();
  try {
    const env = { WORKERS_CI_BRANCH: 'main' };
    assert.equal(resolveBuildVersion({ cwd: dir, env, fetch: false }).version, 'v56.11.17.1');
    assert.equal(resolveBuildVersion({ cwd: dir, env, fetch: false, ref: 'HEAD~1' }).version, 'v56.11.16.2');
    assert.equal(resolveBuildVersion({ cwd: dir, env, fetch: false, ref: 'HEAD~3' }).version, 'v56.11.15.1');
    const sha = git(['rev-parse', '--short=8', 'HEAD']);
    const dev = resolveBuildVersion({ cwd: dir, env: { WORKERS_CI_BRANCH: 'game' }, fetch: false });
    assert.equal(dev.version, `v56.11.17-dev+${sha}`);
    assert.equal(dev.channel, 'dev');
    // Without WORKERS_CI_BRANCH the checked-out branch decides.
    assert.equal(resolveBuildVersion({ cwd: dir, env: {}, fetch: false }).version, 'v56.11.17.1');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('a shallow clone deepens to find the day, or falls back to .0+sha', () => {
  const { dir } = fixtureRepo();
  const clone = mkdtempSync(join(tmpdir(), 'build-version-clone-'));
  try {
    execFileSync('git', ['clone', '-q', '--depth', '1', '-b', 'main', `file://${dir}`, clone], { stdio: 'ignore' });
    // Mid-day: the shallow tip alone cannot tell .1 from .2.
    const env = { WORKERS_CI_BRANCH: 'main' };
    const blind = resolveBuildVersion({ cwd: clone, env, fetch: false });
    assert.match(blind.version, /^v56\.11\.17\.0\+[0-9a-f]{8}$/);
    assert.equal(blind.build, 0);
    const deepened = resolveBuildVersion({ cwd: clone, env });
    assert.equal(deepened.version, 'v56.11.17.1');
  } finally {
    rmSync(dir, { recursive: true, force: true });
    rmSync(clone, { recursive: true, force: true });
  }
});

test('/version serves the build record from the assets, uncached', async () => {
  const record = { version: 'v56.11.17.1', channel: 'production', date: '2026-11-17', build: 1, commit: '58a1140f', branch: 'main' };
  const asked = [];
  const env = {
    ASSETS: {
      fetch: async request => {
        asked.push(new URL(request.url).pathname);
        return new Response(JSON.stringify(record), { headers: { 'content-type': 'application/json' } });
      },
    },
  };
  for (const path of ['/version', '/version/']) {
    const res = await worker.fetch(new Request(`https://game.test${path}`), env);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('cache-control'), 'no-store');
    assert.equal(res.headers.get('x-build-version'), 'v56.11.17.1');
    assert.deepEqual(await res.json(), record);
  }
  assert.deepEqual(asked, ['/version.json', '/version.json']);
});

test('/version answers 404 JSON when the build wrote no record', async () => {
  // Missing: a 404, or the SPA shell (HTML, 200) from not_found_handling.
  for (const fallback of [new Response('nope', { status: 404 }), new Response('<!doctype html>', { status: 200 })]) {
    const env = { ASSETS: { fetch: async () => fallback } };
    const res = await worker.fetch(new Request('https://game.test/version'), env);
    assert.equal(res.status, 404);
    assert.equal((await res.json()).version, 'unknown');
  }
});

test('isVersionPath matches only the version address', () => {
  for (const p of ['/version', '/version/', '/Version']) assert.ok(isVersionPath(p), p);
  for (const p of ['/', '/versions', '/version.json', '/version/x']) assert.ok(!isVersionPath(p), p);
});
