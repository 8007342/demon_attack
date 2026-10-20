import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import worker, { HighScores, readScore } from '../worker/index.mjs';
const request = (data) => new Request('https://game.test/api/scores', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(data) });
function database() {
  const db = new DatabaseSync(':memory:');
  return { sql: { exec(sql, ...params) { const statement = db.prepare(sql); return statement.columns().length ? statement.all(...params) : (statement.run(...params), []); } }, transactionSync(fn) { db.exec('BEGIN'); try { fn(); db.exec('COMMIT'); } catch (error) { db.exec('ROLLBACK'); throw error; } } };
}
test('bounded input rejects malformed, unsafe scores and arbitrary initials', async () => {
  for (const data of [{ initials: 'AB', score: 10 }, { initials: 'abc', score: 10 }, { initials: 'A👾B', score: 10 }, { initials: 'ABC', score: -1 }, { initials: 'ABC', score: 1.5 }, { initials: 'ABC', score: 1e12 }, { initials: 'ABC', score: 10, name: 'private' }, null, []]) await assert.rejects(readScore(request(data)));
  await assert.rejects(readScore(request({ initials: 'ABC', score: 1, padding: 'x'.repeat(300) })));
  assert.deepEqual(await readScore(request({ initials: 'A09', score: 0 })), { initials: 'A09', score: 0 });
});
test('leaderboard persists only ten, ties favor earlier entries, responds in descending order', async () => {
  const storage = database();
  const board = new HighScores({ storage });
  for (let score = 0; score < 15; score++) assert.equal((await board.fetch(request({ initials: 'ABC', score }))).status, 201);
  await board.fetch(request({ initials: 'XYZ', score: 14 }));
  const scores = (await (await new HighScores({ storage }).fetch(new Request('https://game.test'))).json()).scores;
  assert.equal(scores.length, 10);
  assert.deepEqual(scores[0], { rank: 1, initials: 'ABC', score: 14 });
  assert.deepEqual(scores[1], { rank: 2, initials: 'XYZ', score: 14 });
  assert.equal([...storage.sql.exec('SELECT count(*) AS count FROM scores')][0].count, 10);
});
test('worker rejects cross-origin writes and routes unknown APIs without serving app HTML', async () => {
  assert.equal((await worker.fetch(new Request('https://game.test/api/scores', { method: 'POST', headers: { origin: 'https://other.test' } }), {})).status, 403);
  assert.equal((await worker.fetch(new Request('https://game.test/api/unknown'), {})).status, 404);
  assert.equal((await worker.fetch(new Request('https://game.test/api/scores', { method: 'DELETE' }), {})).status, 405);
});
