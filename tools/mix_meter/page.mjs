// The shipped audio players (web/audio/demon-score.js, demon-audio.js, comms-audio.js) loaded into one offline
// context, as index.html loads them: page({ music, speech }) -> { audio, comms, context, render(seconds, at) }.
import { readFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import vm from 'node:vm';
import { OfflineContext, QUANTUM } from './offline-audio.mjs';

export const web = path => new URL(`../../web/${path}`, import.meta.url);

function decodeClip(path, channels = 1) {
  const pcm = execFileSync('ffmpeg', ['-v', 'error', '-i', path, '-f', 'f32le', '-ac', String(channels), '-ar', '48000', '-'], { maxBuffer: 1 << 28 });
  const bytes = new Uint8Array(4 + pcm.length);
  bytes.set([0x46, 0x33, 0x32, channels === 2 ? 0x53 : 0x4d]); bytes.set(pcm, 4);
  return bytes.buffer;
}
// The sample bank's sprites (web/audio/bank/bank-<tier><p|d><m|s>.ogg, and the brood choir's choir-…ogg): decoded with their channel count, once per
// process (decodeAudioData copies, so pages can share the bytes).
const bankSprite = path => path.match(/^audio\/bank\/(?:bank|choir)-\w+?([ms])\.ogg$/);
const spriteCache = new Map();
function decodeSprite(path, channels) {
  if (!spriteCache.has(path)) spriteCache.set(path, decodeClip(path, channels));
  return spriteCache.get(path);
}

// One page: a fresh context with the three players loaded, the stored levels set.
// clip(id): optional clip bytes ('F32M' + float32 PCM, see OfflineContext.decodeAudioData) instead of decoding the shipped Ogg.
// trims: false loads the score without web/audio/score/mix-trim.json (how trim.mjs measures the untrimmed score).
// bank: true switches the score's sample bank on (the stored /console choice; off by default, as in the game).
export async function page(levels = { music: 'full', speech: 'full' }, { clip = null, trims = true, bank = false } = {}) {
  let timer = null, context = null;
  class AudioContext extends OfflineContext { constructor() { super({ sampleRate: 48000 }); context = this; } }
  const store = { 'demonAttack.musicVolume': levels.music, 'demonAttack.speechVolume': levels.speech, 'demonAttack.scoreBank': bank ? 'on' : 'off' };
  const window = { AudioContext, addEventListener() {}, matchMedia: () => ({ matches: false }),
    localStorage: { getItem: k => store[k] ?? null, setItem: (k, v) => { store[k] = v; } } };
  const sandbox = { URL, Uint8Array, DataView, Float32Array, Map, Set, Math, Object, Promise, TextDecoder, TextEncoder, JSON, Array, Number, String, Error,
    encodeURIComponent, decodeURIComponent, console, location: { search: '' }, navigator: { deviceMemory: 8 }, window,
    document: { baseURI: 'https://game.test/', addEventListener() {}, hidden: false },
    setInterval(fn) { timer = fn; return 1; }, clearInterval() {}, setTimeout(fn) { return 0; }, clearTimeout() {},
    async fetch(url) {
      const path = decodeURIComponent(url.pathname.slice(1));
      try {
        if (!trims && path === 'audio/score/mix-trim.json') return { ok: false };
        const id = path.match(/^audio\/comms\/(.+)\.ogg$/)?.[1], sprite = bankSprite(path);
        const bytes = id ? (clip ? clip(id) : decodeClip(web(path).pathname))
          : sprite ? decodeSprite(web(path).pathname, sprite[1] === 's' ? 2 : 1) : (await readFile(web(path))).buffer;
        if (!bytes) return { ok: false };
        return { ok: true, async arrayBuffer() { return bytes; }, async json() { return JSON.parse(new TextDecoder().decode(bytes)); } };
      } catch { return { ok: false }; }
    } };
  sandbox.window.window = window;
  vm.createContext(sandbox);
  for (const file of ['demon-score.js', 'demon-audio.js', 'comms-audio.js']) {
    vm.runInContext(await readFile(web(`audio/${file}`), 'utf8'), sandbox, { filename: file });
    for (const key of ['demonScore', 'demonAudio', 'commsAudio']) if (window[key]) sandbox[key] = window[key];
  }
  const audio = window.demonAudio;
  await audio.unlock();
  await audio.scoreLoading;
  await audio.bankLoading;   // the sample bank, when it is on and web/audio/bank/bank.json exists (else at once)
  // render(seconds, at(t)): runs the 25 ms scheduler on the audio clock; at(t) is called on every tick.
  async function render(seconds, at = () => {}) {
    const frames = Math.round(seconds * 48000 / QUANTUM) * QUANTUM, L = new Float32Array(frames), R = new Float32Array(frames);
    const tickEvery = Math.round(.025 * 48000 / QUANTUM);
    for (let f = 0, b = 0; f < frames; f += QUANTUM, b++) {
      if (b % tickEvery === 0) { await at(context.currentTime); timer?.(); await new Promise(r => setImmediate(r)); }
      context.renderQuantum(L, R, f);
    }
    return { L, R };
  }
  return { window, audio, comms: window.commsAudio, get context() { return context; }, render };
}

