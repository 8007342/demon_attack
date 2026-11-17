// The score's sample bank and its gates (adaptive-soundtrack design §12.9; tasks 8.5, 8.10, 8.12, 8.13):
// - the bank builder (tools/bank/bank_build.lua) on a synthetic fixture: sine tones made with ffmpeg, never a real
//   sample (the CC0 pins are not admitted yet);
// - the zone plan of art/music/bank/recipe.json against the committed score, and its budgets;
// - the score gate `lua tools/midi_stats.lua check` on the committed score and on a broken fixture;
// - the sampler in web/audio/demon-score.js on a mocked audio clock: no bank, a bank still decoding, a decoded bank.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile, mkdtemp, mkdir, rm, stat, appendFile } from 'node:fs/promises';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import vm from 'node:vm';

const repo = new URL('..', import.meta.url).pathname;
const web = path => new URL(`../web/${path}`, import.meta.url);
const manifest = JSON.parse(await readFile(web('audio/score/score.json'), 'utf8'));
const has = cmd => spawnSync(cmd, ['-version'], { stdio: 'ignore' }).status === 0 || spawnSync(cmd, ['-v'], { stdio: 'ignore' }).status === 0;
const tools = has('lua') && has('ffmpeg') && has('git');
const lua = (args, opts = {}) => spawnSync('lua', args, { cwd: repo, encoding: 'utf8', maxBuffer: 1 << 26, ...opts });

// The score's notes, parsed by the shipped player's own parser.
function scoreParser() {
  const sandbox = { window: {}, document: { baseURI: 'https://game.test/' }, URL, Uint8Array, DataView, Map, Set, Math, Object, Promise, Array,
    Number, String, Error, Float32Array, fetch: async () => ({ ok: false }) };
  vm.createContext(sandbox);
  return readFile(web('audio/demon-score.js'), 'utf8').then(code => { vm.runInContext(code, sandbox); return sandbox.window.demonScore.parseScore; });
}
async function sections() {
  const parse = await scoreParser(), out = [];
  for (const [song, spec] of Object.entries(manifest.songs)) {
    for (const [id, s] of Object.entries(spec.sections)) {
      const bytes = await readFile(web(`audio/score/${s.file}`));
      out.push({ song, id, spec: s, songSpec: spec, score: parse(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)) });
    }
  }
  return out;
}
let planCache = null;
function plan() {
  if (planCache) return planCache;
  const r = lua(['tools/bank/bank_build.lua', '--dry-run', '--json']);
  assert.equal(r.status, 0, r.stderr);
  planCache = JSON.parse(r.stdout);
  return planCache;
}

test('8.13 the score files parse, every section is whole bars, and every mask names a real track', async () => {
  for (const { song, id, spec, songSpec, score } of await sections()) {
    const total = (spec.bars + spec.hold) * 4;
    assert.ok(Object.keys(score.tracks).length > 0, `${song}/${id} has tracks`);
    for (const [name, notes] of Object.entries(score.tracks)) {
      assert.ok(manifest.tracks[name], `${song}/${id}: ${name} is a known track`);
      for (const n of notes) assert.ok(n.beat >= 0 && n.beat + n.len <= total + 1e-9, `${song}/${id} ${name}: a note at ${n.beat} inside ${total} beats`);
    }
    const masks = spec.masks || songSpec.masks || manifest.masks;
    for (const tier of ['1', '2', '3', '4']) for (const name of masks[tier]) assert.ok(manifest.tracks[name], `${song}/${id}: mask ${tier} names ${name}`);
  }
});

