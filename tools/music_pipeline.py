#!/usr/bin/env python3
"""Reproducible ACE-Step 1.5 music pipeline for web/audio/music/ (round 2:
per-level motifs, intensity tiers, accents).

Stages, in order (all deterministic for the same model files and seeds):

  guides    render every motif guide (tools/music_guide.py, from
            tools/music_motifs.py) to <work>/guides/<cue>.flac.
  jobs      print one generation request per candidate: `--stage refs` for the
            per-group genre reference takes (text-to-music, acestep15-cue.json),
            `--stage a2a` for the cues (audio-to-audio, acestep15-a2a.json,
            inputs $guide and $reference), `--stage text` for text-only cues.
            Each line is a studio.run_workflow request (workflow, inputs,
            overrides); copy guides/references under /work/tmp/imagegen/ first.
  generate  direct mode: POST the same graphs to a ComfyUI server
            (--comfy http://studio:8188), uploading guides and references, and
            download the FLACs into <work>/ (skips candidates that exist).
  ingest    copy studio outputs into <work>/ (`ingest LIST.json`, a list of
            {"cue","seed","denoise","path"}; or `ingest JOB_DIR --cue NAME`).
  refs      pick one reference take per group (best beat grid, or `ref_pick`)
            and write <work>/refs.json; run before `--stage a2a`.
  analyze   per candidate: tempo/grid analysis, and for audio-to-audio
            candidates the motif similarity to the guide (beat chroma, onset
            envelope) and spectral closeness to the group's reference.
  build     pick one candidate per cue (or its pinned `pick`), cut the
            guide-aligned window (text cues: best downbeat window), build the
            loop seam, loudness-normalise, encode Opus/OGG + AAC/M4A; render the
            synth cues (accent sprites, cackle); write web/audio/music/manifest.json.
  verify    decode the encoded files and check lengths, loop wraps, codec
            edges, clipping and the 120 BPM grid.
  report    listening proxies: genre metrics per cue, tier escalation and the
            motif-similarity matrix within each level (JSON + text).
  table     the markdown cue table for the docs.

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
import uuid
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / 'art/workflows/music/cues.json'
OUT = ROOT / 'web/audio/music'
SR = 48000
HOP = 480  # 10 ms analysis frames at 48 kHz
sys.path.insert(0, str(Path(__file__).resolve().parent))


# ---------------------------------------------------------------- spec / jobs
def load_spec():
    return json.loads(SPEC.read_text())


VAE_HOP = 3840  # pad guides to a multiple of this; ACE then returns the same length


def cue_bpm(spec, cue):
    """Exact tempo of a cue: a level cue (l<n>-*) runs at its level's grid
    (tools/music_motifs.py: integer samples per bar); a reference take at its
    group's tempo; everything else at the spec default (120)."""
    import music_motifs
    name = cue['name']
    if name.startswith('l') and len(name) > 2 and name[1].isdigit() and name[2] == '-':
        return music_motifs.bpm_of(name)
    grp = spec['groups'].get(cue.get('group', ''), {})
    return float(cue.get('bpm', grp.get('bpm', spec['bpm'])))


def spb(bpm):
    """Samples per beat at 48 kHz (may be fractional; bars are integers)."""
    return SR * 60.0 / bpm


def beats_samples(beats, bpm):
    return int(round(beats * spb(bpm)))


def mode_of(cue):
    return cue.get('mode', 'a2a' if 'group' in cue else 'text')


def reference_cues(spec):
    """One virtual text-to-music cue per group: its genre reference take."""
    return [{'name': f'ref-{g}', 'kind': 'reference', 'mode': 'text', 'group': g, 'gen_seconds': 30, 'bpm': grp.get('bpm', spec['bpm']),
             'keyscale': grp['keyscale'], 'seeds': grp['ref_seeds'], 'pick': grp.get('ref_pick'),
             'tags': f"{grp['tags']}, {grp['genre']}"} for g, grp in spec['groups'].items() if grp.get('ref_seeds')]


def all_cues(spec):
    return spec['cues'] + reference_cues(spec)


def cue_by_name(spec, name):
    for cue in all_cues(spec):
        if cue['name'] == name:
            return cue
    raise SystemExit(f'unknown cue {name}')


def selected(args, cue):
    return not args.cue or cue['name'] in args.cue


def cue_tags(spec, cue):
    tempo = f"{round(cue_bpm(spec, cue))} bpm"
    if mode_of(cue) == 'text' and ('group' not in cue or cue['kind'] == 'reference'):
        tags = f"{cue['tags']}, {spec['common_tags']}, {tempo}"
        if cue['kind'] == 'reference':
            return tags + ', seamless loop'
        return tags
    grp = spec['groups'][cue['group']]
    extra = spec['tier_tags'].get(str(cue.get('tier', ''))) or spec['part_tags'].get(cue.get('part', '')) or ''
    parts = [grp['tags'], extra, cue.get('extra_tags', ''), spec['common_tags'], tempo]
    if cue['kind'] == 'tail' and mode_of(cue) != 'text':
        parts.append('short cue with a clear ending')
    tags = ', '.join(p for p in parts if p)
    if cue.get('lyrics', '[instrumental]') != '[instrumental]':
        # Wordless vocalise cues: allow the voice, still no words.
        tags = tags.replace('instrumental, no vocals, ', '').replace('instrumental ', '') + ', wordless female soprano vocalise'
    return tags


def loudness_of(spec, cue):
    grp = spec['groups'].get(cue.get('group', ''), {})
    base = cue.get('loudness_lufs', grp.get('loudness_lufs', spec['loudness_lufs']))
    # Intensity tiers also ramp in level (calm tiers leave effects more room).
    return base + spec.get('tier_loudness_db', {}).get(str(cue.get('tier', '')), 0.0)


def gen_bpm(spec, cue):
    """The BPM passed to ACE's text encoder. Metal-v2 finding: asked for
    150-180 BPM, ACE-Step 1.5 text-to-music mostly settles on 140-150 BPM
    (7 of 8 takes asked for 170); asked for half the tempo (85) with the real
    tempo in the tags, 7 of 8 takes lock to 170.0 BPM without drift. Groups
    set `bpm_param` (the half tempo) for that; default: the cue tempo."""
    grp = spec['groups'].get(cue.get('group', ''), {})
    return int(cue.get('bpm_param', grp.get('bpm_param', round(cue_bpm(spec, cue)))))


def text_seeds(spec, cue):
    grp = spec['groups'].get(cue.get('group', ''), {})
    return cue.get('seeds', grp.get('text_seeds', []))


def a2a_grid(spec, cue):
    grp = spec['groups'][cue['group']]
    return [(seed, d) for d in cue.get('denoise', grp['denoise']) for seed in cue.get('seeds', grp['seeds'])]


def cand_name(cue, seed, denoise=None):
    return f"{cue['name']}-s{seed}" + ('' if denoise is None else f'-d{round(denoise * 100)}')


def overrides(spec, cue, seed, denoise=None, guide_seconds=None):
    n = spec['nodes']
    o = {'seed': seed, f"$node:{n['text_seed']}": seed, f"$node:{n['tags']}": cue_tags(spec, cue),
         f"$node:{n['lyrics']}": cue.get('lyrics', spec['lyrics']), f"$node:{n['bpm']}": gen_bpm(spec, cue)}
    grp = spec['groups'].get(cue.get('group', ''), {})
    if mode_of(cue) == 'text':
        seconds = float(cue.get('gen_seconds', grp.get('gen_seconds', 40)))
        o.update({f"$node:{n['duration']}": seconds, f"$node:{n['seconds']}": seconds,
                  f"$node:{n['keyscale']}": cue.get('keyscale', grp.get('keyscale'))})
    else:
        o.update({f"$node:{n['duration']}": float(guide_seconds), f"$node:{n['denoise']}": float(denoise),
                  f"$node:{n['keyscale']}": grp['keyscale'], f"$node:{n['codes']}": False})
        neg = cue.get('neg_tags', grp.get('neg_tags'))
        if neg and 'neg_tags' in n:
            o[f"$node:{n['neg_tags']}"] = neg
    return o


def guide_info(work, name):
    meta = json.loads((Path(work) / 'guides' / 'guides.json').read_text())
    return meta[name]


def chosen_refs(work):
    path = Path(work) / 'refs.json'
    if not path.exists():
        raise SystemExit('run `refs` first (after generating the reference takes)')
    return json.loads(path.read_text())


