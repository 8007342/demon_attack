#!/usr/bin/env python3
"""Reproducible ACE-Step 1.5 music pipeline for web/audio/music/.

Stages (all deterministic for a given set of candidate FLACs):

  jobs      print one studio.run_workflow request per (cue, seed) from
            art/workflows/music/cues.json (workflow path + overrides).
  generate  optional direct mode: POST the same requests to a ComfyUI server
            (--comfy http://studio:8188) and download the FLACs. Inside a
            Tillandsias forge prefer the studio.run_workflow tool, which shares
            the host GPU queue, then `ingest` its outputs.
  ingest    copy studio outputs into the candidate folder as <cue>-s<seed>.flac
            (reads a JSON list of {"cue","seed","path"}).
  analyze   tempo / beat-grid / downbeat / loop-seam analysis of every
            candidate; writes <work>/analysis.json.
  build     pick the best candidate per cue (or the `pick` seed pinned in the
            spec), correct tempo to exactly 120 BPM, cut an exact bar multiple
            on a downbeat, build the loop seam (continuation crossfade, so the
            wrap is sample-continuous), loudness-normalise, encode Opus/OGG and
            AAC/M4A, and write web/audio/music/manifest.json.
  verify    decode the encoded files again and check lengths, the loop wrap
            discontinuity, clicks and clipping.

Requires python3 with numpy + scipy, and ffmpeg (libopus, aac).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import struct
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / 'art/workflows/music/cues.json'
OUT = ROOT / 'web/audio/music'
SR = 48000
HOP = 480  # 10 ms analysis frames at 48 kHz


# ---------------------------------------------------------------- spec / jobs
def load_spec():
    return json.loads(SPEC.read_text())


def cue_by_name(spec, name):
    for cue in spec['cues']:
        if cue['name'] == name:
            return cue
    raise SystemExit(f'unknown cue {name}')


def overrides(spec, cue, seed):
    n = spec['nodes']
    tags = f"{cue['tags']}, {spec['common_tags']}"
    if cue['kind'] != 'loop':
        tags = tags.replace(', seamless loop', ', short cue with a clear ending')
    return {
        'seed': seed,
        f"$node:{n['text_seed']}": seed,
        f"$node:{n['tags']}": tags,
        f"$node:{n['lyrics']}": spec['lyrics'],
        f"$node:{n['bpm']}": spec['bpm'],
        f"$node:{n['duration']}": float(cue['gen_seconds']),
        f"$node:{n['seconds']}": float(cue['gen_seconds']),
        f"$node:{n['keyscale']}": cue['keyscale'],
    }


def cmd_jobs(args):
    spec = load_spec()
    for cue in spec['cues']:
        if args.cue and cue['name'] not in args.cue:
            continue
        for seed in cue['seeds']:
            print(json.dumps({'cue': cue['name'], 'seed': seed, 'workflow': spec['workflow'], 'overrides': overrides(spec, cue, seed)}))


def cmd_generate(args):
    """Direct ComfyUI mode (outside the forge's studio tool)."""
    spec = load_spec()
    graph0 = json.loads((ROOT / spec['workflow']).read_text())
    work = Path(args.work); work.mkdir(parents=True, exist_ok=True)
    for cue in spec['cues']:
        if args.cue and cue['name'] not in args.cue:
            continue
        for seed in cue['seeds']:
            target = work / f"{cue['name']}-s{seed}.flac"
            if target.exists():
                continue
            graph = json.loads(json.dumps(graph0))
            for key, value in overrides(spec, cue, seed).items():
                if key == 'seed':
                    graph[spec['nodes']['seed'].split('.')[0]]['inputs']['seed'] = value
                    continue
                node, field = key.split(':', 1)[1].split('.')
                graph[node]['inputs'][field] = value
            req = urllib.request.Request(f'{args.comfy}/prompt', data=json.dumps({'prompt': graph}).encode(), headers={'Content-Type': 'application/json'})
            pid = json.load(urllib.request.urlopen(req))['prompt_id']
            while True:
                hist = json.load(urllib.request.urlopen(f'{args.comfy}/history/{pid}'))
                if pid in hist and hist[pid].get('outputs'):
                    break
                time.sleep(2)
            for out in hist[pid]['outputs'].values():
                for item in out.get('audio', []):
                    q = urllib.parse.urlencode({'filename': item['filename'], 'subfolder': item.get('subfolder', ''), 'type': item.get('type', 'output')})
                    target.write_bytes(urllib.request.urlopen(f'{args.comfy}/view?{q}').read())
            print('generated', target)


def cmd_ingest(args):
    """`ingest LIST.json` or `ingest JOB_DIR --cue NAME` (seeds read from provenance)."""
    work = Path(args.work); work.mkdir(parents=True, exist_ok=True)
    source = Path(args.list)
    if source.is_dir():
        if not args.cue or len(args.cue) != 1:
            raise SystemExit('ingest JOB_DIR needs exactly one --cue')
        items = [{'cue': args.cue[0], 'seed': json.loads(p.read_text())['seed'], 'path': str(p)[:-len('.provenance.json')]}
                 for p in sorted(source.glob('*.flac.provenance.json'))]
    else:
        items = json.loads(source.read_text())
    for item in items:
        target = work / f"{item['cue']}-s{item['seed']}.flac"
        shutil.copyfile(item['path'], target)
        prov = Path(item['path'] + '.provenance.json')
        if prov.exists():
            shutil.copyfile(prov, target.with_suffix('.flac.provenance.json'))
        print('ingested', target)


# ---------------------------------------------------------------- audio I/O
def read_audio(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype='<f4').reshape(-1, 2).astype(np.float64)


def write_wav(path, audio):
    pcm = np.clip(audio, -1, 1).astype('<f4').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', '-', '-c:a', 'pcm_s24le', str(path)], input=pcm, check=True)


# ---------------------------------------------------------------- analysis
def stft_mag(mono, n_fft=2048):
    """Centred STFT magnitude: frame i is centred on sample i*HOP."""
    padded = np.pad(mono, (n_fft // 2, n_fft // 2))
    frames = 1 + (len(padded) - n_fft) // HOP
    idx = np.arange(n_fft)[None, :] + HOP * np.arange(frames)[:, None]
    return np.abs(np.fft.rfft(padded[idx] * np.hanning(n_fft), axis=1))


def band_matrix(n_bins, n_bands=40):
    freqs = np.linspace(0, SR / 2, n_bins)
    mel = 2595 * np.log10(1 + freqs / 700)
    edges = np.linspace(mel[1], mel[-1], n_bands + 2)
    fb = np.zeros((n_bands, n_bins))
    for b in range(n_bands):
        lo, mid, hi = edges[b:b + 3]
        fb[b] = np.clip(np.minimum((mel - lo) / (mid - lo), (hi - mel) / (hi - mid)), 0, None)
    return fb, freqs


def normalised_flux(spec_log):
    flux = np.maximum(np.diff(spec_log, axis=0, prepend=spec_log[:1]), 0).sum(axis=1)
    flux = np.maximum(flux - signal.medfilt(flux, 31), 0)
    return flux / (flux.max() + 1e-9)


def features(audio):
    mono = audio.mean(axis=1)
    mag = stft_mag(mono)
    fb, freqs = band_matrix(mag.shape[1])
    mel = np.log1p(mag @ fb.T * 10)
    env = normalised_flux(mel)
    low = normalised_flux(np.log1p(mag[:, (freqs > 30) & (freqs < 160)] * 10))
    # Chroma (55 Hz..2 kHz) and its two-beat novelty: peaks where harmony changes.
    sel = (freqs > 55) & (freqs < 2000)
    pc = np.round(12 * np.log2(freqs[sel] / 440)).astype(int) % 12
    chroma = np.stack([mag[:, sel][:, pc == k].sum(1) for k in range(12)], axis=1)
    chroma /= chroma.sum(1, keepdims=True) + 1e-9
    w = 100
    csum = np.cumsum(np.vstack([np.zeros((1, 12)), chroma]), axis=0)
    nov = np.zeros(len(chroma))
    t = np.arange(w, len(chroma) - w)
    nov[t] = np.linalg.norm((csum[t + w] - csum[t]) - (csum[t] - csum[t - w]), axis=1) / w
    rms = np.sqrt(np.convolve(mono ** 2, np.ones(HOP) / HOP, mode='same')[::HOP][:len(env)] + 1e-12)
    return {'env': env, 'low': low, 'nov': nov / (nov.max() + 1e-9), 'mel': mel, 'rms': rms}


def sample_grid(env, period, phase, start=0, stop=None):
    stop = len(env) - 2 if stop is None else min(stop, len(env) - 2)
    k0 = math.ceil((start - phase) / period)
    pos = phase + period * np.arange(k0, int((stop - phase) / period) + 1)
    pos = pos[(pos >= 0) & (pos < len(env) - 1)]
    i = pos.astype(int); f = pos - i
    return env[i] * (1 - f) + env[i + 1] * f


def grid_score(env, period, phase, start=0, stop=None):
    vals = sample_grid(env, period, phase, start, stop)
    return float(vals.mean()) if len(vals) else 0.0


def best_phase(env, period, start=0, stop=None):
    phases = np.arange(0, period, 0.25)
    scores = [grid_score(env, period, p, start, stop) for p in phases]
    i = int(np.argmax(scores))
    return float(phases[i]), float(scores[i])


def analyse(audio, fixed_bpm=None):
    """Tempo, eighth-note grid, bar phase (downbeat) and drift of one candidate."""
    feat = features(audio)
    env, fps = feat['env'], SR / HOP
    skip = int(1.0 * fps)  # the generator's first second is often a pickup
    body = env.copy(); body[:skip] = 0
    if fixed_bpm is None:
        # Eighth-note lattice score: robust to on/off-beat accents.
        def tempo_score(bpm):
            return best_phase(body, 30 * fps / bpm, skip)[1]
        coarse = np.arange(104, 136.01, 0.25)
        b0 = coarse[int(np.argmax([tempo_score(b) for b in coarse]))]
        fine = np.arange(b0 - 0.3, b0 + 0.301, 0.02)
        bpm = float(fine[int(np.argmax([tempo_score(b) for b in fine]))])
    else:
        bpm = fixed_bpm
    beat = 60 * fps / bpm
    eighth = beat / 2
    phase8, strength = best_phase(body, eighth, skip)
    off = grid_score(body, eighth, phase8 + eighth / 2, skip)
    n = len(env); quarter = (n - skip) // 4
    drift = []
    for q in range(4):
        p, _ = best_phase(env, eighth, skip + q * quarter, skip + (q + 1) * quarter)
        drift.append(((p - phase8 + eighth / 2) % eighth - eighth / 2) / fps * 1000)
    # Bar phase: which of the 8 eighth positions in a bar starts it.
    bar = 4 * beat
    scores = []
    for k in range(8):
        o = phase8 + k * eighth
        def fold(x):
            v = sample_grid(x, bar, o, skip)
            return float(v.mean()) / (float(x[skip:].mean()) + 1e-9)
        scores.append(fold(feat['nov']) + 0.6 * fold(feat['low']) + 0.4 * fold(env) - (0.5 if k % 2 else 0))
    order = np.argsort(scores)[::-1]
    k = int(order[0])
    first = phase8 + k * eighth
    downbeats = first + bar * np.arange(-1, int((n - first) / bar) + 1)
    downbeats = downbeats[downbeats >= 0]
    return {
        'bpm': bpm, 'phase8_s': phase8 / fps, 'grid_strength': strength, 'grid_contrast': strength / (off + 1e-9),
        'drift_ms': drift, 'bar_phase_scores': [round(s, 3) for s in scores],
        'downbeat_confidence': float(scores[k] - scores[int(order[1])]),
        'downbeats_s': [float(d / fps) for d in downbeats],
        'mean_rms': float(feat['rms'][skip:].mean()),
        # Intensity proxies (loudness independent): onsets per second and
        # spectral flux, used to check that levels and boss phases escalate.
        'onset_rate': float(len(signal.find_peaks(env[skip:], height=0.08, distance=6)[0]) / ((n - skip) / fps)),
        'flux': float(env[skip:].mean()),
    }


def to_exact_tempo(audio, bpm):
    """Resample so the measured tempo lands exactly on 120 BPM (tiny pitch change)."""
    ratio = bpm / 120.0
    if abs(ratio - 1) < 1e-4:
        return audio
    new_len = int(round(len(audio) * ratio))
    return np.stack([signal.resample(audio[:, c], new_len) for c in range(2)], axis=1)


def bar_similarity(mel, a, b, frames):
    x = mel[a:a + frames].ravel(); y = mel[b:b + frames].ravel()
    if len(x) != len(y) or len(x) == 0:
        return -1.0
    x = x - x.mean(); y = y - y.mean()
    return float(np.dot(x, y) / (np.linalg.norm(x) * np.linalg.norm(y) + 1e-9))


def choose_window(audio, cue):
    """Pick a downbeat-aligned window of exactly `beats` beats (+ continuation)."""
    beat = SR // 2  # 120 BPM at 48 kHz: 24000 samples, exact
    length = cue['beats'] * beat
    bar = 4 * beat
    info = analyse(audio, fixed_bpm=120.0)
    feat = features(audio)
    mel, rms = feat['mel'], feat['rms']
    tail = bar if cue['kind'] != 'oneshot' else int(cue.get('fade_s', .5) * SR)
    best = None
    for d in info['downbeats_s']:
        s = int(round(d * SR))
        if cue['kind'] == 'loop' and s < int(1.5 * SR):
            continue  # skip the generated intro for loops
        if s + length + tail > len(audio) - int(0.25 * SR):
            break
        f0 = s // HOP; fl = length // HOP; fb = bar // HOP
        seg = rms[f0:f0 + fl]
        steadiness = float(seg[:fb].mean() / (seg[-fb:].mean() + 1e-9))
        if cue['kind'] == 'loop':
            # The bar after the window must resemble the window's first bar,
            # and loudness must not swell or fade across the loop.
            sim = bar_similarity(mel, f0 + fl, f0, fb)
            score = sim - 0.5 * abs(math.log(steadiness))
        elif cue['kind'] == 'tail':
            # The final bar will repeat: it must resemble the bar that follows it.
            sim = bar_similarity(mel, f0 + fl, f0 + fl - fb, fb)
            score = sim - 0.1 * (s / SR)  # prefer the opening of the generated cue
        else:
            sim = 0.0
            score = -s / SR  # earliest full downbeat
        cand = {'start': s, 'score': score, 'similarity': sim, 'steadiness': steadiness}
        if best is None or cand['score'] > best['score']:
            best = cand
    return best


def equal_power(n):
    t = np.linspace(0, 1, n, endpoint=False)
    return np.cos(t * np.pi / 2)[:, None], np.sin(t * np.pi / 2)[:, None]


def k_weighted_loudness(audio):
    # ITU-R BS.1770-4 K-weighting at 48 kHz, gated integrated loudness.
    b1, a1 = [1.53512485958697, -2.69169618940638, 1.19839281085285], [1, -1.69065929318241, 0.73248077421585]
    b2, a2 = [1.0, -2.0, 1.0], [1, -1.99004745483398, 0.99007225036621]
    y = signal.lfilter(b2, a2, signal.lfilter(b1, a1, audio, axis=0), axis=0)
    block, step = int(0.4 * SR), int(0.1 * SR)
    z = np.array([np.mean(y[i:i + block] ** 2, axis=0).sum() for i in range(0, max(1, len(y) - block + 1), step)])
    lk = -0.691 + 10 * np.log10(z + 1e-12)
    z = z[lk > -70]
    rel = -0.691 + 10 * np.log10(z.mean() + 1e-12) - 10
    z = z[(-0.691 + 10 * np.log10(z + 1e-12)) > rel]
    return float(-0.691 + 10 * np.log10(z.mean() + 1e-12))


def render(audio, cue, start, spec):
    beat = SR // 2
    length = cue['beats'] * beat
    bar = 4 * beat
    xf = int(cue.get('crossfade_s', 0.12) * SR)
    if cue['kind'] == 'loop':
        out = audio[start:start + length].copy()
        cont = audio[start + length:start + length + xf]
        fo, fi = equal_power(xf)
        out[:xf] = cont * fo + out[:xf] * fi
        loop = (0, length)
    elif cue['kind'] == 'tail':
        opening = audio[start:start + length].copy()
        body = audio[start + length - bar:start + length].copy()
        cont = audio[start + length:start + length + xf]
        fo, fi = equal_power(xf)
        body[:xf] = cont * fo + body[:xf] * fi
        out = np.concatenate([opening, body])
        loop = (length, length + bar)
    else:
        fade = int(cue.get('fade_s', 0.5) * SR)
        out = audio[start:start + length + fade].copy()
        out[-fade:] *= np.cos(np.linspace(0, np.pi / 2, fade))[:, None] ** 2
        # Short fade-in avoids a non-zero first sample.
        out[:64] *= np.linspace(0, 1, 64)[:, None]
        loop = None
    out -= out.mean(axis=0)  # no DC offset at the join
    gain = 10 ** ((spec['loudness_lufs'] - k_weighted_loudness(out)) / 20)
    peak = np.abs(out).max() * gain
    ceiling = 10 ** (spec['peak_dbfs'] / 20)
    if peak > ceiling:
        gain *= ceiling / peak
    return out * gain, loop


CODEC_CONTEXT = 4096  # samples of real context primed into each lossy encoder


def patch_elst(path, extra):
    """Shift the MP4 edit list start by `extra` samples (hidden priming context)."""
    data = bytearray(path.read_bytes())
    at = data.find(b'elst')
    if at < 0:
        raise SystemExit(f'{path}: no edit list')
    version = data[at + 4]
    entry = at + 12
    if version == 0:
        media = struct.unpack('>i', data[entry + 4:entry + 8])[0]
        data[entry + 4:entry + 8] = struct.pack('>i', media + extra)
    else:
        media = struct.unpack('>q', data[entry + 8:entry + 16])[0]
        data[entry + 8:entry + 16] = struct.pack('>q', media + extra)
    path.write_bytes(bytes(data))


def ogg_crc(page):
    crc = 0
    for byte in page:
        crc ^= byte << 24
        for _ in range(8):
            crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF if crc & 0x80000000 else (crc << 1) & 0xFFFFFFFF
    return crc


def ogg_pages(data):
    pos = 0
    while pos < len(data):
        assert data[pos:pos + 4] == b'OggS', 'bad Ogg page'
        nseg = data[pos + 26]
        size = 27 + nseg + sum(data[pos + 27:pos + 27 + nseg])
        yield pos, size
        pos += size


def trim_ogg_opus(path, head, length):
    """Hide `head` primed samples via OpusHead pre-skip and end the stream after
    `length` samples via the final granule position (RFC 7845 trimming)."""
    data = bytearray(path.read_bytes())
    pages = list(ogg_pages(data))
    first, _ = pages[0]
    body = first + 27 + data[first + 26]
    assert data[body:body + 8] == b'OpusHead'
    pre_skip = struct.unpack('<H', data[body + 10:body + 12])[0] + head
    assert pre_skip < 65536
    data[body + 10:body + 12] = struct.pack('<H', pre_skip)
    last, _ = pages[-1]
    data[last + 6:last + 14] = struct.pack('<q', pre_skip + length)
    for start, size in (pages[0], pages[-1]):
        data[start + 22:start + 26] = b'\0\0\0\0'
        data[start + 22:start + 26] = struct.pack('<I', ogg_crc(data[start:start + size]))
    path.write_bytes(bytes(data))


def encode(wav, name, spec, out, loop, kind):
    ogg = OUT / f'{name}.ogg'; m4a = OUT / f'{name}.m4a'
    # Lossy codecs smear the first/last frame. Prime each encoder with the
    # audio that really precedes the file start when looping (the loop's own
    # end) and append the audio that follows the loop end (the loop start),
    # then hide both with the container's trimming (Opus pre-skip + final
    # granule; MP4 edit list) so the decoded length stays exact and the wrap
    # is coded as continuous audio.
    c = CODEC_CONTEXT
    pre = out[-c:] if kind == 'loop' else np.zeros((c, 2))
    post = out[loop[0]:loop[0] + c] if loop else np.zeros((c, 2))
    padded = wav.with_suffix('.ctx.wav')
    write_wav(padded, np.concatenate([pre, out, post]))
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(padded), '-c:a', 'libopus', '-b:a', f"{spec['opus_kbps']}k", '-vbr', 'on', '-application', 'audio', '-map_metadata', '-1', str(ogg)], check=True)
    trim_ogg_opus(ogg, c, len(out))
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(padded), '-c:a', 'aac', '-b:a', f"{spec['aac_kbps']}k", '-map_metadata', '-1', '-movflags', '+faststart',
                    '-metadata:s:a', 'handler_name=', '-t', f'{(len(out) + 2 * c) / SR:.6f}', str(m4a)], check=True)
    patch_elst(m4a, c)
    # Trim the edit list duration to the cue itself.
    data = bytearray(m4a.read_bytes())
    at = data.find(b'elst')
    if data[at + 4] == 0:
        data[at + 12:at + 16] = struct.pack('>I', len(out))
    else:
        data[at + 12:at + 20] = struct.pack('>Q', len(out))
    m4a.write_bytes(bytes(data))
    padded.unlink()
    return ogg, m4a