test('8.13 the bank plan: zones cover the score note for note where the recipe says so, and report the rest', { skip: !tools && 'needs lua' }, async () => {
  const p = plan();
  const instruments = p.instruments;
  const tonesOf = role => (role === 'drums' ? [0] : p.roles[role]?.chord || [0]);
  const covers = (role, pitch, vel, seconds) => instruments.find(inst => inst.roles.includes(role)
    && !(inst.when && ((inst.when.velMax != null && vel > inst.when.velMax) || (inst.when.durMax != null && seconds > inst.when.durMax)))
    && tonesOf(role).every(t => p.zones.some(z => z.inst === inst.id && (z.keys ? z.keys.includes(pitch) : pitch + t >= z.lo && pitch + t <= z.hi))));
  const tally = {};
  for (const { songSpec, score } of await sections()) {
    const bs = songSpec.barSamples / 48000 / 4;
    for (const [name, notes] of Object.entries(score.tracks)) {
      const role = manifest.tracks[name].role;
      if (!p.roles[role]) continue;
      const t = tally[role] ||= { notes: 0, covered: 0 };
      for (const n of notes) { t.notes++; if (covers(role, n.pitch, n.vel, n.len * bs)) t.covered++; }
    }
  }
  // Drums are `cover: full`: every GM key the score plays has a zone. The pitched roles keep most of their notes
  // in range (design §12.9 lists the gaps: high brass and bells, the lowest bass and guitar roots).
  assert.equal(tally.drums.covered, tally.drums.notes, 'every drum note has a zone');
  for (const role of ['bass', 'guitarL', 'guitarR', 'timpani', 'organ']) assert.ok(tally[role].covered / tally[role].notes > .9, `${role} ${tally[role].covered}/${tally[role].notes}`);
  // Zones: a role the score knows, a sprite in the plan, a sane key and velocity range.
  const roles = new Set(Object.values(manifest.tracks).map(t => t.role));
  const sprites = new Set(p.sprites.map(s => s.file));
  for (const z of p.zones) {
    assert.ok(sprites.has(z.sprite), z.id);
    for (const r of z.roles) assert.ok(roles.has(r), `${z.id}: role ${r} plays in the score`);
    assert.ok(z.vlo >= 1 && z.vhi <= 127 && z.vlo <= z.vhi, z.id);
    if (!z.keys) assert.ok(z.lo <= z.root && z.root <= z.hi && z.hi - z.lo <= 12, `${z.id}: ${z.lo}-${z.root}-${z.hi}`);
    assert.match(z.source.blob, /^[0-9a-f]{40}$/);
  }
  // Budgets (design §11.5): <= 2 MB Opus, <= 41 MB decoded, <= 16 MB decoded on phones; tier 1 loads first.
  assert.deepEqual(p.over, []);
  assert.ok(p.totals.opusBytes <= 2e6 && p.totals.decodedDesktop <= 41e6 && p.totals.decodedPhone <= 16e6, JSON.stringify(p.totals));
  assert.deepEqual(p.sprites.map(s => s.tier), [...p.sprites.map(s => s.tier)].sort());
  assert.ok(p.sprites[0].phone && p.sprites[0].tier === 1);
  // A built bank, once the pins are admitted: its sprites exist with their pinned sizes and hashes.
  const built = await readFile(web('audio/bank/bank.json'), 'utf8').then(JSON.parse, () => null);
  if (built) {
    for (const s of built.sprites) {
      const bytes = await readFile(web(`audio/bank/${s.file}`));
      assert.equal(bytes.length, s.bytes, s.file);
      assert.equal(createHash('sha256').update(bytes).digest('hex'), s.sha256, s.file);
    }
  }
});