def requests(spec, args, stage):
    """Yield (cue, seed, denoise, workflow, inputs{name: local path}, overrides)."""
    work = Path(args.work)
    for cue in all_cues(spec):
        if not selected(args, cue) or (cue.get('keep') and not args.cue):
            continue
        mode = mode_of(cue)
        if stage == 'refs' and cue['kind'] == 'reference':
            for seed in cue['seeds']:
                yield cue, seed, None, spec['workflows']['text'], {}, overrides(spec, cue, seed)
        elif stage == 'text' and mode == 'text' and cue['kind'] != 'reference':
            for seed in text_seeds(spec, cue):
                yield cue, seed, None, spec['workflows']['text'], {}, overrides(spec, cue, seed)
        elif stage == 'a2a' and mode == 'a2a':
            info = guide_info(work, cue['name'])
            workflow = spec['workflows'][cue.get('workflow', spec['groups'][cue['group']].get('workflow', 'a2a'))]
            inputs = {'guide': str(work / 'guides' / f"{cue['name']}.flac")}
            if 'ReferenceTimbreAudio' in (ROOT / workflow).read_text():
                inputs['reference'] = str(work / chosen_refs(work)[cue['group']])
            for seed, d in a2a_grid(spec, cue):
                yield cue, seed, d, workflow, inputs, overrides(spec, cue, seed, d, info['seconds'])


def cmd_guides(args):
    import music_guide
    spec = load_spec()
    out = Path(args.work) / 'guides'; out.mkdir(parents=True, exist_ok=True)
    meta_path = out / 'guides.json'
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    for cue in spec['cues']:
        # Synth motif guides: the a2a source of round-3 cues and, for the
        # metal-v2 text cues, the yardstick for the distance from the synth.
        # Derived variants (`source_of`) get their source from `derive`.
        if not selected(args, cue) or mode_of(cue) not in ('a2a', 'text') or cue.get('source_of') or cue['name'] == 'menu':
            continue
        if cue.get('keep') and not args.cue:
            continue
        if cue['name'] == 'cackle':
            # The formant laugh (music_guide.cackle), one second of air either side.
            laugh = fit_length(music_guide.cackle(), beats_samples(cue['beats'], 120))
            audio, offset, beats = np.concatenate([np.zeros((SR, 2)), laugh, np.zeros((SR, 2))]), 1.0, cue['beats']
        else:
            audio, offset, beats = music_guide.guide(cue['name'])
        bpm = cue_bpm(spec, cue)
        # Pad to a multiple of the VAE hop so ACE returns exactly this length.
        pad = (-len(audio)) % VAE_HOP
        audio = np.concatenate([audio, np.zeros((pad, 2))])
        path = out / f"{cue['name']}.flac"
        write_audio(path, audio)
        meta[cue['name']] = {'offset': offset, 'offsetSamples': int(round(offset * SR)), 'beats': beats, 'bpm': bpm,
                             'windowSamples': beats_samples(beats, bpm), 'samples': len(audio), 'seconds': len(audio) / SR,
                             'sha256': hashlib.sha256(audio.astype('<f4').tobytes()).hexdigest()[:16]}
        print(f"guide {cue['name']:16} {bpm:8.3f} BPM {len(audio) / SR:6.3f}s window {beats_samples(beats, bpm)} samples at {offset:.3f}s")
    meta_path.write_text(json.dumps(dict(sorted(meta.items())), indent=1))


def cmd_jobs(args):
    spec = load_spec()
    for cue, seed, d, workflow, inputs, o in requests(spec, args, args.stage):
        req = {'cue': cue['name'], 'seed': seed, 'workflow': workflow, 'overrides': o}
        if d is not None:
            req['denoise'] = d
        if inputs:
            req['inputs'] = inputs
        print(json.dumps(req))


def comfy_upload(comfy, path, name):
    boundary = uuid.uuid4().hex
    head = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\n'
            'Content-Type: audio/flac\r\n\r\n').encode()
    tail = (f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="subfolder"\r\n\r\ndemon_attack\r\n'
            f'--{boundary}\r\nContent-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n--{boundary}--\r\n').encode()
    req = urllib.request.Request(f'{comfy}/upload/image', data=head + Path(path).read_bytes() + tail,
                                 headers={'Content-Type': f'multipart/form-data; boundary={boundary}'})
    info = json.load(urllib.request.urlopen(req))
    return f"{info['subfolder']}/{info['name']}"


def comfy_submit(comfy, graph):
    req = urllib.request.Request(f'{comfy}/prompt', data=json.dumps({'prompt': graph}).encode(), headers={'Content-Type': 'application/json'})
    return json.load(urllib.request.urlopen(req))['prompt_id']


def comfy_run(comfy, graph, target, pid=None):
    pid = pid or comfy_submit(comfy, graph)
    while True:
        hist = json.load(urllib.request.urlopen(f'{comfy}/history/{pid}'))
        status = hist.get(pid, {}).get('status', {}).get('status_str')
        if pid in hist and (hist[pid].get('outputs') or status == 'error'):
            break
        time.sleep(1)
    if status == 'error':
        raise SystemExit(f'ComfyUI error for {target.name}: {json.dumps(hist[pid]["status"])[:800]}')
    for out in hist[pid]['outputs'].values():
        for item in out.get('audio', []):
            q = urllib.parse.urlencode({'filename': item['filename'], 'subfolder': item.get('subfolder', ''), 'type': item.get('type', 'output')})
            target.write_bytes(urllib.request.urlopen(f'{comfy}/view?{q}').read())


def cmd_generate(args):
    """Direct ComfyUI mode: the same graphs as `jobs`, with inputs uploaded."""
    spec = load_spec()
    work = Path(args.work); work.mkdir(parents=True, exist_ok=True)
    uploaded = {}
    batch = []  # queued together so they run back to back on one model load

    def flush():
        for pid, graph, target, cue, seed, d, workflow, o, inputs, t in batch:
            comfy_run(args.comfy, graph, target, pid)
            target.with_suffix('.flac.provenance.json').write_text(json.dumps({'cue': cue['name'], 'seed': seed, 'denoise': d, 'workflow': workflow, 'overrides': o, 'inputs': {k: Path(v).name for k, v in inputs.items()}}, indent=1))
            print(f'generated {target.name} ({time.time() - t:.1f}s since queued)', flush=True)
        batch.clear()

    for cue, seed, d, workflow, inputs, o in requests(spec, args, args.stage):
        target = work / f'{cand_name(cue, seed, d)}.flac'
        if target.exists():
            continue
        graph = json.loads((ROOT / workflow).read_text())
        for node in graph.values():
            audio = node['inputs'].get('audio')
            if node['class_type'] == 'LoadAudio' and isinstance(audio, str) and audio.startswith('$'):
                path = inputs[audio[1:]]
                if path not in uploaded:
                    uploaded[path] = comfy_upload(args.comfy, path, Path(path).name)
                node['inputs']['audio'] = uploaded[path]
        for key, value in o.items():
            if key == 'seed':
                graph[spec['nodes']['seed'].split('.')[0]]['inputs']['seed'] = value
                continue
            node, field = key.split(':', 1)[1].split('.')
            if node in graph and field in graph[node]['inputs']:
                graph[node]['inputs'][field] = value
        if graph.get('6', {}).get('class_type') == 'TextEncodeAceStepAudio1.5':
            # Negative text encoder: same duration, tempo, key and seed as the positive.
            graph['6']['inputs'].update({k: v for k, v in graph['5']['inputs'].items() if k != 'tags'})
        batch.append((comfy_submit(args.comfy, graph), graph, target, cue, seed, d, workflow, o, inputs, time.time()))
        if len(batch) >= args.batch:
            flush()
    flush()


