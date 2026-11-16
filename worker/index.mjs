import { handleNotes } from './notes.mjs';

export { ReviewNotes } from './notes.mjs';
const headers = { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' };
const json = (data, status = 200) => new Response(JSON.stringify(data), { status, headers });
const MAX_BODY = 512;
const difficulties = ['easy', 'normal', 'hard'];
const boundedInteger = (value, max) => Number.isSafeInteger(value) && value >= 0 && value <= max;
// bonus-balance: a record's run modifiers (the bonus levels met, the run rule) are catalogue ids.
const MAX_MODIFIERS = 4;
const modifierId = /^[a-z][A-Za-z0-9]{0,31}$/;
const validModifiers = (value) => Array.isArray(value) && value.length <= MAX_MODIFIERS && value.every(id => typeof id === 'string' && modifierId.test(id)) && new Set(value).size === value.length;
const isoDay = (date) => date.toISOString().slice(0, 10);
/** The play date: the client's local day when it is within a day of the server's, else the server's (UTC). */
export function playedOn(claimed, now = new Date()) {
  if (typeof claimed === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(claimed)) {
    const day = Date.parse(`${claimed}T00:00:00Z`);
    const today = Date.parse(`${isoDay(now)}T00:00:00Z`);
    if (Number.isFinite(day) && isoDay(new Date(day)) === claimed && Math.abs(day - today) <= 86400000) return claimed;
  }
  return isoDay(now);
}
const fields = ['initials', 'score', 'difficulty', 'medals', 'activeMilliseconds', 'remainingLives', 'modifiers', 'playedOn'];

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
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).some(key => !fields.includes(key)) || !/^[A-Z0-9]{3}$/.test(data.initials) || typeof data.initials !== 'string' || !Number.isSafeInteger(data.score) || data.score < 0 || data.score > 999999999) throw new Error('Expected three A-Z0-9 initials and a score from 0 to 999999999');
  if ('difficulty' in data && !difficulties.includes(data.difficulty)) throw new Error('Invalid difficulty');
  if ('medals' in data && !boundedInteger(data.medals, 5)) throw new Error('Invalid medals');
  if (data.activeMilliseconds != null && !boundedInteger(data.activeMilliseconds, 31536000000)) throw new Error('Invalid play time');
  if (data.remainingLives != null && (!boundedInteger(data.remainingLives, 999999) || data.medals !== 5)) throw new Error('Finisher lives require five medals');
  if (data.modifiers != null && !validModifiers(data.modifiers)) throw new Error('Invalid run modifiers');
  if (data.playedOn != null && typeof data.playedOn !== 'string') throw new Error('Invalid play date');
  return data;
}

export class HighScores {
  constructor(state) {
    this.storage = state.storage;
    this.sql = state.storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS scores (id INTEGER PRIMARY KEY AUTOINCREMENT, initials TEXT NOT NULL, score INTEGER NOT NULL)');
    const columns = new Set([...this.sql.exec('PRAGMA table_info(scores)')].map(column => column.name));
    for (const [name, definition] of Object.entries({ difficulty: "TEXT NOT NULL DEFAULT 'normal'", medals: 'INTEGER NOT NULL DEFAULT 0', activeMilliseconds: 'INTEGER', remainingLives: 'INTEGER', modifiers: "TEXT NOT NULL DEFAULT ''", playedOn: 'TEXT' })) {
      if (!columns.has(name)) this.sql.exec(`ALTER TABLE scores ADD COLUMN ${name} ${definition}`);
    }
  }
  list(difficulty = 'normal') {
    // Records saved before bonus-balance have no modifiers ('') and no play date (null).
    return [...this.sql.exec('SELECT initials, score, difficulty, medals, activeMilliseconds, remainingLives, modifiers, playedOn FROM scores WHERE difficulty = ? ORDER BY score DESC, id ASC LIMIT 10', difficulty)].map((entry, index) => ({ rank: index + 1, ...entry, modifiers: entry.modifiers ? entry.modifiers.split(',') : [], playedOn: entry.playedOn ?? null }));
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
      this.sql.exec('INSERT INTO scores (initials, score, difficulty, medals, activeMilliseconds, remainingLives, modifiers, playedOn) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', score.initials, score.score, score.difficulty ?? 'normal', score.medals ?? 0, score.activeMilliseconds ?? null, score.remainingLives ?? null, (score.modifiers ?? []).join(','), playedOn(score.playedOn));
      this.sql.exec('DELETE FROM scores WHERE difficulty = ? AND id NOT IN (SELECT id FROM scores WHERE difficulty = ? ORDER BY score DESC, id ASC LIMIT 10)', score.difficulty ?? 'normal', score.difficulty ?? 'normal');
    });
    return json({ scores: this.list(score.difficulty ?? 'normal') }, 201);
  }
}

/** The studio's own address: /studio, with or without a trailing slash. */
export function isStudioPath(pathname) {
  return /^\/studio\/?$/i.test(pathname);
}

/** The poster and QR page: /qr, with or without a trailing slash. */
export function isQrPath(pathname) {
  return /^\/qr\/?$/i.test(pathname);
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
    if (url.pathname === '/api/notes') return handleNotes(request, env);
    if (url.pathname.startsWith('/api/')) return json({ error: 'Not found' }, 404);
    // /studio is the asset review studio: the gallery app (built with base
    // href /gallery/), which opens the studio when the path is /studio.
    if (isStudioPath(url.pathname)) return env.ASSETS.fetch(new Request(new URL('/gallery/', url), request));
    // /qr is a static poster page (web/qr/index.html), served without the game.
    if (isQrPath(url.pathname)) return env.ASSETS.fetch(new Request(new URL('/qr/', url), request));
    return env.ASSETS.fetch(request);
  },
};