test('8.10 the score gate: midi_stats.lua check passes on the committed score and fails a broken one', { skip: !tools && 'needs lua' }, async () => {
  const ok = lua(['tools/midi_stats.lua', 'check']);
  assert.equal(ok.status, 0, ok.stdout + ok.stderr);
  // credits-page: the section count follows the committed score (85 before the credits song's two).
  const sections = Object.values(JSON.parse(await readFile(web('audio/score/score.json'), 'utf8')).songs)
    .reduce((n, s) => n + Object.keys(s.sections).length, 0);
  assert.match(ok.stdout, new RegExp(`^check: ok {2}${sections} sections, \\d+ B of MIDI, peak (\\d+) voices, 0 failure\\(s\\)$`, 'm'));
  assert.ok(Number(ok.stdout.match(/peak (\d+) voices, 0/)[1]) <= 32);
  assert.match(ok.stdout, /zones drums +\d+ notes +100\.0 % covered/);
  // A broken fixture: an onset 30 ms off the grid, a section that ends half a bar short, a note out of the key.
  const dir = await mkdtemp(join(tmpdir(), 'midi-check-'));
  try {
    const vlq = n => { const b = [n & 127]; while ((n >>= 7)) b.unshift((n & 127) | 128); return b; };
    const track = (events, end) => {
      const body = [];
      let t = 0;
      for (const [tick, bytes] of events) { body.push(...vlq(tick - t), ...bytes); t = tick; }
      body.push(...vlq(end - t), 0xff, 0x2f, 0);
      return [0x4d, 0x54, 0x72, 0x6b, (body.length >> 24) & 255, (body.length >> 16) & 255, (body.length >> 8) & 255, body.length & 255, ...body];
    };
    const name = text => [0xff, 0x03, text.length, ...Buffer.from(text)];
    const ppq = 480, end = 6 * ppq;   // 1.5 bars: not whole
    const offGrid = Math.round(ppq * (1 + .03 / (60 / 120)));   // beat 1 + 30 ms at 120 BPM
    const conductor = track([[0, [0xff, 0x51, 3, 0x07, 0xa1, 0x20]]], end);
    const bass = track([[0, name('bass')], [0, [0x90, 40, 100]], [ppq, [0x80, 40, 0]], [offGrid, [0x90, 41, 100]], [offGrid + ppq, [0x80, 41, 0]]], end);
    const smf = Buffer.from([0x4d, 0x54, 0x68, 0x64, 0, 0, 0, 6, 0, 1, 0, 2, ppq >> 8, ppq & 255, ...conductor, ...bass]);
    await mkdir(join(dir, 't'));
    await writeFile(join(dir, 't', 'A.mid'), smf);
    await writeFile(join(dir, 'score.json'), JSON.stringify({ tracks: { bass: { channel: 0, role: 'bass' } },
      songs: { t: { barSamples: 96000, tonic: 4, mode: 'minor', key: 'E minor', sections: { A: { file: 't/A.mid', bars: 2, hold: 0, bytes: smf.length } } } } }));
    await writeFile(join(dir, 'map.json'), JSON.stringify({ songs: { t: { key: 'E minor', sections: { A: {} } } } }));
    const bad = lua(['tools/midi_stats.lua', 'check', '--score', dir, '--map', join(dir, 'map.json'), '--bank', join(dir, 'none.json')]);
    assert.equal(bad.status, 1, bad.stdout + bad.stderr);
    assert.match(bad.stdout, /FAIL t\/A: ends at beat 6\.000, not on its 2 whole bars/);
    assert.match(bad.stdout, /FAIL t\/A: bass onset at beat 1\.06\d* is 30\.\d ms off the grid/);
    assert.match(bad.stdout, /FAIL t\/A: 50\.0 % of the notes are out of E minor/);
    assert.match(bad.stdout, /^check: FAILED/m);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('8.5 the bank builder on a synthetic fixture: verify, cut, f0, encode, bank.json; refuse a mismatch', { skip: !tools && 'needs lua, ffmpeg and git' }, async () => {
  const dir = await mkdtemp(join(tmpdir(), 'bank-build-'));
  try {
    const src = join(dir, 'src', 'fixture', 'tones'), out = join(dir, 'out');
    await mkdir(src, { recursive: true });
    // Three tones: A3 named right; "A4" that sounds A3 (an octave the f0 check corrects); a stereo hit.
    const tone = (file, hz, seconds, channels = 1) => execFileSync('ffmpeg', ['-v', 'error', '-y', '-f', 'lavfi', '-i',
      `sine=frequency=${hz}:sample_rate=44100:duration=${seconds}`, '-af', 'adelay=40:all=1,volume=0.5', '-ac', String(channels), '-c:a', 'pcm_s16le', join(src, file)]);
    tone('tone_A3_rr1.wav', 220, 1.2);
    tone('oct_A4_rr1.wav', 220, 1.2);
    tone('hit_vl1_rr1.wav', 1000, .3, 2);
    const blob = file => execFileSync('git', ['hash-object', '--no-filters', join(src, file)], { encoding: 'utf8' }).trim();
    const row = async (group, file) => ['fixture/tones', '0'.repeat(40), group, file, (await stat(join(src, file))).size, blob(file), ''].join('\t');
    await writeFile(join(dir, 'manifest.tsv'), ['repo\tcommit\tgroup\tpath\tbytes\tgit_blob_sha1\traw_url',
      await row('tone', 'tone_A3_rr1.wav'), await row('oct', 'oct_A4_rr1.wav'), await row('hit', 'hit_vl1_rr1.wav')].join('\n') + '\n');
    const recipe = { schema: 'demon-attack.bank-recipe/v1', rate: 48000, kbps: { 1: 64, 2: 96 }, gapSeconds: .05, peakDb: -1, fadeSeconds: .02,
      oggOverhead: .02, budgets: { opusBytes: 200000, decodedDesktop: 2000000, decodedPhone: 1000000 },
      sources: { 'fixture/tones': { spdx: 'CC0-1.0', licenceBlob: '0'.repeat(40), credit: 'test tones' } },
      roles: { bass: { level: .7 }, organ: { level: .3 }, drums: { level: 1, cover: 'full' } },
      instruments: [
        { id: 'hit', groups: ['hit'], roles: ['drums'], keys: [36], art: 'hit', parse: { layer: '_(vl%d+)_rr', rr: '_rr(%d+)' }, layers: { vl1: [1, 127] }, top: 'vl1', trim: .2, channels: 2, tier: 1 },
        { id: 'tone', groups: ['tone'], roles: ['bass'], art: 'sus', parse: { note: '_(%u#?%d)_rr', rr: '_rr(%d+)' }, root: 'name', names: 'scientific', verify: 'strict', trim: .8, channels: 1, tier: 1 },
        { id: 'oct', groups: ['oct'], roles: ['organ'], art: 'sus', parse: { note: '_(%u#?%d)_rr' }, root: 'name', names: 'scientific', verify: 'strict', trim: 1, channels: 1, tier: 2,
          loop: { start: .5, xfade: .2 }, phone: false } ] };
    await writeFile(join(dir, 'recipe.json'), JSON.stringify(recipe));
    const args = ['tools/bank/bank_build.lua', '--recipe', join(dir, 'recipe.json'), '--manifest', join(dir, 'manifest.tsv'), '--keys', 'none',
      '--src', join(dir, 'src'), '--out', out, '--tmp', join(dir, 'tmp')];
    // Dry run: the plan and its estimate, from the manifest alone.
    const dry = lua([...args, '--dry-run', '--json']);
    assert.equal(dry.status, 0, dry.stderr);
    const planned = JSON.parse(dry.stdout);
    assert.deepEqual(planned.zones.map(z => [z.inst, z.root ?? z.keys[0], z.sprite]), [['hit', 36, 'bank-1ps.ogg'], ['tone', 57, 'bank-1pm.ogg'], ['oct', 69, 'bank-2dm.ogg']]);
    assert.equal(planned.totals.decodedDesktop, (Math.round(.25 * 48000) * 2 + Math.round(.85 * 48000) + Math.round(1.05 * 48000)) * 4);
    // Build.
    const built = lua(args);
    assert.equal(built.status, 0, built.stderr);
    assert.match(built.stderr, /oct: f0 puts every zone -12 semitones from its planned root; corrected/);
    const bank = JSON.parse(await readFile(join(out, 'bank.json'), 'utf8'));
    assert.equal(bank.schema, 'demon-attack.bank/v1');
    const byInst = Object.fromEntries(bank.zones.map(z => [z.inst, z]));
    assert.equal(byInst.tone.root, 57);
    assert.equal(byInst.oct.root, 57, 'the octave was corrected by f0');
    assert.ok(Math.abs(byInst.tone.f0 - 220) < 2, `f0 ${byInst.tone.f0}`);
    assert.ok(byInst.tone.length > .75 && byInst.tone.length <= .8 + 1e-9, `trimmed to the recipe: ${byInst.tone.length}`);
    assert.deepEqual(byInst.oct.loop, [.5, byInst.oct.length]);
    assert.equal(byInst.hit.source.repo, 'fixture/tones');
    assert.equal(bank.sources['fixture/tones'].spdx, 'CC0-1.0');
    for (const s of bank.sprites) {
      const bytes = await readFile(join(out, s.file));
      assert.equal(bytes.length, s.bytes, s.file);
      assert.equal(createHash('sha256').update(bytes).digest('hex'), s.sha256);
      assert.equal(String(bytes.subarray(0, 4)), 'OggS');
    }
    for (const z of bank.zones) assert.match(z.source.sha256, /^[0-9a-f]{64}$/);
    // The tone's zone in its sprite: the decoded audio is loud inside the zone and silent in the gap after it.
    const pcm = new Float32Array(execFileSync('ffmpeg', ['-v', 'error', '-i', join(out, byInst.tone.sprite), '-f', 'f32le', '-ac', '1', '-ar', '48000', '-'], { maxBuffer: 1 << 24 }).buffer.slice(0));
    const rms = (a, b) => { let s = 0; for (let i = Math.round(a * 48000); i < Math.round(b * 48000); i++) s += pcm[i] * pcm[i]; return Math.sqrt(s / ((b - a) * 48000)); };
    assert.ok(rms(byInst.tone.offset + .1, byInst.tone.offset + .6) > .3, 'normalised near -1 dBFS');
    assert.ok(rms(byInst.tone.offset + byInst.tone.length + .01, byInst.tone.offset + byInst.tone.length + .04) < .01, 'the gap is silent');
    // Same sources, same bytes.
    const again = lua([...args, '--out', join(dir, 'again')]);
    assert.equal(again.status, 0, again.stderr);
    for (const s of bank.sprites) assert.deepEqual(await readFile(join(dir, 'again', s.file)), await readFile(join(out, s.file)), s.file);
    // A source that is not the pinned blob is refused, and nothing is written.
    await appendFile(join(src, 'tone_A3_rr1.wav'), Buffer.from([0]));
    const refused = lua([...args, '--out', join(dir, 'refused')]);
    assert.equal(refused.status, 1);
    assert.match(refused.stderr, /refused: 1 source\(s\) do not match the pins/);
    await assert.rejects(stat(join(dir, 'refused', 'bank.json')));
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('8.5 a strict f0 check refuses a tone that is not the named note', { skip: !tools && 'needs lua, ffmpeg and git' }, async () => {
  const dir = await mkdtemp(join(tmpdir(), 'bank-f0-'));
  try {
    const src = join(dir, 'src', 'fixture', 'tones');
    await mkdir(src, { recursive: true });
    execFileSync('ffmpeg', ['-v', 'error', '-y', '-f', 'lavfi', '-i', 'sine=frequency=220:sample_rate=48000:duration=1', '-c:a', 'pcm_s16le', join(src, 'tone_C4_rr1.wav')]);
    const size = (await stat(join(src, 'tone_C4_rr1.wav'))).size;
    const blob = execFileSync('git', ['hash-object', '--no-filters', join(src, 'tone_C4_rr1.wav')], { encoding: 'utf8' }).trim();
    await writeFile(join(dir, 'm.tsv'), `repo\tcommit\tgroup\tpath\tbytes\tgit_blob_sha1\traw_url\nfixture/tones\t${'0'.repeat(40)}\ttone\ttone_C4_rr1.wav\t${size}\t${blob}\t\n`);
    await writeFile(join(dir, 'r.json'), JSON.stringify({ rate: 48000, kbps: { 1: 64 }, gapSeconds: .05, peakDb: -1, fadeSeconds: .02, oggOverhead: .02,
      budgets: { opusBytes: 1e6, decodedDesktop: 1e7, decodedPhone: 1e7 }, sources: {}, roles: { bass: {} },
      instruments: [{ id: 'tone', groups: ['tone'], roles: ['bass'], art: 'sus', parse: { note: '_(%u#?%d)_rr' }, root: 'name', verify: 'strict', trim: .8, channels: 1, tier: 1 }] }));
    const r = lua(['tools/bank/bank_build.lua', '--recipe', join(dir, 'r.json'), '--manifest', join(dir, 'm.tsv'), '--keys', 'none', '--src', join(dir, 'src'),
      '--out', join(dir, 'out'), '--tmp', join(dir, 'tmp')]);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /tone tone_C4_rr1\.wav: f0 220\.\d Hz is -3\.00 semitones off root 60/);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

// --- 8.12 the sampler on a mocked audio clock -----------------------------------------------------------------
function mockAudio({ decode = 'now' } = {}) {
  const started = [];
  const param = (value = 0) => ({ value, events: [], cancelScheduledValues() {}, setValueAtTime(v, t) { this.events.push(['set', v, t]); },
    linearRampToValueAtTime(v) { this.value = v; }, exponentialRampToValueAtTime() {}, setTargetAtTime(v, t, c) { this.events.push(['target', v, t, c]); } });
  const audioNode = extra => ({ connect(to) { this.to = to; }, disconnect() {}, ...extra });
  class AudioContext {
    constructor() { this.currentTime = 0; this.state = 'suspended'; this.sampleRate = 48000; this.destination = {}; AudioContext.last = this; }
    createGain() { return audioNode({ gain: param(1) }); }
    createOscillator() { const o = audioNode({ kind: 'osc', type: 'sine', frequency: param(440), detune: param(0), start(at) { o.at = at; started.push(o); }, stop(at) { o.stoppedAt = at; } }); return o; }
    createBufferSource() {
      const s = audioNode({ kind: 'buffer', playbackRate: param(1), loop: false, loopStart: 0, loopEnd: 0,
        start(at, offset, duration) { s.at = at; s.offset = offset; s.duration = duration; started.push(s); }, stop(at) { s.stoppedAt = at; } });
      return s;
    }
    createBiquadFilter() { return audioNode({ type: 'lowpass', frequency: param(350), Q: param(1), gain: param(0) }); }
    createWaveShaper() { return audioNode({ curve: null, oversample: 'none' }); }
    createConvolver() { return audioNode({ buffer: null }); }
    createStereoPanner() { return audioNode({ pan: param(0) }); }
    createDelay() { return audioNode({ delayTime: param(0) }); }
    createDynamicsCompressor() { return audioNode({ threshold: param(), knee: param(), ratio: param(), attack: param(), release: param() }); }
    createBuffer(channels, length) { const data = Array.from({ length: channels }, () => new Float32Array(length)); return { length, numberOfChannels: channels, getChannelData: c => data[c] }; }
    decodeAudioData(bytes) {
      const { file, frames, channels } = JSON.parse(new TextDecoder().decode(bytes));
      const buffer = { file, length: frames, numberOfChannels: channels, sampleRate: 48000, duration: frames / 48000 };
      return decode === 'never' ? new Promise(() => {}) : Promise.resolve(buffer);
    }
    async resume() { this.state = 'running'; }
    async suspend() { this.state = 'suspended'; }
  }
  return { AudioContext, started };
}
// A bank.json from the recipe's plan: each zone at its planned trim, packed as the builder packs it.
function bankFromPlan(p) {
  const zones = [], sprites = [];
  for (const s of p.sprites) {
    let cursor = 0;
    for (const i of s.zones) {
      const z = p.zones[i - 1];   // the plan's indexes are Lua's (1-based)
      zones.push({ ...z, offset: cursor, length: z.trim, loop: z.loop ? [z.loop.start, z.trim] : undefined });
      cursor += z.trim + .05;
    }
    sprites.push({ file: s.file, tier: s.tier, phone: s.phone, channels: s.channels, seconds: cursor, decodedBytes: Math.round(cursor * 48000) * 4 * s.channels });
  }
  return { schema: 'demon-attack.bank/v1', budgets: { decodedDesktop: 41e6, decodedPhone: 16e6 }, roles: p.roles, instruments: p.instruments, sprites, zones };
}
// search: the page's query (the bank is off by default: these tests switch it on with ?bank=1 unless they say
// otherwise); stored: localStorage's contents (the /console choice).
async function player({ bank = null, decode = 'now', phone = false, search = '?bank=1', stored = {} } = {}) {
  let tick;
  const { AudioContext, started } = mockAudio({ decode });
  const fetched = [];
  const sandbox = { URL, Uint8Array, DataView, Float32Array, Map, Set, Math, Object, Promise, TextDecoder, TextEncoder, JSON, Array, Number, String,
    location: { search }, navigator: { deviceMemory: phone ? 2 : 8 },
    window: { AudioContext, addEventListener() {}, matchMedia: () => ({ matches: false }),
      localStorage: { getItem: k => stored[k] ?? null, setItem: (k, v) => { stored[k] = String(v); } } },
    document: { baseURI: 'https://game.test/', addEventListener() {} },
    setInterval(fn) { tick = fn; },
    async fetch(url) {
      fetched.push(url.pathname);
      if (url.pathname.startsWith('/audio/bank/')) {
        if (!bank) return { ok: false };
        const name = url.pathname.slice('/audio/bank/'.length);
        if (name === 'bank.json') return { ok: true, async json() { return JSON.parse(JSON.stringify(bank)); } };
        const sprite = bank.sprites.find(s => s.file === name);
        const bytes = new TextEncoder().encode(JSON.stringify({ file: name, frames: Math.round(sprite.seconds * 48000), channels: sprite.channels }));
        return { ok: true, async arrayBuffer() { return bytes.buffer; } };
      }
      const bytes = await readFile(web(url.pathname.slice(1)));
      const buffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
      return { ok: true, async arrayBuffer() { return buffer; }, async json() { return JSON.parse(new TextDecoder().decode(bytes)); } };
    } };
  sandbox.window.location = sandbox.location; sandbox.window.navigator = sandbox.navigator;
  vm.createContext(sandbox);
  vm.runInContext(await readFile(web('audio/demon-score.js'), 'utf8'), sandbox);
  vm.runInContext(await readFile(web('audio/demon-audio.js'), 'utf8'), sandbox);
  const audio = sandbox.window.demonAudio;
  const settle = async () => { for (let i = 0; i < 60; i++) await new Promise(resolve => setImmediate(resolve)); };
  const ctx = () => AudioContext.last;
  await audio.scoreLoading;
  await audio.unlock();
  if (decode !== 'never') await audio.bankLoading;
  await settle();
  const run = async seconds => { const steps = Math.round(seconds / .025); for (let i = 0; i < steps; i++) { ctx().currentTime += .025; tick(); } await settle(); };
  return { audio, run, started, fetched, ctx, stored, settle };
}
// Krybor's B at tier 4 with the power layer: every band track sounds.
async function playKrybor(p, seconds = 8) {
  p.audio.song({ song: 'k', section: 'B', at: -1, quantum: 'bar', enter: 'start', tier: 4 });
  p.audio.powerLayer(2, true);
  await p.run(seconds);
}
const shape = started => started.map(s => [s.kind, s.type || null, +s.at.toFixed(6), s.frequency ? +s.frequency.value.toFixed(3) : null]);

test('8.12 no bank: the synth path is untouched (only bank.json is asked for), and a bank still decoding plays the same synth notes', { skip: !tools && 'needs lua' }, async () => {
  const none = await player();
  await playKrybor(none);
  assert.deepEqual(none.fetched.filter(f => f.startsWith('/audio/bank/')), ['/audio/bank/bank.json']);
  assert.ok(none.started.length > 500 && none.started.every(s => s.kind === 'osc' || !s.offset), 'oscillators and noise only');
  const state = none.audio.state.score;
  assert.equal(state.bank.present, false);
  assert.equal(state.bankLoaded, false);
  assert.equal(state.bankDecodedBytes, 0);
  // A bank whose sprites never finish decoding: every note falls back to the synth voice, note for note the same.
  const pending = await player({ bank: bankFromPlan(plan()), decode: 'never' });
  await playKrybor(pending);
  assert.deepEqual(shape(pending.started), shape(none.started));
  const ps = pending.audio.state.score.bank;
  assert.equal(ps.present, true);
  assert.equal(ps.sampled, 0);
  assert.ok(ps.synth > 100, `${ps.synth} notes waited for their zone`);
});

test('8.12 the bank switch: off by default (nothing under audio/bank/ is fetched), ?bank=1|0 per load, the stored /console choice, switched on live', { skip: !tools && 'needs lua' }, async () => {
  const bank = bankFromPlan(plan());
  const ref = await player({ search: '' });
  await playKrybor(ref);
  // Off by default even with a bank on the server: not even bank.json is asked for, and the synth plays as before.
  const off = await player({ bank, search: '' });
  await playKrybor(off);
  assert.deepEqual(off.fetched.filter(f => f.startsWith('/audio/bank/')), []);
  assert.deepEqual(shape(off.started), shape(ref.started));
  assert.equal(off.audio.scoreBank, false);
  assert.equal(off.audio.state.score.bank.enabled, false);
  assert.equal(off.audio.state.score.bank.present, false);
  // The stored choice turns it on; ?bank=0 overrides the stored choice for one load.
  const stored = await player({ bank, search: '', stored: { 'demonAttack.scoreBank': 'on' } });
  assert.equal(stored.audio.scoreBank, true);
  assert.equal(stored.audio.state.score.bankLoaded, true);
  const vetoed = await player({ bank, search: '?bank=0', stored: { 'demonAttack.scoreBank': 'on' } });
  assert.equal(vetoed.audio.scoreBank, false);
  assert.deepEqual(vetoed.fetched.filter(f => f.startsWith('/audio/bank/')), []);
  // Switched on live (the /console toggle): stored, loaded, sampled from the next notes; off again: synth only.
  assert.equal(off.audio.setScoreBank(true), true);
  assert.equal(off.stored['demonAttack.scoreBank'], 'on');
  await off.audio.bankLoading;
  await off.settle();
  assert.equal(off.audio.state.score.bankLoaded, true);
  await off.run(4);
  const sampled = off.audio.state.score.bank.sampled;
  assert.ok(sampled > 20, `${sampled} notes sampled after the switch`);
  assert.equal(off.audio.setScoreBank(false), false);
  assert.equal(off.stored['demonAttack.scoreBank'], 'off');
  await off.run(4);
  assert.equal(off.audio.state.score.bank.sampled, sampled, 'no sampled notes once switched off');
});

test('8.12 a decoded bank: zones by key and velocity, playbackRate from the root, power chords, round robins, the cap', { skip: !tools && 'needs lua' }, async () => {
  const bank = bankFromPlan(plan());
  const p = await player({ bank });
  const state0 = p.audio.state.score;
  assert.equal(state0.bankLoaded, true);
  assert.equal(state0.bank.loaded, bank.sprites.length);
  assert.equal(state0.bankDecodedBytes, bank.sprites.reduce((n, s) => n + Math.round(s.seconds * 48000) * 4 * s.channels, 0));
  assert.ok(state0.bankDecodedBytes <= 41e6);
  await playKrybor(p);
  const sampled = p.started.filter(s => s.kind === 'buffer' && s.buffer?.file);
  assert.ok(sampled.length > 200, `${sampled.length} sampled sources`);
  const zoneAt = s => bank.zones.find(z => z.sprite === s.buffer.file && Math.abs(z.offset - s.offset) < 1e-9);
  const roles = new Set();
  for (const s of sampled) {
    const z = zoneAt(s);
    assert.ok(z, `a source starts on a zone (${s.buffer.file} @ ${s.offset})`);
    for (const r of z.roles) roles.add(r);
    if (z.keys) assert.equal(s.playbackRate.value, 1, 'drums play at their own pitch');
    else {
      const semis = 12 * Math.log2(s.playbackRate.value);
      assert.ok(Math.abs(semis - Math.round(semis)) < .1, 'a pitched zone moves by whole semitones (plus the double\'s cents)');
      assert.ok(Math.abs(semis) <= 7.1, `within the zone's stretch: ${semis.toFixed(2)}`);
    }
    if (!s.loop) assert.ok(s.duration <= z.length + 1e-9, 'never past its zone');
  }
  for (const role of ['drums', 'bass', 'guitarL', 'guitarR']) assert.ok(roles.has(role), `${role} plays samples`);
  // Round robins: the snare's top layer alternates between its takes.
  const snares = sampled.filter(s => zoneAt(s).inst === 'snare').map(s => zoneAt(s).rr);
  assert.ok(new Set(snares).size > 1, `snare round robins ${[...new Set(snares)]}`);
  // A guitar note is a power chord of samples: the left double root + fifth, the right root + fifth + octave.
  const groups = new Map();
  for (const s of sampled) { const z = zoneAt(s); if (z.roles.includes('guitarL')) { const k = `${s.at}`; groups.set(k, (groups.get(k) || 0) + 1); } }
  assert.ok([...groups.values()].includes(5), 'at a guitar onset: 2 sources left + 3 right');
  const state = p.audio.state.score;
  assert.ok(state.bank.sampled > 100);
  assert.ok(state.voices <= state.cap && state.cap === 48);
});

test('8.12 phones: only the phone tier loads (within 16 MB decoded), and the cap is 32', { skip: !tools && 'needs lua' }, async () => {
  const bank = bankFromPlan(plan());
  const p = await player({ bank, phone: true });
  const phoneFiles = bank.sprites.filter(s => s.phone).map(s => `/audio/bank/${s.file}`);
  assert.deepEqual(p.fetched.filter(f => f.startsWith('/audio/bank/') && f !== '/audio/bank/bank.json'), phoneFiles);
  const state = p.audio.state.score;
  assert.equal(state.bank.tier, 'phone');
  assert.ok(state.bankDecodedBytes <= 16e6, `${state.bankDecodedBytes}`);
  p.audio.song({ song: 'c5', section: 'H4', at: -1, quantum: 'bar', enter: 'start', tier: 4, variant: 'v2', fleet: true });
  p.audio.powerLayer(2, true);
  let peak = 0;
  for (let i = 0; i < 40; i++) { await p.run(.5); peak = Math.max(peak, p.audio.state.score.voices); }
  assert.equal(p.audio.state.score.cap, 32);
  assert.ok(peak <= 32, `peak ${peak}`);
  // Desktop-only zones (bells, the high guitar) are not in the phone's map: those tracks stay synthesized.
  assert.ok(p.started.some(s => s.kind === 'buffer' && s.buffer?.file));
});