def cmd_ingest(args):
    """`ingest LIST.json` or `ingest JOB_DIR --cue NAME` (seeds read from provenance)."""
    work = Path(args.work); work.mkdir(parents=True, exist_ok=True)
    source = Path(args.list)
    if source.is_dir():
        if not args.cue or len(args.cue) != 1:
            raise SystemExit('ingest JOB_DIR needs exactly one --cue')
        items = []
        for prov in sorted(source.glob('*.flac.provenance.json')):
            meta = json.loads(prov.read_text())
            denoise = meta.get('overrides', {}).get('$node:8.denoise')
            items.append({'cue': args.cue[0], 'seed': meta['seed'], 'denoise': denoise, 'path': str(prov)[:-len('.provenance.json')]})
    else:
        items = json.loads(source.read_text())
    for item in items:
        target = work / f"{cand_name({'name': item['cue']}, item['seed'], item.get('denoise'))}.flac"
        shutil.copyfile(item['path'], target)
        prov = Path(item['path'] + '.provenance.json')
        if prov.exists():
            shutil.copyfile(prov, target.with_suffix('.flac.provenance.json'))
        print('ingested', target)


# ---------------------------------------------------------------- audio I/O
def read_audio(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype='<f4').reshape(-1, 2).astype(np.float64)


def write_audio(path, audio, codec=None):
    pcm = np.clip(audio, -1, 1).astype('<f4').tobytes()
    codec = codec or ('flac' if str(path).endswith('.flac') else 'pcm_s24le')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', '-', '-c:a', codec, str(path)], input=pcm, check=True)


def write_wav(path, audio):
    write_audio(path, audio, 'pcm_s24le')
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


def analyse(audio, fixed_bpm=None, around=None):
    """Tempo, eighth-note grid, bar phase (downbeat) and drift of one candidate.
    `around`: search the tempo within +-12% of this BPM (default 104-136)."""
    feat = features(audio)
    env, fps = feat['env'], SR / HOP
    skip = int(1.0 * fps)  # the generator's first second is often a pickup
    body = env.copy(); body[:skip] = 0
    if fixed_bpm is None:
        # Eighth-note lattice score: robust to on/off-beat accents.
        def tempo_score(bpm):
            return best_phase(body, 30 * fps / bpm, skip)[1]
        lo, hi = (around * .88, around * 1.12) if around else (104, 136)
        coarse = np.arange(lo, hi + .01, 0.25)
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


def motif_features(audio, bpm=120.0):
    """Beat-synchronous chroma (one 12-bin column per eighth note at `bpm`),
    a smoothed onset envelope and the log-mel texture, for motif comparison."""
    mono = audio.mean(axis=1)
    mag = stft_mag(mono, 4096)
    freqs = np.linspace(0, SR / 2, mag.shape[1])
    sel = (freqs > 60) & (freqs < 2100)
    pc = np.round(12 * np.log2(freqs[sel] / 440)).astype(int) % 12
    # Log-compressed chroma so loud low partials do not swamp the melody.
    power = np.log1p(mag[:, sel] * 4)
    chroma = np.stack([power[:, pc == k].sum(1) for k in range(12)], axis=1)
    step = 30.0 / bpm * SR / HOP  # frames per eighth note (fractional)
    cols = int(len(chroma) // step)
    edges = np.round(np.arange(cols + 1) * step).astype(int)
    beat = np.stack([chroma[edges[k]:max(edges[k] + 1, edges[k + 1])].mean(axis=0) for k in range(cols)])
    beat /= np.linalg.norm(beat, axis=1, keepdims=True) + 1e-9
    # The progression: bass-register chroma (riff roots, 40-260 Hz) per bar.
    low = (freqs > 40) & (freqs < 260)
    lpc = np.round(12 * np.log2(freqs[low] / 440)).astype(int) % 12
    lpow = mag[:, low] ** 2
    lchroma = np.stack([lpow[:, lpc == k].sum(1) for k in range(12)], axis=1)
    bar = int(round(4 * 60.0 / bpm * SR / HOP))
    bars = len(lchroma) // bar
    prog = lchroma[:bars * bar].reshape(bars, bar, 12).mean(axis=1)
    prog /= np.linalg.norm(prog, axis=1, keepdims=True) + 1e-9
    fb, _ = band_matrix(mag.shape[1])
    mel = np.log1p(mag @ fb.T * 10)
    env = np.convolve(normalised_flux(mel), np.ones(3) / 3, mode='same')
    return {'chroma': beat, 'onset': env, 'mel': mel, 'progression': prog}


def _corr(x, y):
    x = x - x.mean(axis=0); y = y - y.mean(axis=0)
    return float((x * y).sum() / (np.linalg.norm(x) * np.linalg.norm(y) + 1e-9))


def motif_similarity(a, b):
    """Pearson correlations of the time-centred beat chroma (harmony/riff),
    onset envelopes (rhythm) and log-mel (texture) of two aligned clips."""
    n = min(len(a['chroma']), len(b['chroma']))
    m = min(len(a['onset']), len(b['onset']))
    k = min(len(a['progression']), len(b['progression']))
    return {'chroma': _corr(a['chroma'][:n], b['chroma'][:n]),
            'progression': _corr(a['progression'][:k], b['progression'][:k]),
            'onset': max(_corr(a['onset'][k:m], b['onset'][:m - k]) for k in range(0, 3)),
            'mel': _corr(a['mel'][:m], b['mel'][:m])}


def genre_metrics(audio, bpm=120.0):
    """Loudness-independent listening proxies: tempo, onset density, spectral
    centroid, flatness (noise-like/distorted spectra are flatter), crest
    factor (distortion and dense mixes lower it), high- and low-band share."""
    mono = audio.mean(axis=1)
    info = analyse(audio, around=bpm)
    mag = stft_mag(mono)
    power = mag ** 2 + 1e-12
    freqs = np.linspace(0, SR / 2, mag.shape[1])
    band = (freqs > 500) & (freqs < 6000)
    flat = np.exp(np.log(power[:, band]).mean(1)) / power[:, band].mean(1)
    total = power.sum(1)
    rms = np.sqrt(np.mean(mono ** 2)) + 1e-12
    fbm, _ = band_matrix(mag.shape[1])
    logmel = np.log(mag @ fbm.T + 1e-4)
    # Absolute positive log-mel flux per second: comparable across cues because
    # every cue is loudness-normalised; rises with note and drum density.
    flux_abs = float(np.maximum(np.diff(logmel, axis=0), 0).sum(1).mean() * SR / HOP / 1000)
    return {'bpm': info['bpm'], 'onsets': info['onset_rate'], 'flux': info['flux'], 'flux_abs': flux_abs,
            'centroid': float(((power * freqs).sum(1) / total).mean()),
            'flatness': float(flat.mean()),
            'crest_db': float(20 * np.log10(np.percentile(np.abs(mono), 99.9) / rms)),
            'hf': float((power[:, freqs > 2500].sum(1) / total).mean()),
            'low': float((power[:, freqs < 150].sum(1) / total).mean())}


def metal_metrics(audio):
    """Timbre proxies for distorted-guitar metal against a synth rendering
    (metal-v2 round). flat15: spectral flatness 1-5 kHz (distorted guitars
    are noise-like there: ACE metal takes 0.26-0.47, the synth guide 0.22,
    the round-3 a2a cues 0.09); perc: percussive share of the spectrogram
    energy by median-filter HPSS (drum transients; round 3 0.20, metal
    takes 0.28-0.39); crest_db (99.9th percentile over RMS; lower = denser,
    more compressed); and the energy shares of the low (<150 Hz), mid
    (150 Hz-1 kHz), guitar (1-5 kHz) and air (>5 kHz) bands."""
    from scipy.ndimage import median_filter
    mono = audio.mean(axis=1)
    mag = stft_mag(mono)
    power = mag ** 2 + 1e-12
    freqs = np.linspace(0, SR / 2, mag.shape[1])
    total = power.sum(1)
    share = lambda lo, hi: float((power[:, (freqs >= lo) & (freqs < hi)].sum(1) / total).mean())
    band = (freqs > 1000) & (freqs < 5000)
    flat = float((np.exp(np.log(power[:, band]).mean(1)) / power[:, band].mean(1)).mean())
    sp = mag[:, freqs < 12000]
    harm = median_filter(sp, size=(17, 1)); perc = median_filter(sp, size=(1, 17))
    p_share = float((perc ** 2).sum() / ((perc ** 2).sum() + (harm ** 2).sum() + 1e-12))
    rms = np.sqrt(np.mean(mono ** 2)) + 1e-12
    return {'flat15': flat, 'perc': p_share, 'crest_db': float(20 * np.log10(np.percentile(np.abs(mono), 99.9) / rms)),
            'low': share(0, 150), 'mid': share(150, 1000), 'gtr': share(1000, 5000), 'air': share(5000, SR / 2)}


def metal_score(m):
    """Higher = more like a distorted band recording, less like the synth:
    flatness and percussive share dominate; a hollow guitar band or a peaky
    (uncompressed) mix costs a little."""
    return (4.0 * min(m['flat15'], 0.45) + 3.0 * min(m['perc'], 0.42) + 1.5 * min(m['gtr'], 0.25)
            - 0.08 * max(m['crest_db'] - 10.5, 0.0))


def timbre_distance(a, b):
    """1 - cosine of the mean-removed long-term log-mel spectra."""
    pa, pb = mel_profile(a), mel_profile(b)
    return float(1 - np.dot(pa, pb) / (np.linalg.norm(pa) * np.linalg.norm(pb) + 1e-9))


def to_exact_tempo(audio, bpm, target=120.0):
    """Resample so the measured tempo lands exactly on `target` (tiny pitch change)."""
    ratio = bpm / target
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
    bpm = cue.get('bpm', 120.0)
    length = beats_samples(cue['beats'], bpm)
    bar = beats_samples(4, bpm)
    info = analyse(audio, fixed_bpm=bpm)
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
            # No breakdowns: every bar must carry the cue's energy.
            bars = seg[:len(seg) // fb * fb].reshape(-1, fb).mean(axis=1)
            evenness = float(bars.min() / (np.median(bars) + 1e-9))
            score = sim - 0.5 * abs(math.log(steadiness)) + 1.5 * math.log(min(evenness, 0.8) / 0.8)
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
    bpm = cue.get('bpm', 120.0)
    length = beats_samples(cue['beats'], bpm)
    bar = beats_samples(4, bpm)
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
        # fade_s 0: the cue ends at its last beat; a 20 ms release avoids a click.
        tail = fade or int(0.02 * SR)
        out[-tail:] *= np.cos(np.linspace(0, np.pi / 2, tail))[:, None] ** 2
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
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(padded), '-c:a', 'libopus', '-b:a', f"{spec['opus_kbps']}k", '-vbr', 'on', '-application', 'audio', '-map_metadata', '-1', '-fflags', '+bitexact', '-flags:a', '+bitexact', str(ogg)], check=True)
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


