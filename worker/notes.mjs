// Operator-only asset review notes (/api/notes), written by the asset review
// studio in the gallery (lib/review/). Stored in their own SQLite Durable
// Object, apart from the public high scores, and readable only with the
// NOTES_TOKEN secret (`wrangler secret put NOTES_TOKEN`; `.dev.vars` locally).
// Without the secret the API answers 503: notes are never public.
//
//   GET    /api/notes[?kind=radio&asset=<id>&tag=needs-growl&since=<ISO>]
//   POST   /api/notes   { "notes": [note, ...] } or one note object
//   DELETE /api/notes?id=<note id>
//
// Every call needs `authorization: Bearer <NOTES_TOKEN>`. The note format is
// the studio's export format (schema below); see tools/review_notes.lua.

export const NOTES_SCHEMA = 'demon-attack.notes/v1';
export const NOTE_KINDS = ['background', 'atlas', 'radio', 'music', 'scene', 'page'];
export const MAX_NOTES_BODY = 256 * 1024;
export const MAX_BATCH = 200;
export const MAX_STORED = 5000;

const headers = { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' };
const json = (data, status = 200) => new Response(JSON.stringify(data), { status, headers });
const isText = (value, max, min = 0) => typeof value === 'string' && value.length >= min && value.length <= max;
const optionalText = (value, max) => value == null || isText(value, max);
const isoTime = value => isText(value, 40, 10) && /^\d{4}-\d{2}-\d{2}T[\d:.]+(Z|[+-]\d{2}:?\d{2})$/.test(value) && !Number.isNaN(Date.parse(value));
const noteKeys = ['id', 'ref', 'kind', 'asset', 'source', 'hash', 'tags', 'text', 'offset', 'section', 'createdAt', 'updatedAt', 'build'];

/// The validated note, with only the known keys; throws on anything else.
export function validateNote(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('A note is an object');
  const unknown = Object.keys(data).filter(key => !noteKeys.includes(key));
  if (unknown.length) throw new Error(`Unknown note fields: ${unknown.join(', ')}`);
  if (!isText(data.id, 64, 8) || !/^[A-Za-z0-9_-]+$/.test(data.id)) throw new Error('id: 8-64 letters, digits, _ or -');
  if (!NOTE_KINDS.includes(data.kind)) throw new Error(`kind: one of ${NOTE_KINDS.join(', ')}`);
  if (!isText(data.asset, 200, 1) || /[\u0000-\u001f]/.test(data.asset)) throw new Error('asset: 1-200 printable characters');
  if (!optionalText(data.ref, 260) || !optionalText(data.source, 400) || !optionalText(data.section, 120) || !optionalText(data.build, 64)) throw new Error('ref, source, section or build too long');
  if (data.hash != null && !(isText(data.hash, 128, 6) && /^[A-Za-z0-9:._-]+$/.test(data.hash))) throw new Error('hash: 6-128 hash characters');
  if (!Array.isArray(data.tags) || data.tags.length > 16 || data.tags.some(tag => !isText(tag, 32, 1) || !/^[a-z0-9][a-z0-9-]*$/.test(tag))) throw new Error('tags: up to 16 lowercase-kebab tags');
  if (!optionalText(data.text, 4000)) throw new Error('text: up to 4000 characters');
  if (!data.tags.length && !(data.text || '').trim()) throw new Error('A note needs a tag or text');
  if (data.offset != null && !(typeof data.offset === 'number' && Number.isFinite(data.offset) && data.offset >= 0 && data.offset <= 36000)) throw new Error('offset: seconds from 0 to 36000');
  if (!isoTime(data.createdAt) || (data.updatedAt != null && !isoTime(data.updatedAt))) throw new Error('createdAt / updatedAt: ISO times');
  const note = {};
  for (const key of noteKeys) if (data[key] !== undefined && data[key] !== null) note[key] = data[key];
  note.tags = [...new Set(data.tags)];
  note.ref ??= `${note.kind} / ${note.asset}`;
  note.updatedAt ??= note.createdAt;
  return note;
}

async function readBody(request) {
  if (!(request.headers.get('content-type') || '').toLowerCase().startsWith('application/json')) throw new Error('Use application/json');
  const reader = request.body?.getReader();
  if (!reader) throw new Error('Missing notes');
  let size = 0;
  const chunks = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_NOTES_BODY) { await reader.cancel(); throw new Error('Notes request too large'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return JSON.parse(new TextDecoder().decode(bytes));
}

/// The notes of a POST body ({notes: [...]}, an array, or one note).
export async function readNotes(request) {
  const data = await readBody(request);
  const list = Array.isArray(data) ? data : Array.isArray(data?.notes) ? data.notes : [data];
  if (!list.length || list.length > MAX_BATCH) throw new Error(`Send 1-${MAX_BATCH} notes`);
  return list.map(validateNote);
}

export class ReviewNotes {
  constructor(state) {
    this.storage = state.storage;
    this.sql = state.storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, kind TEXT NOT NULL, asset TEXT NOT NULL, updatedAt TEXT NOT NULL, receivedAt TEXT NOT NULL, data TEXT NOT NULL)');
    this.sql.exec('CREATE INDEX IF NOT EXISTS notes_asset ON notes (kind, asset)');
  }
  list({ kind, asset, tag, since } = {}) {
    const where = [], params = [];
    if (kind) { where.push('kind = ?'); params.push(kind); }
    if (asset) { where.push('asset = ?'); params.push(asset); }
    if (since) { where.push('updatedAt > ?'); params.push(since); }
    const rows = [...this.sql.exec(`SELECT data, receivedAt FROM notes${where.length ? ` WHERE ${where.join(' AND ')}` : ''} ORDER BY kind, asset, updatedAt`, ...params)];
    const notes = rows.map(row => ({ ...JSON.parse(row.data), receivedAt: row.receivedAt }));
    return tag ? notes.filter(note => note.tags.includes(tag)) : notes;
  }
  count() { return [...this.sql.exec('SELECT count(*) AS count FROM notes')][0].count; }
  async fetch(request) {
    const url = new URL(request.url);
    if (request.method === 'GET') {
      const query = Object.fromEntries(['kind', 'asset', 'tag', 'since'].map(key => [key, url.searchParams.get(key) || undefined]));
      if (query.kind && !NOTE_KINDS.includes(query.kind)) return json({ error: 'Unknown kind' }, 400);
      const notes = this.list(query);
      return json({ schema: NOTES_SCHEMA, count: notes.length, notes });
    }
    if (request.method === 'DELETE') {
      const id = url.searchParams.get('id') || '';
      if (!/^[A-Za-z0-9_-]{8,64}$/.test(id)) return json({ error: 'Give ?id=<note id>' }, 400);
      const existed = [...this.sql.exec('SELECT id FROM notes WHERE id = ?', id)].length;
      this.sql.exec('DELETE FROM notes WHERE id = ?', id);
      return json({ deleted: existed });
    }
    if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
    let notes;
    try { notes = await readNotes(request); } catch (error) { return json({ error: `Invalid notes: ${error.message}` }, 400); }
    const fresh = notes.filter(note => ![...this.sql.exec('SELECT id FROM notes WHERE id = ?', note.id)].length).length;
    if (this.count() + fresh > MAX_STORED) return json({ error: `Notes are capped at ${MAX_STORED}; export and prune first` }, 507);
    const receivedAt = new Date().toISOString();
    let saved = 0;
    this.storage.transactionSync(() => {
      for (const note of notes) {
        // Last writer by updatedAt wins, so an old offline copy never overwrites an edit.
        const before = [...this.sql.exec('SELECT updatedAt FROM notes WHERE id = ?', note.id)][0];
        if (before && before.updatedAt > note.updatedAt) continue;
        this.sql.exec('INSERT INTO notes (id, kind, asset, updatedAt, receivedAt, data) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET kind = excluded.kind, asset = excluded.asset, updatedAt = excluded.updatedAt, receivedAt = excluded.receivedAt, data = excluded.data',
          note.id, note.kind, note.asset, note.updatedAt, receivedAt, JSON.stringify(note));
        saved++;
      }
    });
    return json({ schema: NOTES_SCHEMA, saved, ids: notes.map(note => note.id) }, 201);
  }
}

function sameSecret(given, expected) {
  const a = new TextEncoder().encode(given), b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < b.length; i++) diff |= (a[i % (a.length || 1)] ?? 0) ^ b[i];
  return diff === 0;
}

/// Worker-side gate for /api/notes: token, method and origin checks, then the
/// single notes Durable Object.
export function handleNotes(request, env) {
  const url = new URL(request.url);
  if (!['GET', 'POST', 'DELETE'].includes(request.method)) return json({ error: 'Method not allowed' }, 405);
  if (!env.NOTES_TOKEN || !env.REVIEW_NOTES) return json({ error: 'Notes are not configured on this deployment' }, 503);
  const auth = request.headers.get('authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  if (!token || !sameSecret(token, env.NOTES_TOKEN)) return json({ error: 'Operator token required' }, 401);
  const origin = request.headers.get('origin');
  if (request.method !== 'GET' && origin && origin !== url.origin) return json({ error: 'Origin not allowed' }, 403);
  const id = env.REVIEW_NOTES.idFromName('asset-review-notes-v1');
  return env.REVIEW_NOTES.get(id).fetch(request);
}