def candidate_files(work, cue):
    return sorted(Path(work).glob(f"{cue['name']}-s*.flac"))


def rank(info, cue):
    """Higher is better: on-grid, tempo near 120, no drift, strong downbeat."""
    tempo_pen = abs(info['bpm'] - 120) * 0.6
    drift_pen = (max(info['drift_ms']) - min(info['drift_ms'])) / 40
    return math.log(min(info['grid_contrast'], 20)) + 0.3 * min(info['downbeat_confidence'], 3) - tempo_pen - drift_pen


def cmd_analyze(args):
    spec = load_spec()
    report = {}
    for cue in spec['cues']:
        if args.cue and cue['name'] not in args.cue:
            continue
        for path in candidate_files(args.work, cue):
            info = analyse(read_audio(path))
            info['rank'] = rank(info, cue)
            report[path.stem] = info
            print(f"{path.stem:18} bpm={info['bpm']:.2f} contrast={info['grid_contrast']:.2f} drift={np.ptp(info['drift_ms']):5.1f}ms down={info['downbeat_confidence']:.2f} onsets={info['onset_rate']:.1f}/s rank={info['rank']:.2f}")
    target = Path(args.work) / 'analysis.json'
    old = json.loads(target.read_text()) if target.exists() else {}
    old.update(report)
    target.write_text(json.dumps(old, indent=1))