def candidate_files(work, cue, spec=None):
    """Candidate FLACs of a cue; audio-to-audio cues keep only the spec's grid."""
    found = sorted(p for p in Path(work).glob(f"{cue['name']}-s*.flac") if not p.name.endswith('.provenance.json'))
    if spec is not None and mode_of(cue) == 'a2a':
        grid = {cand_name(cue, seed, d) for seed, d in a2a_grid(spec, cue)}
        found = [p for p in found if p.stem in grid]
    return found


def parse_candidate(path):
    stem = path.stem
    denoise = None
    if '-d' in stem.rsplit('-s', 1)[1]:
        stem, d = stem.rsplit('-d', 1)
        denoise = int(d) / 100
    return int(stem.rsplit('-s', 1)[1]), denoise


def rank(info, cue):
    """Higher is better: on-grid, tempo near the cue's, no drift, strong downbeat."""
    tempo_pen = abs(info['bpm'] - cue.get('bpm', 120)) * 0.6
    drift_pen = (max(info['drift_ms']) - min(info['drift_ms'])) / 40
    return math.log(min(info['grid_contrast'], 20)) + 0.3 * min(info['downbeat_confidence'], 3) - tempo_pen - drift_pen


def mel_profile(audio):
    """Long-term spectrum (mean log-mel), mean-removed: the production colour."""
    mono = audio.mean(axis=1)
    mag = stft_mag(mono)
    fb, _ = band_matrix(mag.shape[1])
    prof = np.log(mag @ fb.T + 1e-6).mean(axis=0)
    return prof - prof.mean()


def fit_length(audio, n):
    if len(audio) >= n:
        return audio[:n]
    return np.concatenate([audio, np.zeros((n - len(audio), 2))])


def cmd_refs(args):
    spec = load_spec()
    work = Path(args.work)
    path = work / 'refs.json'
    refs = json.loads(path.read_text()) if path.exists() else {}
    for cue in reference_cues(spec):
        if not selected(args, cue):
            continue
        best = None
        for cand in candidate_files(work, cue):
            seed, _ = parse_candidate(cand)
            info = analyse(read_audio(cand), around=cue['bpm'])
            score = rank(info, cue) + 0.2 * info['onset_rate']
            print(f"{cand.stem:16} bpm={info['bpm']:.2f} contrast={info['grid_contrast']:.2f} onsets={info['onset_rate']:.1f}/s score={score:.2f}")
            if cue.get('pick') is not None and seed == cue['pick']:
                best = (1e9, cand)
            elif best is None or score > best[0]:
                best = (score, cand)
        if best:
            refs[cue['group']] = best[1].name
            print(f"reference {cue['group']}: {best[1].name}")
    path.write_text(json.dumps(dict(sorted(refs.items())), indent=1))


def a2a_scores(spec, work, cue, path, refs, cache={}):
    """Motif similarity to the guide (in the cut window) and closeness to the
    group's reference production; returns the analysis record."""
    info_g = guide_info(work, cue['name'])
    bpm = info_g.get('bpm', 120.0)
    gkey = cue['name']
    if gkey not in cache:
        guide = read_audio(work / 'guides' / f"{cue['name']}.flac")
        gwin = window_of(guide, info_g)
        ref = read_audio(work / refs[cue['group']]) if refs and cue['group'] in refs else None
        cache[gkey] = (len(guide), motif_features(gwin, bpm), None if ref is None else mel_profile(ref[SR * 2:]),
                       genre_metrics(gwin, bpm)['flux_abs'])
    n, gfeat, rprof, gflux = cache[gkey]
    raw = read_audio(path)
    length_ok = len(raw) == n
    audio = fit_length(raw, n)
    win = window_of(audio, info_g)
    feat = motif_features(win, bpm)
    sim = motif_similarity(gfeat, feat)
    lag, _ = guide_lag(feat['onset'], gfeat['onset'])
    prof = mel_profile(win)
    closeness = 0.0 if rprof is None else float(np.dot(prof, rprof) / (np.linalg.norm(prof) * np.linalg.norm(rprof) + 1e-9))
    seed, d = parse_candidate(path)
    tempo, tempo_ok, tempo_target, tempo_top = tempo_check(win, bpm)
    metal = metal_metrics(win)
    metrics = genre_metrics(win, bpm)
    info = {'seed': seed, 'denoise': d, 'motif': sim, 'reference_closeness': closeness, 'guide_lag_ms': round(lag * 1000),
            'length_ok': length_ok, 'tempo': tempo, 'tempo_ok': tempo_ok, 'pulse_target': round(tempo_target, 3), 'pulse_top': round(tempo_top, 3),
            'metrics': metrics, 'metal': metal, 'metal_score': metal_score(metal)}
    if info_g.get('source'):
        # Metal-v2 variant of a recorded cue (the fleet marches): the "guide"
        # is the shipped take itself, so staying on its grid and riff is
        # wanted. Reward the bigger arrangement (more spectral flux than the
        # source) and the band timbre; the tempo gate stays.
        info['score'] = (0.5 * sim['chroma'] + sim['onset'] + 2.0 * info['metal_score']
                         + 2.0 * (metrics['flux_abs'] - gflux) / (gflux + 1e-9) - (0.0 if tempo_ok else 3.0)
                         - (1.0 if sim['onset'] < 0.5 else 0.0))
        return info
    # Round 3 (motif guide): keep the motif first, then sound like the genre take.
    info['score'] = (sim['chroma'] + 0.5 * sim['onset'] + 2.0 * closeness + 0.5 * d
                     - (1.0 if sim['chroma'] < 0.25 else 0.0) - (0.0 if tempo_ok else 3.0))
    return info


# Metal-v2 selection gates for text-to-music takes (see plan/audio-backend.md).
TEMPO_TOLERANCE = 0.004  # a take whose lattice tempo is further off is rejected
MIN_FLAT15 = 0.16        # distorted guitars: 1-5 kHz flatness (round-3 cues 0.09)
MIN_GUIDE_DISTANCE = 0.3  # long-term spectrum distance from the synth guide


