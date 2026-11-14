import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import worker, { ReviewNotes } from '../worker/index.mjs';
import { MAX_BATCH, NOTES_SCHEMA, validateNote } from '../worker/notes.mjs';

function database() {
  const db = new DatabaseSync(':memory:');
  return { sql: { exec(sql, ...params) { const statement = db.prepare(sql); return statement.columns().length ? statement.all(...params) : (statement.run(...params), []); } }, transactionSync(fn) { db.exec('BEGIN'); try { fn(); db.exec('COMMIT'); } catch (error) { db.exec('ROLLBACK'); throw error; } } };
}
const note = (over = {}) => ({
  id: 'note-0001', kind: 'radio', asset: 'gloat.d3', ref: 'radio / gloat.d3', source: 'web/audio/comms/gloat.d3.ogg',
  hash: 'a030bf5d03fb8b38', tags: ['needs-growl'], text: 'Still no growl in the second half.', offset: 1.25,
  createdAt: '2026-11-13T10:00:00.000Z', updatedAt: '2026-11-13T10:00:00.000Z', build: 'abc1234', ...over,
});
const post = (body, headers = {}) => new Request('https://game.test/api/notes', { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });
const listOf = async (board, query = '') => (await (await board.fetch(new Request(`https://game.test/api/notes${query}`))).json());

test('validates notes and keeps only known fields', () => {
  assert.deepEqual(validateNote(note()), note());
  const minimal = validateNote({ id: 'abcdefgh', kind: 'music', asset: 'l1-t3', tags: [], text: 'drums late', createdAt: '2026-11-13T10:00:00Z' });
  assert.equal(minimal.ref, 'music / l1-t3');
  assert.equal(minimal.updatedAt, '2026-11-13T10:00:00Z');
  for (const bad of [
    null, [], { ...note(), extra: 1 }, note({ id: 'short' }), note({ id: 'bad id!!' }), note({ kind: 'score' }),
    note({ asset: '' }), note({ tags: ['Needs Growl'] }), note({ tags: Array(17).fill('x') }), note({ tags: [], text: '  ' }),
    note({ offset: -1 }), note({ offset: '3' }), note({ createdAt: 'yesterday' }), note({ text: 'x'.repeat(4001) }), note({ hash: 'no spaces allowed' }),
  ]) assert.throws(() => validateNote(bad));
});

test('stores, filters, upserts and deletes notes in SQLite', async () => {
  const storage = database();
  const board = new ReviewNotes({ storage });
  const created = await board.fetch(post({ notes: [note(), note({ id: 'note-0002', kind: 'music', asset: 'l1-t3', ref: undefined, tags: ['timing', 'refine'], offset: null })] }));
  assert.equal(created.status, 201);
  assert.equal((await created.json()).saved, 2);
  const all = await listOf(new ReviewNotes({ storage }));
  assert.equal(all.schema, NOTES_SCHEMA);
  assert.equal(all.count, 2);
  assert.ok(all.notes.every(n => n.receivedAt));
  assert.equal((await listOf(board, '?kind=radio')).notes[0].asset, 'gloat.d3');
  assert.equal((await listOf(board, '?tag=timing')).notes[0].id, 'note-0002');
  assert.equal((await listOf(board, '?asset=l1-t3')).count, 1);
  assert.equal((await board.fetch(new Request('https://game.test/api/notes?kind=scores'))).status, 400);

  // A newer edit replaces the note; an older copy (offline device) does not.
  await board.fetch(post(note({ text: 'Growl fixed?', updatedAt: '2026-11-13T11:00:00.000Z' })));
  await board.fetch(post(note({ text: 'stale', updatedAt: '2026-11-13T10:30:00.000Z' })));
  const edited = (await listOf(board, '?kind=radio')).notes;
  assert.equal(edited.length, 1);
  assert.equal(edited[0].text, 'Growl fixed?');
  assert.equal((await listOf(board, '?since=2026-11-13T10:30:00.000Z')).count, 1);

  const removed = await board.fetch(new Request('https://game.test/api/notes?id=note-0001', { method: 'DELETE' }));
  assert.deepEqual(await removed.json(), { deleted: 1 });
  assert.equal((await listOf(board)).count, 1);
  assert.equal((await board.fetch(new Request('https://game.test/api/notes', { method: 'DELETE' }))).status, 400);
});