def cmd_build(args):
    spec = load_spec()
    work = Path(args.work)
    analysis = json.loads((work / 'analysis.json').read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'cues': {}}
    manifest.update({'schema': 'demon-attack.music/v1', 'bpm': spec['bpm'], 'sampleRate': SR, 'formats': ['ogg', 'm4a']})
    for cue in spec['cues']:
        if args.cue and cue['name'] not in args.cue:
            continue
        cands = [p for p in candidate_files(work, cue) if p.stem in analysis]
        if not cands:
            print('no candidates for', cue['name']); continue
        if cue.get('pick') is not None:
            cands = [p for p in cands if p.stem == f"{cue['name']}-s{cue['pick']}"]
        best = None
        for path in cands:
            info = analysis[path.stem]
            audio = to_exact_tempo(read_audio(path), info['bpm'])
            win = choose_window(audio, cue)
            if win is None:
                continue
            total = info['rank'] + (2 * win['similarity'] if cue['kind'] != 'oneshot' else 0) + 0.15 * cue.get('density_bias', 0) * info['onset_rate']
            if best is None or total > best[0]:
                best = (total, path, audio, win, info)
        if best is None:
            print('no usable window for', cue['name']); continue
        total, path, audio, win, info = best
        out, loop = render(audio, cue, win['start'], spec)
        wav = work / f"{cue['name']}.wav"
        write_wav(wav, out)
        ogg, m4a = encode(wav, cue["name"], spec, out, loop, cue["kind"])
        seed = int(path.stem.rsplit('-s', 1)[1])
        manifest['cues'][cue['name']] = {
            'kind': cue['kind'], 'beats': cue['beats'], 'seconds': len(out) / SR,
            'loopStart': None if loop is None else loop[0] / SR,
            'loopEnd': None if loop is None else loop[1] / SR,
            'seed': seed, 'sourceBpm': round(info['bpm'], 3), 'startSeconds': round(win['start'] / SR, 4),
            'seamSimilarity': round(win['similarity'], 3),
            'bytes': {'ogg': ogg.stat().st_size, 'm4a': m4a.stat().st_size},
            'sha256': {'ogg': hashlib.sha256(ogg.read_bytes()).hexdigest(), 'm4a': hashlib.sha256(m4a.read_bytes()).hexdigest()},
        }
        print(f"{cue['name']:11} seed={seed} bpm={info['bpm']:.2f} start={win['start']/SR:6.3f}s sim={win['similarity']:.2f} -> {len(out)/SR:.3f}s ogg={ogg.stat().st_size//1024}KB m4a={m4a.stat().st_size//1024}KB")
    manifest['cues'] = dict(sorted(manifest['cues'].items()))
    manifest_path.write_text(json.dumps(manifest, indent=1) + '\n')


