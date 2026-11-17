// The MIDI-first score (adaptive-soundtrack tasks 4.3, 8.13) and its section-graph player (tasks 4.1, 8.12):
// web/audio/score/ as tools/score/score_gen.lua writes it, played by web/audio/demon-score.js inside
// demon-audio.js's scheduler on a mocked audio clock.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import vm from 'node:vm';

const web = path => new URL(`../web/${path}`, import.meta.url);
const manifest = JSON.parse(await readFile(web('audio/score/score.json'), 'utf8'));

// A Web Audio mock that records every source start (time, frequency) and every gain automation.
function mockAudio() {
  const started = [];
  const param = (value = 0) => ({ value, events: [], cancelScheduledValues(t) { this.events.push(['cancel', t]); },
    setValueAtTime(v, t) { this.events.push(['set', v, t]); }, linearRampToValueAtTime(v, t) { this.events.push(['ramp', v, t]); this.value = v; },
    exponentialRampToValueAtTime(v, t) { this.events.push(['exp', v, t]); }, setTargetAtTime(v, t, c) { this.events.push(['target', v, t, c]); } });
  const audioNode = extra => ({ connect(to) { this.to = to; }, disconnect() {}, ...extra });
  class AudioContext {
    constructor() { this.currentTime = 0; this.state = 'suspended'; this.sampleRate = 48000; this.destination = {}; AudioContext.last = this; }
    createGain() { return audioNode({ gain: param(1) }); }
    createOscillator() {
      const o = audioNode({ type: 'sine', frequency: param(440), detune: param(0),
        start(at) { o.at = at; started.push(o); }, stop(at) { o.stoppedAt = Math.min(o.stoppedAt ?? Infinity, at); } });
      return o;
    }
    createBufferSource() {
      const s = audioNode({ playbackRate: param(1), start(at, offset, duration) { s.at = at; s.offset = offset; s.duration = duration; started.push(s); }, stop(at) { s.stoppedAt = Math.min(s.stoppedAt ?? Infinity, at); } });
      return s;
    }
    createBiquadFilter() { return audioNode({ type: 'lowpass', frequency: param(350), Q: param(1), gain: param(0) }); }
    createWaveShaper() { return audioNode({ curve: null, oversample: 'none' }); }
    createConvolver() { return audioNode({ buffer: null }); }
    createStereoPanner() { return audioNode({ pan: param(0) }); }
    createDelay() { return audioNode({ delayTime: param(0) }); }
    createDynamicsCompressor() { return audioNode({ threshold: param(), knee: param(), ratio: param(), attack: param(), release: param() }); }
    createBuffer(channels, length) { const data = Array.from({ length: channels }, () => new Float32Array(length)); return { length, numberOfChannels: channels, getChannelData: c => data[c] }; }
    decodeAudioData(bytes) { return Promise.resolve({ duration: 12, length: 12 * 48000, numberOfChannels: 2, name: new TextDecoder().decode(new Uint8Array(bytes)) }); }
    async resume() { this.state = 'running'; }
    async suspend() { this.state = 'suspended'; }
  }
  return { AudioContext, started };
}