def text_scores(spec, work, cue, path, cache={}):
    """Metal-v2 analysis of one text-to-music take: lattice tempo against the
    cue tempo (gate), the resampling ratio to the exact grid, the best
    downbeat-aligned window (loop seam / tail bar / one-shot), the window's
    metal timbre metrics and density, and its distance from the synth motif
    guide of the same cue (when there is one)."""
    bpm = cue['bpm']
    raw = read_audio(path)
    info = analyse(raw, around=bpm)
    info['rank'] = rank(info, cue)
    off = info['bpm'] / bpm - 1
    info['tempo_ok'] = abs(off) <= TEMPO_TOLERANCE
    rec = {'seed': parse_candidate(path)[0], 'bpm': info['bpm'], 'grid_contrast': info['grid_contrast'],
           'drift_ms': info['drift_ms'], 'rank': info['rank'], 'tempo_ok': info['tempo_ok'], 'onset_rate': info['onset_rate']}
    if not info['tempo_ok']:
        rec['score'] = -99.0
        return rec
    audio = to_exact_tempo(raw, info['bpm'], bpm)
    win = choose_window(audio, cue)
    if win is None:
        rec['score'] = -99.0
        return rec
    n = beats_samples(cue['beats'], bpm)
    w = audio[win['start']:win['start'] + n]
    metal = metal_metrics(w)
    g = genre_metrics(w, bpm)
    gpath = Path(work) / 'guides' / f"{cue['name']}.flac"
    gdist = melr = None
    if gpath.exists():
        if cue['name'] not in cache:
            ginfo = guide_info(work, cue['name'])
            cache[cue['name']] = window_of(read_audio(gpath), ginfo)
        gw = cache[cue['name']]
        gdist = timbre_distance(w, gw)
        melr = motif_similarity(motif_features(gw, bpm), motif_features(w, bpm))['mel']
    t, t_ok, _, _ = tempo_check(w, bpm)
    rec.update({'start': win['start'], 'window': win, 'metal': metal, 'metal_score': metal_score(metal), 'flux_abs': g['flux_abs'],
                'onsets': g['onsets'], 'guide_distance': gdist, 'guide_mel_r': melr, 'pulse_ok': t_ok})
    score = info['rank'] + 2.0 * win['score'] + 2.0 * rec['metal_score']
    score -= 2.0 if metal['flat15'] < MIN_FLAT15 else 0.0
    score -= 2.0 if gdist is not None and gdist < MIN_GUIDE_DISTANCE else 0.0
    score -= 0.0 if t_ok else 3.0
    rec['score'] = float(score)
    return rec


def guide_lag(onset, guide_onset):
    """Lag (s) of the best onset-envelope correlation with the guide within
    +-150 ms, and that correlation."""
    n = min(len(onset), len(guide_onset))
    lags = list(range(-15, 16))
    corr = [_corr(onset[max(0, k):n + min(0, k)], guide_onset[max(0, -k):n - max(0, k)]) for k in lags]
    best = int(np.argmax(corr))
    return lags[best] * HOP / SR, corr[best]


def acf_tempo(audio, lo=100.0, hi=240.0):
    """Tempo by onset autocorrelation of a (tiled) loop: score(bpm) sums the
    ACF at 1..8 beats; returns the best BPM and a function score(bpm)."""
    feat = features(audio)
    k = np.exp(-0.5 * (np.arange(-9, 10) / 3.0) ** 2); k /= k.sum()
    env = np.convolve(feat['env'], k, mode='same')
    env = env - env.mean()
    n = len(env)
    spec = np.fft.rfft(env, 2 * n)
    acf = np.fft.irfft(spec * np.conj(spec))[:n]
    acf /= acf[0] + 1e-12
    fps = SR / HOP

    def value(lag):
        i = int(lag); f = lag - i
        return acf[i] * (1 - f) + acf[i + 1] * f if i + 1 < n else 0.0

    def score(bpm):
        b = 60.0 / bpm * fps
        return sum(value(m * b) * (1.0 if m in (1, 2, 4, 8) else 0.5) for m in range(1, 9))
    grid = np.arange(lo, hi, 0.1)
    best = float(grid[int(np.argmax([score(x) for x in grid]))])
    return best, score


FOREIGN_PULSE = 0.8  # ACF score of a strong pulse (guides and clean takes: 1.1-2.5)


def tempo_check(audio, bpm):
    """Does a strong pulse other than the target tempo dominate the take?
    That is the defect the timbre reference caused at these tempos (a 150 BPM
    pulse scoring 2.0 against -0.5 at the 180 BPM target). Returns (best BPM,
    ok, target score, top score). A take with no strong periodicity at all
    (top < FOREIGN_PULSE: smeared drums) passes; its alignment is then judged
    by the chroma check. The argmax of a weak ACF is noise: on the same take it
    flips between 169.6 and 127 BPM after Opus coding (correlation 0.987)."""
    best, score = acf_tempo(np.concatenate([audio, audio]))
    ratio = min(abs(best / bpm - 1), abs(best * 2 / bpm - 1), abs(best / 2 / bpm - 1))
    top = float(score(best))
    at_target = float(max(score(bpm), score(bpm / 2) if bpm / 2 >= 100 else -9, score(bpm * 2) if bpm * 2 <= 240 else -9))
    foreign = top >= FOREIGN_PULSE and ratio > 0.025 and at_target < 0.5 * top
    return best, bool(not foreign), at_target, top


def chroma_alignment(cue, guide, bpm):
    """Best frame-level chroma correlation lag (s) within +-1 beat, its
    correlation, and the correlation at lag 0."""
    def chroma(audio):
        mag = stft_mag(audio.mean(axis=1), 4096)
        fr = np.linspace(0, SR / 2, mag.shape[1])
        sel = (fr > 60) & (fr < 2100)
        pc = np.round(12 * np.log2(fr[sel] / 440)).astype(int) % 12
        pw = np.log1p(mag[:, sel] * 4)
        return np.stack([pw[:, pc == k].sum(1) for k in range(12)], 1)
    x, y = chroma(cue), chroma(guide)
    n = min(len(x), len(y))
    beat = int(round(60.0 / bpm * SR / HOP))
    best, bl = -2.0, 0
    for k in range(-beat, beat + 1):
        c = _corr(x[max(0, k):n + min(0, k)], y[max(0, -k):n - max(0, k)])
        if c > best:
            best, bl = c, k
    return bl * HOP / SR, best, _corr(x[:n], y[:n])