def wrap_report(audio, a, b):
    """Discontinuity at the loop wrap relative to the loop's own sample steps."""
    region = audio[a:b]
    steps = np.abs(np.diff(region, axis=0)).max(axis=1)
    wrap = float(np.abs(region[0] - region[-1]).max())
    # Second difference (curvature) over the 8 samples either side of the wrap:
    # a click shows up as a spike far above the loop's typical curvature.
    ring = np.concatenate([region[-8:], region[:8]])
    d2 = float(np.abs(np.diff(ring, n=2, axis=0)).max())
    d2_all = np.abs(np.diff(region, n=2, axis=0)).max(axis=1)
    return {'wrap_step': wrap, 'step_p999': float(np.percentile(steps, 99.9)),
            'wrap_d2': d2, 'd2_p999': float(np.percentile(d2_all, 99.9))}


def cmd_verify(args):
    """Check encoded cues: exact length, whole-bar loops, continuous wrap,
    no codec edge artefacts against the master WAV, beats on the 120 BPM grid."""
    manifest = json.loads((OUT / 'manifest.json').read_text())
    work = Path(args.work)
    ok = True
    for name, meta in manifest['cues'].items():
        if args.cue and name not in args.cue:
            continue
        master = read_audio(work / f'{name}.wav') if (work / f'{name}.wav').exists() else None
        for fmt in ('ogg', 'm4a'):
            audio = read_audio(OUT / f'{name}.{fmt}')
            expected = round(meta['seconds'] * SR)
            problems, notes = [], []
            if len(audio) != expected:
                problems.append(f'length {len(audio)} != {expected}')
            peak = float(np.abs(audio).max())
            if peak >= 0.999:
                problems.append(f'peak {peak:.3f}')
            if meta['loopEnd'] is not None:
                a, b = round(meta['loopStart'] * SR), round(meta['loopEnd'] * SR)
                if (b - a) % (2 * SR) != 0:
                    problems.append('loop is not a whole number of bars')
                w = wrap_report(audio, a, b)
                notes.append(f"wrap step {w['wrap_step']:.4f} (p99.9 {w['step_p999']:.4f}) curvature {w['wrap_d2']:.4f} (p99.9 {w['d2_p999']:.4f})")
                if w['wrap_step'] > w['step_p999']:
                    problems.append('wrap step exceeds the loop\'s 99.9th percentile step')
                if w['wrap_d2'] > max(w['d2_p999'], 0.004):
                    (problems if fmt == 'ogg' else notes).append('click-like curvature at the wrap')
            if master is not None and len(master) == len(audio):
                err = audio - master
                rms = lambda s: float(np.sqrt(np.mean(err[s] ** 2)))
                body = rms(slice(SR, -SR)) + 1e-9
                head, tail = rms(slice(0, 960)) / body, rms(slice(-960, None)) / body
                notes.append(f'edge err head {head:.2f}x tail {tail:.2f}x')
                if max(head, tail) > (2.0 if fmt == 'ogg' else 3.5):
                    problems.append('codec edge artefact')
            if fmt == 'ogg':
                # Beat grid: tile loops so the analysis sees the wrap too.
                probe = np.concatenate([audio[:b], audio[a:b]]) if meta['loopEnd'] is not None else audio
                info = analyse(probe, fixed_bpm=120.0)
                offset = ((info['phase8_s'] + .125) % .25) - .125
                notes.append(f'grid offset {offset * 1000:+.1f} ms')
                if abs(offset) > 0.03 and meta['kind'] != 'oneshot':
                    problems.append('beats are off the 120 BPM eighth-note grid')
            status = 'ok' if not problems else 'FAIL ' + '; '.join(problems)
            if problems:
                ok = False
            print(f"{name:11} {fmt} {len(audio)/SR:6.3f}s peak={peak:.3f} {' '.join(notes)} {status}")
    sys.exit(0 if ok else 1)



