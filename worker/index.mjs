const headers = { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' };
const json = (data, status = 200) => new Response(JSON.stringify(data), { status, headers });
const MAX_BODY = 512;
const difficulties = ['easy', 'normal', 'hard'];
const boundedInteger = (value, max) => Number.isSafeInteger(value) && value >= 0 && value <= max;

export async function readScore(request) {
  if (!(request.headers.get('content-type') || '').toLowerCase().startsWith('application/json')) throw new Error('Use application/json');
  const reader = request.body?.getReader();
  if (!reader) throw new Error('Missing score');
  let size = 0;
  const chunks = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BODY) { await reader.cancel(); throw new Error('Score request too large'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  const data = JSON.parse(new TextDecoder().decode(bytes));
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).some(key => !['initials', 'score', 'difficulty', 'medals', 'activeMilliseconds', 'remainingLives'].includes(key)) || !/^[A-Z0-9]{3}$/.test(data.initials) || typeof data.initials !== 'string' || !Number.isSafeInteger(data.score) || data.score < 0 || data.score > 999999999) throw new Error('Expected three A-Z0-9 initials and a score from 0 to 999999999');
  if ('difficulty' in data && !difficulties.includes(data.difficulty)) throw new Error('Invalid difficulty');
  if ('medals' in data && !boundedInteger(data.medals, 5)) throw new Error('Invalid medals');
  if (data.activeMilliseconds != null && !boundedInteger(data.activeMilliseconds, 31536000000)) throw new Error('Invalid play time');
  if (data.remainingLives != null && (!boundedInteger(data.remainingLives, 999999) || data.medals !== 5)) throw new Error('Finisher lives require five medals');
  return data;
}

export class HighScores {
  constructor(state) {
    this.storage = state.storage;
    this.sql = state.storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS scores (id INTEGER PRIMARY KEY AUTOINCREMENT, initials TEXT NOT NULL, score INTEGER NOT NULL)');
    const columns = new Set([...this.sql.exec('PRAGMA table_info(scores)')].map(column => column.name));
    for (const [name, definition] of Object.entries({ difficulty: "TEXT NOT NULL DEFAULT 'normal'", medals: 'INTEGER NOT NULL DEFAULT 0', activeMilliseconds: 'INTEGER', remainingLives: 'INTEGER' })) {
      if (!columns.has(name)) this.sql.exec(`ALTER TABLE scores ADD COLUMN ${name} ${definition}`);
    }
  }
  list(difficulty = 'normal') {
    return [...this.sql.exec('SELECT initials, score, difficulty, medals, activeMilliseconds, remainingLives FROM scores WHERE difficulty = ? ORDER BY score DESC, id ASC LIMIT 10', difficulty)].map((entry, index) => ({ rank: index + 1, ...entry }));
  }
  async fetch(request) {
    if (request.method === 'GET') {
      const difficulty = new URL(request.url).searchParams.get('difficulty') ?? 'normal';
      if (!difficulties.includes(difficulty)) return json({ error: 'Invalid difficulty' }, 400);
      return json({ scores: this.list(difficulty) });
    }
    if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
    let score;
    try { score = await readScore(request); } catch { return json({ error: 'Use JSON with exactly three A-Z0-9 initials and an integer score from 0 to 999999999' }, 400); }
    this.storage.transactionSync(() => {
      this.sql.exec('INSERT INTO scores (initials, score, difficulty, medals, activeMilliseconds, remainingLives) VALUES (?, ?, ?, ?, ?, ?)', score.initials, score.score, score.difficulty ?? 'normal', score.medals ?? 0, score.activeMilliseconds ?? null, score.remainingLives ?? null);
      this.sql.exec('DELETE FROM scores WHERE difficulty = ? AND id NOT IN (SELECT id FROM scores WHERE difficulty = ? ORDER BY score DESC, id ASC LIMIT 10)', score.difficulty ?? 'normal', score.difficulty ?? 'normal');
    });
    return json({ scores: this.list(score.difficulty ?? 'normal') }, 201);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/api/scores') {
      if (!['GET', 'POST'].includes(request.method)) return json({ error: 'Method not allowed' }, 405);
      const origin = request.headers.get('origin');
      if (request.method === 'POST' && origin && origin !== url.origin) return json({ error: 'Origin not allowed' }, 403);
      const id = env.HIGH_SCORES.idFromName('global-top10-v1');
      return env.HIGH_SCORES.get(id).fetch(request);
    }
    if (url.pathname.startsWith('/api/')) return json({ error: 'Not found' }, 404);
    return env.ASSETS.fetch(request);
  },
};