test('rejects malformed, oversized and over-long batches', async () => {
  const board = new ReviewNotes({ storage: database() });
  assert.equal((await board.fetch(post({ notes: [note({ kind: 'nope' })] }))).status, 400);
  assert.equal((await board.fetch(post({ notes: [] }))).status, 400);
  const many = Array.from({ length: MAX_BATCH + 1 }, (_, i) => note({ id: `note-${String(i).padStart(5, '0')}` }));
  assert.equal((await board.fetch(post({ notes: many }))).status, 400);
  const huge = new Request('https://game.test/api/notes', { method: 'POST', headers: { 'content-type': 'application/json' }, body: ' '.repeat(300 * 1024) + '{}' });
  assert.equal((await board.fetch(huge)).status, 400);
  assert.equal((await board.fetch(new Request('https://game.test/api/notes', { method: 'POST', body: '{}' }))).status, 400);
  assert.equal((await listOf(board)).count, 0);
});

test('worker gates notes behind the operator token and keeps them off the score API', async () => {
  let name;
  const env = {
    NOTES_TOKEN: 'operator-secret',
    REVIEW_NOTES: { idFromName(value) { name = value; return value; }, get() { return { fetch: () => new Response('{"notes":[]}') }; } },
    HIGH_SCORES: { idFromName() { throw new Error('notes must not touch the high scores'); } },
  };
  const get = (headers = {}) => worker.fetch(new Request('https://game.test/api/notes', { headers }), env);
  assert.equal((await worker.fetch(new Request('https://game.test/api/notes'), {})).status, 503);
  assert.equal((await get()).status, 401);
  assert.equal((await get({ authorization: 'Bearer wrong' })).status, 401);
  assert.equal((await get({ authorization: 'Bearer operator-secre' })).status, 401);
  assert.equal((await get({ authorization: 'Bearer operator-secret' })).status, 200);
  assert.equal(name, 'asset-review-notes-v1');
  const crossOrigin = post(note(), { authorization: 'Bearer operator-secret', origin: 'https://other.test' });
  assert.equal((await worker.fetch(crossOrigin, env)).status, 403);
  assert.equal((await worker.fetch(new Request('https://game.test/api/notes', { method: 'PUT', headers: { authorization: 'Bearer operator-secret' } }), env)).status, 405);
});

test('tools/review_notes.lua turns an export into a worklist grouped by tag', { skip: spawnSync('lua', ['-v']).error ? 'lua not installed' : false }, () => {
  const dir = mkdtempSync(join(tmpdir(), 'notes-'));
  const file = join(dir, 'notes.json');
  writeFileSync(file, JSON.stringify({ schema: NOTES_SCHEMA, notes: [
    note(),
    note({ id: 'note-0002', kind: 'music', asset: 'l1-t3', ref: 'music / l1-t3', tags: ['timing', 'refine'], text: 'Bar 3 “late”', offset: 65.5, section: 'bars 3-4' }),
    note({ id: 'note-0003', tags: [], text: 'Untagged thought' }),
  ] }));
  const out = spawnSync('lua', ['tools/review_notes.lua', file], { encoding: 'utf8' });
  assert.equal(out.status, 0, out.stderr);
  assert.match(out.stdout, /^# Asset review worklist/m);
  assert.match(out.stdout, /## needs-growl \(1\)/);
  assert.match(out.stdout, /## timing \(1\)/);
  assert.match(out.stdout, /## untagged \(1\)/);
  assert.match(out.stdout, /`music \/ l1-t3` @ 1:05\.5 · bars 3-4/);
  assert.match(out.stdout, /Bar 3 “late”/);
  assert.ok(out.stdout.indexOf('## refine') < out.stdout.indexOf('## needs-growl'));
  const filtered = spawnSync('lua', ['tools/review_notes.lua', '--tag', 'timing', file], { encoding: 'utf8' });
  assert.equal(filtered.status, 0, filtered.stderr);
  assert.doesNotMatch(filtered.stdout, /needs-growl \(/);
});
