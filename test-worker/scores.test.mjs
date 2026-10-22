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
  assert.deepEqual(scores[0], { rank: 1, initials: 'ABC', score: 14, difficulty: 'normal', medals: 0, activeMilliseconds: null, remainingLives: null });
  assert.deepEqual(scores[1], { rank: 2, initials: 'XYZ', score: 14, difficulty: 'normal', medals: 0, activeMilliseconds: null, remainingLives: null });
  assert.equal([...storage.sql.exec('SELECT count(*) AS count FROM scores')][0].count, 10);
});
test('worker rejects cross-origin writes and routes unknown APIs without serving app HTML', async () => {
  assert.equal((await worker.fetch(new Request('https://game.test/api/scores', { method: 'POST', headers: { origin: 'https://other.test' } }), {})).status, 403);
  assert.equal((await worker.fetch(new Request('https://game.test/api/unknown'), {})).status, 404);
  assert.equal((await worker.fetch(new Request('https://game.test/api/scores', { method: 'DELETE' }), {})).status, 405);
});

test('migrates legacy scores and keeps ten independent scores per mode', async () => {
  const storage = database();
  storage.sql.exec('CREATE TABLE scores (id INTEGER PRIMARY KEY AUTOINCREMENT, initials TEXT NOT NULL, score INTEGER NOT NULL)');
  storage.sql.exec("INSERT INTO scores (initials, score) VALUES ('OLD', 999)");
  const board = new HighScores({ storage });
  assert.equal(board.list()[0].initials, 'OLD');
  assert.equal(board.list()[0].activeMilliseconds, null);
  for (const difficulty of ['easy', 'normal', 'hard']) {
    for (let score = 0; score < 12; score++) await board.fetch(request({ initials: 'NEW', score, difficulty, medals: 5, activeMilliseconds: 123, remainingLives: 4 }));
    const response = await board.fetch(new Request(`https://game.test/api/scores?difficulty=${difficulty}`));
    const entries = (await response.json()).scores;
    assert.equal(entries.length, 10);
    assert.ok(entries.every(entry => entry.difficulty === difficulty));
  }
  assert.equal(board.list()[0].initials, 'OLD');
  assert.equal(board.list('easy')[0].remainingLives, 4);
  assert.equal([...storage.sql.exec('SELECT count(*) AS count FROM scores')][0].count, 30);
  assert.equal(new HighScores({ storage }).list().length, 10);
});
test('rejects inconsistent and unbounded metadata', async () => {
  for (const metadata of [{ difficulty: 'extreme' }, { difficulty: null }, { medals: 6 }, { medals: -1 }, { medals: 1.5 }, { activeMilliseconds: -1 }, { activeMilliseconds: 31536000001 }, { activeMilliseconds: '12' }, { remainingLives: 3 }, { medals: 5, remainingLives: 1000000 }]) {
    await assert.rejects(readScore(request({ initials: 'ABC', score: 10, ...metadata })));
  }
  const board = new HighScores({ storage: database() });
  assert.equal((await board.fetch(new Request('https://game.test/api/scores?difficulty=unknown'))).status, 400);
});
test('worker preserves the Durable Object identity and forwards mode requests', async () => {
  let name;
  let forwarded;
  const response = await worker.fetch(new Request('https://game.test/api/scores?difficulty=easy'), { HIGH_SCORES: {
    idFromName(value) { name = value; return value; },
    get() { return { fetch(request) { forwarded = request.url; return new Response('{}'); } }; },
  } });
  assert.equal(response.status, 200);
  assert.equal(name, 'global-top10-v1');
  assert.match(forwarded, /difficulty=easy/);
});
test('body limit rejects oversized valid JSON and nullable legacy metadata remains unknown', async () => {
  const oversized = new Request('https://game.test/api/scores', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: ' '.repeat(513) + JSON.stringify({ initials: 'ABC', score: 1 }),
  });
  await assert.rejects(readScore(oversized), /too large/);
  const board = new HighScores({ storage: database() });
  const response = await board.fetch(request({ initials: 'ABC', score: 1, medals: 0, activeMilliseconds: null, remainingLives: null }));
  assert.equal(response.status, 201);
  const entry = (await response.json()).scores[0];
  assert.equal(entry.activeMilliseconds, null);
  assert.equal(entry.remainingLives, null);
  assert.equal(entry.difficulty, 'normal');
  assert.equal((await board.fetch(request({ initials: 'BAD', score: 999, medals: 4, remainingLives: 3 }))).status, 400);
  assert.equal(board.list().length, 1);
});