def cmd_table(args):
    """Markdown cue table from the manifest (for the plan docs)."""
    manifest = json.loads((OUT / 'manifest.json').read_text())
    print('| Cue | Kind | Beats | Seconds | Loop | Seed | Opus | AAC |')
    print('| --- | --- | ---: | ---: | --- | ---: | ---: | ---: |')
    total = [0, 0]
    for name, m in manifest['cues'].items():
        loop = '—' if m['loopEnd'] is None else f"{m['loopStart']:g}–{m['loopEnd']:g} s"
        total[0] += m['bytes']['ogg']; total[1] += m['bytes']['m4a']
        print(f"| `{name}` | {m['kind']} | {m['beats']} | {m['seconds']:g} | {loop} | {m['seed']} | {m['bytes']['ogg'] / 1024:.0f} KB | {m['bytes']['m4a'] / 1024:.0f} KB |")
    print(f"| **Total** | | | | | | **{total[0] / 1048576:.2f} MB** | **{total[1] / 1048576:.2f} MB** |")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='cmd', required=True)
    for name in ('jobs', 'generate', 'ingest', 'analyze', 'build', 'verify', 'table'):
        p = sub.add_parser(name)
        p.add_argument('--cue', nargs='*')
        p.add_argument('--work', default=str(ROOT / 'build/music'))
        if name == 'generate':
            p.add_argument('--comfy', default='http://studio:8188')
        if name == 'ingest':
            p.add_argument('list')
    args = parser.parse_args()
    {'jobs': cmd_jobs, 'generate': cmd_generate, 'ingest': cmd_ingest, 'analyze': cmd_analyze, 'build': cmd_build, 'verify': cmd_verify, 'table': cmd_table}[args.cmd](args)


if __name__ == '__main__':
    main()