def window_of(audio, info_g):
    s = info_g.get('offsetSamples', int(round(info_g['offset'] * SR)))
    n = info_g.get('windowSamples', info_g['beats'] * SR // 2)
    return audio[s:s + n]


def cmd_analyze(args):
    spec = load_spec()
    work = Path(args.work)
    target = work / 'analysis.json'
    report = json.loads(target.read_text()) if target.exists() else {}
    refs = None
    for cue in spec['cues']:
        if not selected(args, cue) or mode_of(cue) == 'synth' or (cue.get('keep') and not args.cue):
            continue
        cue = dict(cue, bpm=cue_bpm(spec, cue))
        for path in candidate_files(work, cue, spec):
            if mode_of(cue) == 'text':
                info = text_scores(spec, work, cue, path)
                if 'metal' in info:
                    m = info['metal']
                    gd = info['guide_distance']
                    print(f"{path.stem:22} bpm={info['bpm']:.2f} contrast={info['grid_contrast']:.1f} seam={info['window']['similarity']:.2f} at={info['start'] / SR:.2f}s "
                          f"flat={m['flat15']:.3f} perc={m['perc']:.3f} crest={m['crest_db']:.1f} flux={info['flux_abs']:.2f} gdist={'-' if gd is None else f'{gd:.2f}'} score={info['score']:.2f}", flush=True)
                else:
                    print(f"{path.stem:22} bpm={info['bpm']:.2f} rejected (tempo {cue['bpm']:.2f} wanted)", flush=True)
            else:
                if refs is None:
                    refs = json.loads((work / 'refs.json').read_text()) if (work / 'refs.json').exists() else {}
                info = a2a_scores(spec, work, cue, path, refs)
                m = info['motif']
                print(f"{path.stem:22} chroma={m['chroma']:.3f} onset={m['onset']:.3f} mel={m['mel']:.3f} ref={info['reference_closeness']:.3f} tempo={info['tempo']:.1f}{'' if info['tempo_ok'] else '!'} score={info['score']:.3f}", flush=True)
            report[path.stem] = info
    target.write_text(json.dumps(dict(sorted(report.items())), indent=1))


def build_record(cue, out, loop, ogg, m4a, extra):
    import music_motifs
    rec = {'kind': cue['kind'], 'beats': cue.get('beats'), 'bpm': round(cue.get('bpm', 120.0), 4),
           'barSamples': beats_samples(4, cue.get('bpm', 120.0)), 'seconds': len(out) / SR,
           'loopStart': None if loop is None else loop[0] / SR, 'loopEnd': None if loop is None else loop[1] / SR}
    rec.update(extra)
    rec.update({'bytes': {'ogg': ogg.stat().st_size, 'm4a': m4a.stat().st_size},
                'sha256': {'ogg': hashlib.sha256(ogg.read_bytes()).hexdigest(), 'm4a': hashlib.sha256(m4a.read_bytes()).hexdigest()}})
    return rec


def normalise(out, lufs, spec):
    out = out - out.mean(axis=0)
    gain = 10 ** ((lufs - k_weighted_loudness(out)) / 20)
    peak = np.abs(out).max() * gain
    ceiling = 10 ** (spec['peak_dbfs'] / 20)
    if peak > ceiling:
        gain *= ceiling / peak
    return out * gain


def build_synth(spec, cue, work):
    import music_guide
    if cue['kind'] == 'sprite':
        out = music_guide.accents(int(cue['group']))
        extra = {'slotSeconds': music_guide.SLOT_SECONDS, 'slots': list(music_guide.motifs.ACCENTS), 'source': 'synth'}
    else:
        laugh = music_guide.cackle()
        out = fit_length(laugh, cue['beats'] * SR // 2)
        extra = {'source': 'synth'}
        if cue.get('next'):
            extra['next'] = cue['next']
    out = normalise(out, loudness_of(spec, cue), spec)
    out[:64] *= np.linspace(0, 1, 64)[:, None]
    return out, None, extra


def cmd_build(args):
    spec = load_spec()
    work = Path(args.work)
    analysis = json.loads((work / 'analysis.json').read_text()) if (work / 'analysis.json').exists() else {}
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'cues': {}}
    if manifest.get('schema') not in ('demon-attack.music/v2', 'demon-attack.music/v3'):
        manifest = {'cues': {}}
    manifest.update({'schema': 'demon-attack.music/v3', 'bpm': spec['bpm'], 'sampleRate': SR, 'formats': ['ogg', 'm4a']})
    import music_motifs
    manifest['motifs'] = {str(k): {'name': m['name'], 'genre': spec['groups'][str(k)]['genre'], 'keyscale': m['keyscale'], 'summary': m['summary'],
                                   'bpm': round(music_motifs.BPM[k], 4), 'barSamples': music_motifs.BAR_SAMPLES[k]} for k, m in music_motifs.MOTIFS.items()}
    choices = json.loads((work / 'choices.json').read_text()) if (work / 'choices.json').exists() else {}
    tier_pick = choose_tiers(spec, work, analysis)
    for cue in spec['cues']:
        if not selected(args, cue) or (cue.get('keep') and not args.cue):
            continue
        cue = dict(cue, bpm=cue_bpm(spec, cue))
        mode = mode_of(cue)
        cspec = dict(spec, loudness_lufs=loudness_of(spec, cue))
        if mode == 'synth':
            out, loop, extra = build_synth(spec, cue, work)
        else:
            cands = [p for p in candidate_files(work, cue, spec) if p.stem in analysis]
            if cue.get('pick') is not None:
                cands = [p for p in cands if p.stem == f"{cue['name']}-s{cue['pick']}" or p.stem.startswith(f"{cue['name']}-s{cue['pick']}-d")
                         and (cue.get('pick_denoise') is None or p.stem.endswith(f"-d{round(cue['pick_denoise'] * 100)}"))]
            if not cands:
                print('no candidates for', cue['name']); continue
            if mode == 'text':
                usable = [p for p in cands if analysis[p.stem].get('score', -99) > -50 and 'start' in analysis[p.stem]]
                if not usable:
                    print('no usable take for', cue['name']); continue
                if cue['name'] in tier_pick:
                    path = next(p for p in usable if p.stem == tier_pick[cue['name']])
                else:
                    path = max(usable, key=lambda p: analysis[p.stem]['score'] + 0.15 * cue.get('density_bias', 0) * analysis[p.stem]['onset_rate'])
                info = analysis[path.stem]
                audio = to_exact_tempo(read_audio(path), info['bpm'], cue['bpm'])
                start = info['start']
                win = info['window']
                choices[cue['name']] = {'path': str(path), 'sourceBpm': info['bpm'], 'start': start}
                m = info['metal']
                extra = {'mode': 'text', 'group': cue.get('group'), 'seed': info['seed'], 'sourceBpm': round(info['bpm'], 3),
                         'startSeconds': round(start / SR, 4), 'seamSimilarity': round(win['similarity'], 3),
                         'flat15': round(m['flat15'], 3), 'perc': round(m['perc'], 3), 'crestDb': round(m['crest_db'], 2),
                         'fluxAbs': round(info['flux_abs'], 3)}
                if info.get('guide_distance') is not None:
                    extra['guideDistance'] = round(info['guide_distance'], 3)
                for key in ('tier', 'part'):
                    if key in cue:
                        extra[key] = cue[key]
            else:
                path = max(cands, key=lambda p: analysis[p.stem]['score'])
                info = analysis[path.stem]
                ginfo = guide_info(work, cue['name'])
                audio = fit_length(read_audio(path), ginfo.get('samples', int(round(ginfo['seconds'] * SR))))
                start = ginfo.get('offsetSamples', int(round(ginfo['offset'] * SR)))
                # The cut is the guide window itself: audio-to-audio keeps the
                # guide's timing (latent frames are positional). An onset-envelope
                # "lag" against the synth guide reflects ACE's softer transients,
                # not a time shift (round 3: shifting by it moved the chroma and
                # mel alignment off zero), so no shift is applied.
                shift = 0
                r = 0.0
                extra = {'mode': 'a2a', 'group': cue['group'], 'seed': info['seed'], 'denoise': info['denoise'],
                         'gridShiftMs': round(shift / SR * 1000, 1), 'guideLagR': round(r, 2),
                         'motifChroma': round(info['motif']['chroma'], 3), 'motifOnset': round(info['motif']['onset'], 3),
                         'referenceCloseness': round(info['reference_closeness'], 3), 'startSeconds': ginfo['offset']}
                if ginfo.get('source'):
                    m = info['metal']
                    extra.update({'variantOf': ginfo['source'], 'flat15': round(m['flat15'], 3), 'perc': round(m['perc'], 3),
                                  'crestDb': round(m['crest_db'], 2), 'fluxAbs': round(info['metrics']['flux_abs'], 3)})
                    for k in ('gridShiftMs', 'guideLagR', 'referenceCloseness'):
                        extra.pop(k)
                for key in ('tier', 'part'):
                    if key in cue:
                        extra[key] = cue[key]
            out, loop = render(audio, cue, start, cspec)
        wav = work / f"{cue['name']}.wav"
        write_wav(wav, out)
        if cue['kind'] == 'sprite':
            loop_for_codec, kind = None, 'oneshot'
        else:
            loop_for_codec, kind = loop, cue['kind']
        ogg, m4a = encode(wav, cue['name'], cspec, out, loop_for_codec, kind)
        if cue.get('next'):
            extra['next'] = cue['next']
        manifest['cues'][cue['name']] = build_record(cue, out, loop, ogg, m4a, extra)
        print(f"{cue['name']:11} {extra.get('mode', 'synth'):5} seed={extra.get('seed', '-')} d={extra.get('denoise', '-')} -> {len(out) / SR:.3f}s ogg={ogg.stat().st_size // 1024}KB m4a={m4a.stat().st_size // 1024}KB")
    names = {c['name'] for c in spec['cues']}
    manifest['cues'] = {k: v for k, v in sorted(manifest['cues'].items()) if k in names}
    manifest_path.write_text(json.dumps(manifest, indent=1) + '\n')
    (work / 'choices.json').write_text(json.dumps(dict(sorted(choices.items())), indent=1))


def choose_tiers(spec, work, analysis, top=4):
    """Joint pick of a level's four text-mode tiers: the best-scored takes
    whose density (absolute spectral flux of the window) rises from tier 1 to
    tier 4. Each tier keeps its `top` best takes; every combination scores the
    sum of the take scores, +1 per rising step, -1.5 per falling step."""
    import itertools
    picks = {}
    for level in range(1, 6):
        names = [f'l{level}-t{t}' for t in range(1, 5)]
        cues = {c['name']: c for c in spec['cues'] if c['name'] in names and mode_of(c) == 'text'}
        if len(cues) != 4:
            continue
        lists = []
        for name in names:
            cands = [p.stem for p in candidate_files(work, cues[name], spec) if p.stem in analysis and analysis[p.stem].get('score', -99) > -50
                     and 'start' in analysis[p.stem]]
            if cues[name].get('pick') is not None:
                cands = [c for c in cands if c == f"{name}-s{cues[name]['pick']}"]
            lists.append(sorted(cands, key=lambda c: -analysis[c]['score'])[:top])
        if not all(lists):
            continue
        best = None
        for combo in itertools.product(*lists):
            flux = [analysis[c]['flux_abs'] for c in combo]
            steps = [b - a for a, b in zip(flux, flux[1:])]
            total = sum(analysis[c]['score'] for c in combo) + sum(1.0 if s > 0 else -1.5 for s in steps)
            if best is None or total > best[0]:
                best = (total, combo)
        picks.update(dict(zip(names, best[1])))
        print(f"L{level} tiers: {', '.join(best[1])} flux {[round(analysis[c]['flux_abs'], 2) for c in best[1]]}")
    return picks


def cmd_derive(args):
    """Write the a2a source of each `source_of` cue (the fleet marches) from
    the take chosen for its source cue by `build` (choices.json): the source
    window with one bar before and two after, padded to the VAE hop, as
    <work>/guides/<cue>.flac with its guides.json entry."""
    spec = load_spec()
    work = Path(args.work)
    choices = json.loads((work / 'choices.json').read_text())
    meta_path = work / 'guides' / 'guides.json'
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    for cue in spec['cues']:
        if not cue.get('source_of') or not selected(args, cue):
            continue
        src = choices[cue['source_of']]
        bpm = cue_bpm(spec, cue)
        audio = to_exact_tempo(read_audio(src['path']), src['sourceBpm'], bpm)
        bar = beats_samples(4, bpm)
        length = beats_samples(cue['beats'], bpm)
        pre = min(bar, src['start'])
        seg = audio[src['start'] - pre:src['start'] + length + 2 * bar]
        seg = np.concatenate([seg, np.zeros(((-len(seg)) % VAE_HOP, 2))])
        path = work / 'guides' / f"{cue['name']}.flac"
        write_audio(path, seg)
        meta[cue['name']] = {'offset': pre / SR, 'offsetSamples': pre, 'beats': cue['beats'], 'bpm': bpm, 'windowSamples': length,
                             'samples': len(seg), 'seconds': len(seg) / SR, 'source': cue['source_of'],
                             'sha256': hashlib.sha256(seg.astype('<f4').tobytes()).hexdigest()[:16]}
        print(f"derived {cue['name']} from {Path(src['path']).name} at {src['start'] / SR:.3f}s ({len(seg) / SR:.2f}s)")
    meta_path.write_text(json.dumps(dict(sorted(meta.items())), indent=1))


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
    no codec edge artefacts against the master WAV, beats on the 120 BPM grid,
    and the total Opus budget."""
    manifest = json.loads((OUT / 'manifest.json').read_text())
    spec = load_spec()
    work = Path(args.work)
    ok = True
    missing = [c['name'] for c in spec['cues'] if c['name'] not in manifest['cues']]
    if missing:
        print('FAIL missing cues:', ', '.join(missing)); ok = False
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
            a = b = None
            bpm = meta.get('bpm', 120.0)
            bar_samples = meta.get('barSamples', 2 * SR)
            if meta['loopEnd'] is not None:
                a, b = round(meta['loopStart'] * SR), round(meta['loopEnd'] * SR)
                if (b - a) % bar_samples != 0:
                    problems.append('loop is not a whole number of bars')
                w = wrap_report(audio, a, b)
                notes.append(f"wrap {w['wrap_step']:.4f}/{w['step_p999']:.4f} d2 {w['wrap_d2']:.4f}/{w['d2_p999']:.4f}")
                # A guide-aligned loop starts on bar 1's downbeat, so the wrap may
                # carry a real attack: compare against the master's own wrap (the
                # continuous source waveform) as well as the loop's percentile.
                mw = wrap_report(master, a, b) if master is not None and len(master) == len(audio) else None
                step_limit = max(w['step_p999'], 1.5 * mw['wrap_step'] + 0.01) if mw else w['step_p999']
                d2_limit = max(w['d2_p999'], 0.004, 1.5 * mw['wrap_d2'] + 0.01) if mw else max(w['d2_p999'], 0.004)
                if mw:
                    notes.append(f"master wrap {mw['wrap_step']:.4f} d2 {mw['wrap_d2']:.4f}")
                if w['wrap_step'] > step_limit:
                    (problems if fmt == 'ogg' else notes).append('wrap step exceeds the loop\'s 99.9th percentile step and the master wrap')
                if w['wrap_d2'] > d2_limit:
                    (problems if fmt == 'ogg' else notes).append('click-like curvature at the wrap')
            if meta['kind'] in ('loop', 'tail') and meta.get('beats'):
                # Whole bars of the cue's integer bar length (bpm in the manifest is rounded).
                ideal = meta['beats'] / 4 * bar_samples
                start_ok = meta['kind'] == 'loop' or round(meta['loopStart'] * SR) == ideal
                if meta['beats'] % 4 or (meta['kind'] == 'loop' and len(audio) != ideal) or not start_ok:
                    problems.append(f'loop is not a sample-exact {meta["beats"]} beats at {bpm:g} BPM')
            if meta['kind'] == 'sprite':
                slot = round(meta['slotSeconds'] * SR)
                if len(audio) != slot * len(meta['slots']):
                    problems.append('sprite slots do not tile the file')
                ends = [float(np.abs(audio[(i + 1) * slot - 480:(i + 1) * slot]).max()) for i in range(len(meta['slots']))]
                # AAC pre-echo of the next slot's attack is allowed (about -30 dB).
                if max(ends) > (0.02 if fmt == 'ogg' else 0.05):
                    problems.append(f'slot does not end silent ({max(ends):.3f})')
            if master is not None and len(master) == len(audio) and meta['kind'] in ('loop', 'tail'):
                err = audio - master
                rms = lambda s: float(np.sqrt(np.mean(err[s] ** 2)))
                bar = bar_samples
                inner = [rms(slice(i, i + 960)) for i in range(bar, len(audio) - bar, bar)]
                inner_tail = [rms(slice(i - 960, i)) for i in range(bar, len(audio) - bar + 1, bar)]
                head = rms(slice(0, 960)) / (np.median(inner) + 1e-9) if inner else 1.0
                tail = rms(slice(-960, None)) / (np.median(inner_tail) + 1e-9) if inner_tail else 1.0
                notes.append(f'edge {head:.2f}x/{tail:.2f}x')
                checked = [head, tail] if meta['kind'] == 'loop' else [tail]
                if max(checked) > (2.5 if fmt == 'ogg' else 4.0):
                    (problems if fmt == 'ogg' else notes).append('codec edge artefact')
            guide = work / 'guides' / f'{name}.flac'
            r = 0.0
            if fmt == 'ogg' and meta.get('mode') == 'a2a' and guide.exists():
                # The guide fixes the grid: the cue's onsets must line up with
                # the guide window's (lag of the best onset correlation).
                ginfo = guide_info(work, name)
                gw = motif_features(window_of(read_audio(guide), ginfo), bpm)['onset']
                cw = motif_features(audio[:ginfo.get('windowSamples', ginfo['beats'] * SR // 2)], bpm)['onset']
                lag, r = guide_lag(cw, gw)
                # Grid alignment: frame-level chroma cross-correlation with the
                # guide over +-1 beat (riff and chord changes survive the drum
                # smearing that makes onset lags unreliable at these tempos).
                clag, cbest, c0 = chroma_alignment(audio[:ginfo['windowSamples']], window_of(read_audio(guide), ginfo), bpm)
                notes.append(f'onset lag {lag * 1000:+.0f}ms (r={r:.2f}) chroma lag {clag * 1000:+.0f}ms (r={cbest:.2f}, at 0 {c0:.2f})')
                if cbest >= 0.3 and c0 < 0.85 * cbest:
                    problems.append('the take is off the guide grid (chroma alignment)')
                # Loops: the loop; tails (intros): the opening (the last-bar loop is too short).
                loop_audio = audio[a:b] if meta['kind'] == 'loop' else audio[:ginfo['windowSamples']]
                tempo, tempo_ok, at_target, top = tempo_check(loop_audio, bpm)
                notes.append(f'pulse: target {at_target:.2f}, strongest {top:.2f} at {tempo:.1f}' + ('' if top >= FOREIGN_PULSE else ' (weak)'))
                if not tempo_ok:
                    problems.append(f'a foreign {tempo:.1f} BPM pulse dominates the {bpm:g} BPM grid')
                r = 1.0  # the guide check stands in for the lattice check
            if fmt == 'ogg' and meta['kind'] in ('loop', 'tail') and not (meta.get('mode') == 'a2a' and guide.exists()):
                # No reliable guide correlation: check the eighth lattice at the cue's tempo.
                probe = np.concatenate([audio[:b], audio[a:b]]) if b else audio
                info = analyse(probe, fixed_bpm=bpm)
                e8 = 30.0 / bpm
                offset = ((info['phase8_s'] + e8 / 2) % e8) - e8 / 2
                notes.append(f'grid {offset * 1000:+.1f}ms')
                if abs(offset) > 0.03:
                    problems.append(f'beats are off the {bpm:g} BPM eighth-note grid')
            status = 'ok' if not problems else 'FAIL ' + '; '.join(problems)
            if problems:
                ok = False
            print(f"{name:11} {fmt} {len(audio)/SR:6.3f}s peak={peak:.3f} {' '.join(notes)} {status}")
    opus = sum(m['bytes']['ogg'] for m in manifest['cues'].values())
    budget = spec.get('opus_budget_bytes', 8 * 1024 * 1024)
    print(f'Opus total {opus / 1048576:.2f} MB (budget {budget / 1048576:.0f} MB)', 'ok' if opus <= budget else 'FAIL')
    ok = ok and opus <= budget
    sys.exit(0 if ok else 1)


def cmd_report(args):
    """Analysis-based listening proxies on the shipped (decoded Opus) cues."""
    manifest = json.loads((OUT / 'manifest.json').read_text())
    cues = manifest['cues']
    report = {'metrics': {}, 'levels': {}, 'lufs': {}}
    feats = {}
    for name, meta in cues.items():
        if meta['kind'] == 'sprite':
            continue
        audio = read_audio(OUT / f'{name}.ogg')
        body = audio if meta['loopEnd'] is None else audio[round(meta['loopStart'] * SR):round(meta['loopEnd'] * SR)]
        if meta['kind'] == 'tail':
            body = audio[:round(meta['loopStart'] * SR)]
        report['metrics'][name] = {k: round(v, 4) for k, v in genre_metrics(body, meta.get('bpm', 120.0)).items()}
        report['metrics'][name]['lufs'] = round(k_weighted_loudness(body), 2)
        feats[name] = motif_features(body, meta.get('bpm', 120.0))
        report['metrics'][name]['expected_bpm'] = meta.get('bpm', 120.0)
    print(f"{'cue':16} {'bpm':>6} {'onset/s':>7} {'fluxabs':>7} {'centroid':>8} {'flat':>6} {'crest':>6} {'hf':>6} {'low':>6}")
    for name, m in report['metrics'].items():
        print(f"{name:16} {m['bpm']:6.1f} {m['onsets']:7.2f} {m['flux_abs']:7.2f} {m['centroid']:8.0f} {m['flatness']:6.3f} {m['crest_db']:6.1f} {m['hf']:6.3f} {m['low']:6.3f}")
    import music_motifs
    for level in range(1, 6):
        names = [f'l{level}-t{t}' for t in range(1, 5) if f'l{level}-t{t}' in feats]
        if not names:
            continue
        sim = lambda a, b, key: round(motif_similarity(feats[a], feats[b])[key], 2)
        matrix = [[sim(a, b, 'chroma') for b in names] for a in names]
        prog = [[sim(a, b, 'progression') for b in names] for a in names]
        # Cross-level baseline: the same tier of the other levels.
        other = {key: [sim(f'l{level}-t2', f'l{o}-t2', key) for o in range(1, 6) if o != level and f'l{o}-t2' in feats] for key in ('chroma', 'progression')}
        # Intro and outro against each tier's opening bars (best tier).
        parts = {}
        for part in ('intro', 'outro'):
            pn = f'l{level}-{part}'
            if pn in feats:
                parts[part] = {key: max(sim(pn, t, key) for t in names) for key in ('chroma', 'progression')}
        notes = [len(music_motifs.tier_events(level, t)) for t in range(1, 5)]
        report['levels'][level] = {'tiers': names, 'chroma_matrix': matrix, 'progression_matrix': prog, 'other_levels_t2': other, 'parts_best_tier': parts,
                                   'guide_events': notes, 'onsets': [report['metrics'][n]['onsets'] for n in names],
                                   'flux_abs': [round(report['metrics'][n]['flux_abs'], 2) for n in names], 'lufs': [report['metrics'][n]['lufs'] for n in names], 'hf': [report['metrics'][n]['hf'] for n in names]}
        off = lambda m: round(float(np.mean([m[i][j] for i in range(len(m)) for j in range(len(m)) if i != j])), 2)
        print(f'L{level} within-level tiers: chroma {off(matrix)} progression {off(prog)} | vs other levels: chroma {np.mean(other["chroma"]):.2f} progression {np.mean(other["progression"]):.2f} | intro/outro {parts}')
        print(f'   progression matrix {prog}')
        print(f"   guide events by tier {notes}  flux_abs {report['levels'][level]['flux_abs']}  onsets/s {[round(x, 1) for x in report['levels'][level]['onsets']]}  LUFS {report['levels'][level]['lufs']}  hf {[round(x, 3) for x in report['levels'][level]['hf']]}")
    path = Path(args.work) / 'report.json'
    path.write_text(json.dumps(report, indent=1))
    print('wrote', path)


def cmd_table(args):
    """Markdown cue table from the manifest (for the plan docs)."""
    manifest = json.loads((OUT / 'manifest.json').read_text())
    print('| Cue | Kind | Source | Beats | Seconds | Loop | Opus | AAC |')
    print('| --- | --- | --- | ---: | ---: | --- | ---: | ---: |')
    total = [0, 0]
    for name, m in manifest['cues'].items():
        loop = '—' if m['loopEnd'] is None else f"{m['loopStart']:g}–{m['loopEnd']:g} s"
        src = m.get('mode', m.get('source', ''))
        if src == 'a2a':
            src = f"a2a s{m['seed']} d{m['denoise']:.2f}"
        elif src == 'text':
            src = f"text s{m['seed']}"
        total[0] += m['bytes']['ogg']; total[1] += m['bytes']['m4a']
        print(f"| `{name}` | {m['kind']} | {src} | {m.get('beats') or '—'} | {m['seconds']:g} | {loop} | {m['bytes']['ogg'] / 1024:.0f} KB | {m['bytes']['m4a'] / 1024:.0f} KB |")
    print(f"| **Total** | | | | | | **{total[0] / 1048576:.2f} MB** | **{total[1] / 1048576:.2f} MB** |")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='cmd', required=True)
    commands = {'guides': cmd_guides, 'jobs': cmd_jobs, 'generate': cmd_generate, 'ingest': cmd_ingest, 'refs': cmd_refs,
                'analyze': cmd_analyze, 'build': cmd_build, 'derive': cmd_derive, 'verify': cmd_verify, 'report': cmd_report, 'table': cmd_table}
    for name in commands:
        p = sub.add_parser(name)
        p.add_argument('--cue', nargs='*')
        p.add_argument('--work', default=str(ROOT / 'build/music'))
        if name in ('jobs', 'generate'):
            p.add_argument('--stage', choices=['refs', 'a2a', 'text'], default='a2a')
        if name == 'generate':
            p.add_argument('--comfy', default='http://studio:8188')
            p.add_argument('--batch', type=int, default=6, help='prompts queued at once (they then run back to back)')
        if name == 'ingest':
            p.add_argument('list')
    args = parser.parse_args()
    commands[args.cmd](args)


if __name__ == '__main__':
    main()