async function player({ search = '', recorded = true } = {}) {
  let tick;
  const { AudioContext, started } = mockAudio();
  const fetched = [];
  const sandbox = { URL, Uint8Array, DataView, Float32Array, Map, Set, Math, Object, Promise, TextDecoder, TextEncoder, JSON, Array, Number, String,
    location: { search }, navigator: { deviceMemory: 8 },
    window: { AudioContext, addEventListener() {}, matchMedia: () => ({ matches: false }) },
    document: { baseURI: 'https://game.test/', addEventListener() {} },
    setInterval(fn) { tick = fn; },
    async fetch(url) {
      fetched.push(url.pathname);
      const music = url.pathname.match(/^\/audio\/music\/(.+)\.(ogg|m4a)$/);
      if (music) {
        if (!recorded) return { ok: false };
        const bytes = new TextEncoder().encode(music[1]);
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
  // Advance the audio clock in 25 ms timer ticks (the real scheduler's period).
  await audio.scoreLoading;
  const run = async seconds => { const steps = Math.round(seconds / .025); for (let i = 0; i < steps; i++) { ctx().currentTime += .025; tick(); } await settle(); };
  await settle();
  return { audio, ctx, run, settle, started, fetched };
}
const bar = song => manifest.songs[song].barSamples / 48000;
const onLine = (t, origin, unit) => Math.abs((t - origin) / unit - Math.round((t - origin) / unit)) < 1e-6;
const plain = x => JSON.parse(JSON.stringify(x));
const moves = audio => plain(audio.state.score.moves.filter(m => m.section));

test('the score: every section is whole bars of its grid, parses, and its masks, layers and stingers name real tracks', async () => {
  let bytes = 0;
  for (const [id, song] of Object.entries(manifest.songs)) {
    for (const [sid, section] of Object.entries(song.sections)) {
      const file = web(`audio/score/${section.file}`);
      const size = (await stat(file)).size;
      assert.equal(size, section.bytes, `${id}/${sid} size matches the manifest`);
      bytes += size;
      const data = new Uint8Array(await readFile(file));
      assert.equal(String.fromCharCode(...data.slice(0, 4)), 'MThd');
      assert.equal((data[8] << 8) | data[9], 1, 'SMF type 1');
      for (const name of section.tracks) assert.ok(manifest.tracks[name], `${id}/${sid}: track ${name} is in the map`);
      if (section.next) assert.ok(song.sections[section.next], `${id}/${sid}: next ${section.next} exists`);
      assert.ok(['loop', 'tail', 'bridge'].includes(section.kind));
      assert.ok(Number.isInteger(section.bars) && section.bars > 0);
    }
    const masks = song.masks || manifest.masks;
    for (const tier of ['1', '2', '3', '4']) for (const name of masks[tier]) assert.ok(manifest.tracks[name], `${id}: mask ${tier} names ${name}`);
  }
  for (const list of Object.values(manifest.layers)) for (const name of list) assert.ok(manifest.tracks[name]);
  for (const [accent, sting] of Object.entries(manifest.accents)) assert.ok(manifest.stingers[sting], `${accent} -> ${sting}`);
  for (const sting of Object.values(manifest.stingers)) for (const n of sting.notes) assert.ok(manifest.tracks[n.track], `stinger track ${n.track}`);
  assert.ok(bytes < 1024 * 1024, `the whole score stays under the 1 MB budget (${bytes} B)`);
  // The carrier fight graph and the sector song of the brief.
  assert.deepEqual(Object.keys(manifest.songs.c1.sections).sort(), ['H1', 'H2', 'approach', 'arrival', 'collapse', 'core', 'transform', 'victory']);
  assert.deepEqual(Object.keys(manifest.songs.k.sections).sort(), ['A', 'B', 'C', 'D', 'arrival', 'clear']);
});

test('the carrier graph plays on its bar grid: arrival hands over, moves land on bar lines, transform runs into the core', async () => {
  const { audio, ctx, run, started } = await player();
  await audio.unlock();
  await run(.2);
  const menu = audio.state.startedAt;
  assert.equal(audio.state.active, 'menu');
  const first = audio.song({ song: 'c1', section: 'arrival', at: -1, quantum: 'bar', enter: 'start', tier: 2 });
  // From the menu cue (120 BPM, 2 s bars) the score waits for that cue's next bar line.
  assert.ok(onLine(first, menu, 2) && first > menu, `on the menu's bar line: ${first} from ${menu}`);
  const B = bar('c1');
  await run(first - ctx().currentTime + 4 * B + .3);
  let log = moves(audio);
  assert.deepEqual(log.map(m => m.section), ['arrival', 'approach'], 'the arrival hands over to the approach at its end');
  assert.ok(Math.abs(log[1].at - (first + 4 * B)) < 1e-9, 'exactly four bars later');
  // A hatch tier: SongDirector asks for the next bar line.
  const startH1 = log[1].at + 6 * B;
  assert.equal(audio.song({ song: 'c1', section: 'H1', at: startH1, quantum: 'bar', enter: 'start' }), startH1);
  await run(startH1 - ctx().currentTime + .1);
  assert.equal(audio.state.score.section, 'H1');
  // No note of the approach starts at or after the move; notes do start within the first beat of H1 (no gap).
  const beat = B / 4;
  const afterMove = started.filter(s => s.at >= startH1 - 1e-9 && s.at < startH1 + beat);
  assert.ok(afterMove.length > 0, 'H1 sounds on its downbeat');
  assert.ok(started.some(s => s.at < startH1 - 1e-9 && s.at >= startH1 - beat - 1e-9), 'the approach sounds right up to the move');
  // Two quick requests: the later one replaces the pending earlier one.
  const next = startH1 + 2 * B;
  audio.song({ song: 'c1', section: 'H2', at: next, quantum: 'bar', enter: 'start' });
  audio.song({ song: 'c1', section: 'transform', at: next, quantum: 'bar', enter: 'start' });
  await run(next - ctx().currentTime + 3 * B + .2);
  log = moves(audio);
  assert.deepEqual(log.slice(-3).map(m => m.section), ['H1', 'transform', 'core'], 'H2 never plays; the bridge runs into the core');
  assert.ok(Math.abs(log.at(-1).at - (next + 3 * B)) < 1e-9, 'the core lands on the bridge\'s last bar line');
  for (const m of log.slice(1)) assert.ok(onLine(m.at, first, B), `${m.section} starts on a bar line of the song`);
});

test('a same-position move keeps the bar; a beat move lands on a beat; a late request slips to the next line', async () => {
  const { audio, ctx, run } = await player();
  await audio.unlock(); await run(.1);
  const B = bar('c1'), beat = B / 4;
  const t0 = audio.song({ song: 'c1', section: 'H1', at: -1, quantum: 'bar', enter: 'start', tier: 3 });
  await run(t0 - ctx().currentTime + 3 * B + .1);
  const at = t0 + 4 * B;   // bar 5 of H1
  audio.song({ song: 'c1', section: 'H2', at, quantum: 'bar', enter: 'same' });
  await run(at - ctx().currentTime + .1);
  assert.equal(audio.state.score.section, 'H2', JSON.stringify(audio.state.score.moves));
  assert.equal(audio.state.score.entry, 16, 'H2 enters at its own bar 5');
  // Collapse on the next beat.
  const now = ctx().currentTime;
  const collapse = audio.song({ song: 'c1', section: 'collapse', at: -1, quantum: 'beat', enter: 'start' });
  assert.ok(collapse - now <= beat + .3 + 1e-9 && onLine(collapse, at - 16 * beat, beat), 'next beat line');
  await run(collapse - ctx().currentTime + .1);
  assert.equal(audio.state.score.section, 'collapse');
  // A requested time already inside the scheduled window slips to the next bar line.
  const slippedBefore = audio.state.score.slipped;
  const late = audio.song({ song: 'c1', section: 'victory', at: ctx().currentTime + .01, quantum: 'bar', enter: 'start' });
  assert.equal(audio.state.score.slipped, slippedBefore + 1);
  assert.ok(onLine(late, collapse, B), 'on a bar line of the collapse');
});

test('intensity is a track mask on the next bar: tracks join and leave without a restart', async () => {
  const { audio, ctx, run } = await player();
  await audio.unlock(); await run(.1);
  const B = bar('k');
  const t0 = audio.song({ song: 'k', section: 'A', at: -1, quantum: 'bar', enter: 'start', tier: 1 });
  await run(t0 - ctx().currentTime + .5);
  assert.deepEqual(plain(audio.state.score.audible), ['bass', 'clean', 'drums', 'gtrL', 'gtrR']);
  const t3 = t0 + 2 * B;
  audio.song({ tier: 3, at: t3, quantum: 'bar' });
  await run(t3 - ctx().currentTime + .1);
  const audible = audio.state.score.audible;
  for (const name of ['drums2', 'lead2', 'organ', 'lead']) assert.ok(audible.includes(name), `tier 3 adds ${name}`);
  assert.equal(audio.state.score.moves.filter(m => m.section).length, 1, 'no section restart');
  audio.song({ variant: 'v2', fleet: true, at: t3 + B, quantum: 'bar' });
  await run(B);
  assert.ok(audio.state.score.audible.includes('choir') && audio.state.score.audible.includes('fanfare'), 'v2 and fleet layers');
  audio.powerLayer(2, false);
  await run(B + .1);
  assert.equal(audio.state.score.mask.power, 2, 'the power layer joins on a bar line');
});

test('recorded cues and the score hand over on bar lines in both directions; accents become stingers in the key', async () => {
  const { audio, ctx, run, settle, started } = await player();
  await audio.cue('level', 2);
  await audio.unlock(); await run(1);
  assert.equal(audio.state.active, 'l2-intro');
  const intro = audio.state.startedAt;
  const t0 = audio.song({ song: 'k', section: 'arrival', at: -1, quantum: 'bar', enter: 'start' });
  const B2 = 72000 / 48000;
  assert.ok(onLine(t0, intro, B2), 'the score starts on the recorded cue\'s bar line');
  assert.equal(audio.state.active, null, 'the recorded cue yields');
  await run(t0 - ctx().currentTime + 4 * bar('k') + .2);
  assert.equal(audio.state.score.section, 'A');
  // An accent: the dive becomes a fill that leads into the next bar line of A.
  const before = started.length;
  const at = await audio.accent('dive');
  assert.ok(at !== null && onLine(at, t0, bar('k')), 'the fill lands on a bar line');
  assert.ok(started.length > before, 'its notes are scheduled');
  assert.equal(await audio.accent('dive'), null, 'spacing: a second fill waits');
  assert.notEqual(await audio.accent('destroyed'), null, 'life loss plays');
  // Back to recorded music: the next cue waits for the score's bar line.
  await audio.cue('level', 3); await settle();
  const handover = audio.state.startedAt;
  assert.ok(onLine(handover, t0 + 4 * bar('k'), bar('k')), 'the recorded cue starts on the score\'s bar line');
  await run(handover - ctx().currentTime + .2);
  assert.equal(audio.state.score.section, null, 'the score stopped');
  assert.equal(audio.state.active, 'l3-intro');
});

test('with the score off (or missing) a move plays its recorded fallback cue', async () => {
  const { audio, run, fetched } = await player({ search: '?score=off' });
  await audio.unlock(); await run(.2);
  assert.equal(audio.song({ song: 'c1', section: 'arrival', at: -1, quantum: 'bar', enter: 'start', fallback: { mode: 'boss', level: 5, phase: 1, cycle: 0 } }), -2);
  await run(.3);
  assert.ok(fetched.includes('/audio/music/l5-intro.ogg'));
  assert.equal(audio.state.score.section, null);
});

test('scheduling stays bounded: a long fight never exceeds the voice cap and every timer tick is cheap', async () => {
  const { audio, ctx, run } = await player();
  await audio.unlock(); await run(.1);
  const B = bar('c1');
  const t0 = audio.song({ song: 'c1', section: 'core', at: -1, quantum: 'bar', enter: 'start', tier: 4, variant: 'v2' });
  await run(t0 - ctx().currentTime);
  let peak = 0;
  for (let i = 0; i < 40; i++) { await run(B / 2); peak = Math.max(peak, audio.state.score.voices); }
  assert.ok(peak <= audio.state.score.cap, `peak ${peak} voices within the cap`);
  assert.ok(audio.state.score.scheduledUntil <= ctx().currentTime + .25 + 1e-9, 'never schedules further than the lookahead');
});
