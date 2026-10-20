const headers = { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' };
const json = (data, status = 200) => new Response(JSON.stringify(data), { status, headers });
const MAX_BODY = 256;

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
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).some(key => !['initials', 'score'].includes(key)) || !/^[A-Z0-9]{3}$/.test(data.initials) || typeof data.initials !== 'string' || !Number.isSafeInteger(data.score) || data.score < 0 || data.score > 999999999) throw new Error('Expected three A-Z0-9 initials and a score from 0 to 999999999');
  return { initials: data.initials, score: data.score };
}

export class HighScores {
  constructor(state) {
    this.storage = state.storage;
    this.sql = state.storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS scores (id INTEGER PRIMARY KEY AUTOINCREMENT, initials TEXT NOT NULL, score INTEGER NOT NULL)');
  }
  list() {
    return [...this.sql.exec('SELECT initials, score FROM scores ORDER BY score DESC, id ASC LIMIT 10')].map((entry, index) => ({ rank: index + 1, initials: entry.initials, score: entry.score }));
  }
  async fetch(request) {
    if (request.method === 'GET') return json({ scores: this.list() });
    if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
    let score;
    try { score = await readScore(request); } catch { return json({ error: 'Use JSON with exactly three A-Z0-9 initials and an integer score from 0 to 999999999' }, 400); }
    this.storage.transactionSync(() => {
      this.sql.exec('INSERT INTO scores (initials, score) VALUES (?, ?)', score.initials, score.score);
      this.sql.exec('DELETE FROM scores WHERE id NOT IN (SELECT id FROM scores ORDER BY score DESC, id ASC LIMIT 10)');
    });
    return json({ scores: this.list() }, 201);
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
