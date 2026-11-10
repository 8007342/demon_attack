#!/usr/bin/env python3
"""Deterministic synthesizer for the motif guides, accent sprites and the cackle.

  * guide(name)   renders a cue's motif events (tools/music_motifs.py) to a
                  48 kHz stereo guide: distorted double-tracked guitars, bass,
                  drum kit, lead, brass, choir/organ/bell. ACE-Step 1.5 then
                  re-performs it (audio-to-audio), so all tiers of a level keep
                  the same riff, harmony and bar grid.
  * accents(level) renders that level's accent sprite (dive, last stand, hatch,
                  reinforcements; one 3-beat slot each) in its motif and
                  instrumentation; shipped directly.
  * cackle()      layered formant synthesis of a cartoonish demonic laugh.

Everything is numpy/scipy with fixed seeds: the same code gives the same audio.
"""
from __future__ import annotations

import math

import numpy as np
from scipy import signal

import music_motifs as motifs

SR = 48000
BEAT = 0.5  # 120 BPM default; render() takes the cue's tempo
TAU = 2 * np.pi


def hz(pitch):
    return 440.0 * 2 ** ((pitch - 69) / 12)


def rng(*key):
    seed = 0
    for k in key:
        for ch in str(k):
            seed = (seed * 131 + ord(ch)) % 2**31
    return np.random.default_rng(seed)


def env_adsr(n, a=0.005, d=0.1, s=0.7, r=0.05, hold=None):
    """Attack/decay/sustain over `hold` samples, then release (total n)."""
    hold = n if hold is None else min(hold, n)
    e = np.zeros(n)
    na, nd, nr = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    t = np.arange(n)
    e = np.where(t < na, t / na, s + (1 - s) * np.exp(-(t - na) / nd))
    rel = t >= hold
    if rel.any():
        level = e[min(hold, n - 1)]
        e[rel] = level * np.exp(-(t[rel] - hold) / nr)
    return e


def saw(freq, n, phase=0.0, vib=None):
    f = np.full(n, float(freq)) if np.isscalar(freq) else freq
    if vib is not None:
        f = f * vib
    ph = np.cumsum(f) / SR + phase
    x = 2 * (ph % 1.0) - 1
    # PolyBLEP-lite: soften the reset to cut the worst aliasing.
    dt = f / SR
    frac = ph % 1.0
    x -= np.where(frac < dt, (frac / dt - 1) ** 2, 0) - np.where(frac > 1 - dt, ((frac - 1) / dt + 1) ** 2, 0)
    return x


def biquad(kind, f0, q=0.707, gain_db=0.0):
    w = TAU * f0 / SR
    alpha = math.sin(w) / (2 * q)
    cw = math.cos(w)
    A = 10 ** (gain_db / 40)
    if kind == 'lp':
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]; a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'hp':
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]; a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'bp':
        b = [alpha, 0, -alpha]; a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'peak':
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]; a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    else:
        raise ValueError(kind)
    return np.array(b) / a[0], np.array(a) / a[0]


def filt(x, kind, f0, q=0.707, gain_db=0.0):
    b, a = biquad(kind, f0, q, gain_db)
    return signal.lfilter(b, a, x, axis=0)


def noise(n, key):
    return rng(*key).standard_normal(n)


# ------------------------------------------------------------------ voices
def amp_sim(x, drive, tone=4200, scoop=True):
    x = filt(x, 'hp', 110)
    x = filt(x, 'peak', 900, 0.8, 4)  # tube-screamer style mid push before clipping
    y = np.tanh(drive * x)
    y = np.tanh(1.6 * y + 0.1 * y ** 2)  # second stage, slight asymmetry
    # Cabinet: 4x12-ish band limit with a resonance and the scooped mids.
    y = filt(y, 'hp', 85)
    y = filt(y, 'peak', 120, 1.0, 3)
    if scoop:
        y = filt(y, 'peak', 520, 0.9, -5)
    y = filt(y, 'peak', 2400, 1.2, 3)
    y = filt(filt(y, 'lp', tone, 0.8), 'lp', tone * 1.25, 0.6)
    return y


def guitar(pitch, dur_s, vel, kind, key, drive=18.0, tone=4200, scoop=True):
    """Power chord (root, fifth, octave) or triad; palm mute; tremolo picking."""
    tail = 0.12 if kind == 'mute' else 0.35
    n = int((dur_s + tail) * SR)
    hold = int(dur_s * SR)
    r = rng(*key)
    if kind.startswith('chord'):
        third = 3 if kind == 'chordm' else 4
        notes = [pitch, pitch + 7, pitch + 12, pitch + 12 + third, pitch + 19]
    elif kind == 'clean':
        notes = [pitch]
    else:
        notes = [pitch, pitch + 7, pitch + 12]
    x = np.zeros(n)
    for i, nt in enumerate(notes):
        f = hz(nt) * (1 + r.uniform(-0.0015, 0.0015))
        x += saw(f, n, r.uniform()) * (1.0 if i == 0 else 0.8)
    if kind == 'mute':
        e = env_adsr(n, 0.002, 0.07, 0.15, 0.03, hold)
        x = filt(x * e, 'lp', 900)
        y = amp_sim(x, drive * 1.2, tone, scoop)
    elif kind == 'trem':
        # 16th-note re-picks.
        t = np.arange(n) / SR
        pick = np.exp(-(t % 0.125) / 0.05) * 0.6 + 0.4
        e = env_adsr(n, 0.002, 0.3, 0.8, 0.06, hold) * pick
        y = amp_sim(x * e, drive * 1.3, tone, scoop)
    elif kind == 'clean':
        e = env_adsr(n, 0.002, 0.4, 0.3, 0.3, hold)
        y = filt(filt(x * e, 'lp', 2600), 'hp', 150) * 0.5
        y = np.tanh(1.5 * y)
    else:
        e = env_adsr(n, 0.003, 0.5, 0.75, 0.08, hold)
        y = amp_sim(x * e, drive * (0.6 if kind.startswith('chord') else 1.0), tone, scoop)
    return y * (vel / 127) * 0.35


def bass_voice(pitch, dur_s, vel, drive=2.5):
    n = int((dur_s + 0.08) * SR)
    f = hz(pitch)
    x = saw(f, n) * 0.6 + np.sign(np.sin(TAU * f * np.arange(n) / SR)) * 0.3 + np.sin(TAU * f * np.arange(n) / SR) * 0.8
    x *= env_adsr(n, 0.003, 0.25, 0.7, 0.05, int(dur_s * SR))
    x = filt(np.tanh(drive * x), 'lp', 1400, 0.9)
    return x * (vel / 127) * 0.55


def lead_voice(pitch, dur_s, vel, key, drive=10.0, tone=5000):
    n = int((dur_s + 0.3) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.012 * np.sin(TAU * 5.6 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
    # Pick-attack bend from a quarter-tone below.
    bend = 1 - 0.015 * np.exp(-t / 0.03)
    x = saw(hz(pitch), n, vib=vib * bend) + 0.5 * saw(hz(pitch) * 1.003, n, 0.3, vib=vib * bend)
    x *= env_adsr(n, 0.004, 0.6, 0.85, 0.12, int(dur_s * SR))
    y = amp_sim(x, drive, tone, scoop=False)
    return y * (vel / 127) * 0.33


def brass_voice(pitch, dur_s, vel, key):
    n = int((dur_s + 0.2) * SR)
    t = np.arange(n) / SR
    r = rng(*key)
    vib = 1 + 0.004 * np.sin(TAU * 5.2 * t + r.uniform(0, 6))
    x = sum(saw(hz(pitch) * d, n, r.uniform(), vib=vib) for d in (0.997, 1.0, 1.004))
    e = env_adsr(n, 0.035, 0.25, 0.8, 0.12, int(dur_s * SR))
    # Brightness follows the envelope (brass "blat").
    bright = filt(x, 'lp', 1800 + 2500 * (vel / 127), 0.8)
    dull = filt(x, 'lp', 900, 0.7)
    blend = np.clip(env_adsr(n, 0.02, 0.15, 0.4, 0.1, int(dur_s * SR)), 0, 1)
    y = (bright * blend + dull * (1 - blend)) * e
    y = filt(y, 'peak', 1200, 1.0, 4)
    return np.tanh(1.2 * y) * (vel / 127) * 0.22


def formant_voice(pitch, dur_s, vel, key, vowel='a', attack=0.25):
    n = int((dur_s + 0.4) * SR)
    t = np.arange(n) / SR
    r = rng(*key)
    out = np.zeros(n)
    form = {'a': [(700, 1.0), (1150, 0.6), (2600, 0.25)], 'o': [(450, 1.0), (800, 0.6), (2830, 0.15)], 'u': [(325, 1.0), (700, 0.4), (2530, 0.1)]}[vowel]
    for d in (0.994, 1.0, 1.006):
        vib = 1 + 0.006 * np.sin(TAU * (4.8 + r.uniform(-.4, .4)) * t + r.uniform(0, 6))
        src = saw(hz(pitch) * d, n, r.uniform(), vib=vib)
        for f, g in form:
            out += filt(src, 'bp', f, 6) * g
    out *= env_adsr(n, attack, 0.5, 0.9, 0.35, int(dur_s * SR))
    return out * (vel / 127) * 0.35


def organ_voice(pitch, dur_s, vel):
    n = int((dur_s + 0.15) * SR)
    t = np.arange(n) / SR
    f = hz(pitch)
    x = sum(g * np.sin(TAU * f * h * t) for h, g in ((0.5, .7), (1, 1), (2, .6), (3, .4), (4, .3), (6, .15)))
    x *= env_adsr(n, 0.02, 0.3, 0.95, 0.1, int(dur_s * SR))
    return np.tanh(0.8 * x) * (vel / 127) * 0.16


def bell_voice(pitch, dur_s, vel):
    dur = max(dur_s, 1.5) + 1.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(pitch)
    x = sum(g * np.sin(TAU * f * h * t) * np.exp(-t / dcy) for h, g, dcy in ((0.5, .6, 2.5), (1, 1, 1.8), (2.76, .5, .9), (5.4, .3, .5), (8.93, .2, .3)))
    return x * (vel / 127) * 0.22


def timp_voice(pitch, vel, key):
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    f = hz(pitch) * (1 + 0.08 * np.exp(-t / 0.05))
    x = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.5) + 0.3 * filt(noise(n, key), 'lp', 800) * np.exp(-t / 0.04)
    return x * (vel / 127) * 0.7


def drum(name, vel, key):
    r = rng(*key)
    v = vel / 127
    if name == 'kick':
        n = int(0.4 * SR); t = np.arange(n) / SR
        f = 48 + 110 * np.exp(-t / 0.025)
        x = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.18)
        x += 0.5 * filt(r.standard_normal(n), 'hp', 2500) * np.exp(-t / 0.004)  # beater click
        return np.tanh(1.5 * x) * v * 0.9
    if name in ('snare', 'snareroll'):
        n = int(0.35 * SR); t = np.arange(n) / SR
        body = np.sin(TAU * 185 * t) * np.exp(-t / 0.05) + 0.5 * np.sin(TAU * 330 * t) * np.exp(-t / 0.03)
        wires = filt(filt(r.standard_normal(n), 'hp', 1200), 'lp', 9000) * np.exp(-t / (0.12 if name == 'snare' else 0.06))
        x = 0.6 * body + 0.8 * wires
        return np.tanh(1.3 * x) * v * (0.6 if name == 'snare' else 0.4)
    if name in ('hat', 'ohat'):
        n = int((0.06 if name == 'hat' else 0.35) * SR); t = np.arange(n) / SR
        x = filt(r.standard_normal(n), 'hp', 7500) * np.exp(-t / (0.018 if name == 'hat' else 0.15))
        return x * v * 0.3
    if name in ('crash', 'china'):
        n = int(2.0 * SR); t = np.arange(n) / SR
        x = filt(r.standard_normal(n), 'hp', 3500 if name == 'crash' else 2000) * np.exp(-t / (0.9 if name == 'crash' else 0.5))
        if name == 'china':
            x = np.tanh(2 * x)
        return x * v * 0.3
    if name == 'ride':
        n = int(0.8 * SR); t = np.arange(n) / SR
        x = filt(r.standard_normal(n), 'hp', 6000) * np.exp(-t / 0.3) * 0.5
        x += sum(np.sin(TAU * f * t) * np.exp(-t / 0.4) for f in (3150, 4870, 6230)) * 0.08
        return x * v * 0.3
    if name == 'tom':
        n = int(0.5 * SR); t = np.arange(n) / SR
        f = 110 * (1 + 0.5 * np.exp(-t / 0.04))
        return np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.2) * v * 0.7
    raise ValueError(name)


TOM_PITCH = {41: 82, 43: 98, 45: 115}

# Per-genre production: (guitar drive, cab tone, scooped mids, guitar level, room)
GENRE = {
    'punk': dict(drive=12.0, tone=4800, scoop=False, gtr=1.0, room=0.12),
    'rock': dict(drive=8.0, tone=5200, scoop=False, gtr=0.9, room=0.18),
    'metal': dict(drive=24.0, tone=4500, scoop=True, gtr=1.0, room=0.15),
    'doom': dict(drive=30.0, tone=3200, scoop=True, gtr=1.1, room=0.3),
    'deathdoom': dict(drive=34.0, tone=3600, scoop=True, gtr=1.1, room=0.28),
    'march': dict(drive=6.0, tone=4000, scoop=False, gtr=0.6, room=0.35),
    # Round 3 battle styles: hotter gain, brighter cab, tight room.
    'battlepunk': dict(drive=22.0, tone=5200, scoop=False, gtr=1.1, room=0.12),
    'powermetal': dict(drive=20.0, tone=5400, scoop=True, gtr=1.0, room=0.2),
    'battle': dict(drive=28.0, tone=5000, scoop=True, gtr=1.1, room=0.16),
    'doombattle': dict(drive=32.0, tone=4200, scoop=True, gtr=1.15, room=0.28),
    'blackened': dict(drive=36.0, tone=4800, scoop=True, gtr=1.1, room=0.3),
}


def reverb_ir(seconds, key):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    r = rng('ir', *key)
    ir = r.standard_normal((n, 2)) * np.exp(-t / (seconds / 6.9))[:, None]
    ir[:int(0.012 * SR)] = 0
    return filt(ir, 'lp', 6000)


# Bus levels of the guide mix. The metal-v2 round renders guides with the
# drums forward (MIX_V2) so that a strong audio-to-audio re-performance keeps
# the kit's pulse and the bar grid while it replaces the guitars' timbre.
MIX = {'drums': 1.0, 'gtr': 0.9, 'bass': 0.9, 'lead': 0.8, 'pad': 0.7}
MIX_V2 = {'drums': 1.8, 'gtr': 0.55, 'bass': 0.9, 'lead': 0.7, 'pad': 0.7}


def render(events, beats, style='rock', key=('guide',), tail_s=2.0, bpm=120, mix=None):
    """Mix events into stereo at `bpm`; returns float array (n, 2). The length
    is round(beats * 60 / bpm * SR) samples (+ tail), so windows cut by the
    pipeline at the same rounding are sample-exact."""
    g = GENRE.get(style, GENRE['rock'])
    BEAT = 60.0 / bpm
    n = int(round(beats * BEAT * SR)) + int(tail_s * SR)
    bus = {k: np.zeros((n, 2)) for k in ('drums', 'gtr', 'bass', 'lead', 'pad')}

    def place(target, x, t, pan=0.0, width=0.0):
        s = int(round(t * BEAT * SR))
        if s >= n:
            return
        x = x[:n - s]
        lgain = math.cos((pan + 1) * math.pi / 4); rgain = math.sin((pan + 1) * math.pi / 4)
        target[s:s + len(x), 0] += x * lgain * 1.414
        target[s:s + len(x), 1] += x * rgain * 1.414

    for idx, (b, d, pitch, vel, inst) in enumerate(events):
        k = (*key, idx, inst, pitch, b)
        ds = d * BEAT
        if inst in ('kick', 'snare', 'snareroll', 'hat', 'ohat', 'crash', 'china', 'ride'):
            pan = {'hat': .3, 'ohat': .3, 'ride': -.35, 'crash': -.4 if pitch == 49 else .4, 'china': .45}.get(inst, 0)
            place(bus['drums'], drum(inst, vel, k), b, pan)
        elif inst == 'tom':
            n0 = int(0.5 * SR); t = np.arange(n0) / SR
            f = TOM_PITCH.get(pitch, 100) * (1 + 0.5 * np.exp(-t / 0.04))
            place(bus['drums'], np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.2) * vel / 127 * 0.7, b, (pitch - 43) / 6)
        elif inst in ('gtr', 'mute', 'chord', 'chordm', 'trem', 'clean'):
            # Double-tracked: two independent takes hard left and right.
            for side, pan, off in ((0, -.85, 0.0), (1, .85, 0.006)):
                x = guitar(pitch, ds, vel, inst, (*k, side), g['drive'], g['tone'], g['scoop']) * g['gtr']
                place(bus['gtr'], x, b + off / BEAT, pan)
        elif inst == 'bass':
            place(bus['bass'], bass_voice(pitch, ds, vel), b)
        elif inst in ('lead', 'lead2'):
            place(bus['lead'], lead_voice(pitch, ds, vel, k, tone=g['tone'] + 800), b, .15 if inst == 'lead' else -.25)
        elif inst == 'brass':
            place(bus['lead'], brass_voice(pitch, ds, vel, k), b, (pitch - 64) / 40)
        elif inst == 'choir':
            place(bus['pad'], formant_voice(pitch, ds, vel, k, 'a' if (pitch // 3) % 2 else 'o'), b, ((pitch % 5) - 2) / 4)
        elif inst == 'organ':
            place(bus['pad'], organ_voice(pitch, ds, vel), b, ((pitch % 3) - 1) / 3)
        elif inst == 'bell':
            place(bus['pad'], bell_voice(pitch, ds, vel), b, .2)
        elif inst == 'timp':
            place(bus['drums'], timp_voice(pitch, vel, k), b, -.2)
        elif inst == 'pad':
            place(bus['pad'], formant_voice(pitch, ds, vel, k, 'u', 0.4), b)
        elif inst == 'strings':
            place(bus['pad'], strings_voice(pitch, ds, vel, k), b, ((pitch % 7) - 3) / 4)
        elif inst == 'vocalise':
            place(bus['lead'], vocalise_voice(pitch, ds, vel, k), b, 0.0)
        elif inst == 'hey':
            place(bus['drums'], hey_voice(vel, k), b, 0.0)
        else:
            raise ValueError(inst)
    # Lead delay (dotted eighth) for the solo voice.
    d = int(0.375 * SR)
    lead = bus['lead'].copy()
    lead[d:] += 0.25 * bus['lead'][:-d][:, ::-1]
    lv = mix or MIX
    mix = (bus['drums'] * lv['drums'] + bus['gtr'] * lv['gtr'] + bus['bass'] * lv['bass'] + lead * lv['lead'] + bus['pad'] * lv['pad'])
    wet = signal.fftconvolve(bus['drums'] * 0.5 + lead * 0.8 + bus['pad'] * 1.0 + bus['gtr'] * 0.2, reverb_ir(2.2, key), axes=0)[:n]
    mix = mix + g['room'] * wet
    # Bus glue: gentle compression via tanh, then loudness-ish normalisation.
    mix = np.tanh(mix / (np.percentile(np.abs(mix), 99.9) + 1e-9) * 1.1) * 0.8
    return mix


def style_of(name):
    if name.startswith('l') and name[1].isdigit():
        return motifs.BATTLE[int(name[1])]
    return 'march' if name.split('-')[0] in ('levelclear', 'victory', 'finale') else 'metal'


def guide(name, pre_bars=2, post_bars=2, mix=None):
    """Guide for one cue. Loops are rendered with `pre_bars` of the loop's end
    before and `post_bars` of its start after, so the window that the pipeline
    cuts (beat 4*pre_bars onwards) is the loop itself in musical context."""
    events, beats = motifs.cue_events(name)
    style = style_of(name)
    bpm = motifs.bpm_of(name)
    loop = name.endswith(('t1', 't2', 't3', 't4')) or name == 'alienwin' or name.endswith('outro')
    if loop:
        pre = [(b - beats + 4 * pre_bars, d, pt, v, i) for b, d, pt, v, i in events if b >= beats - 4 * pre_bars]
        mid = [(b + 4 * pre_bars, d, pt, v, i) for b, d, pt, v, i in events]
        post = [(b + beats + 4 * pre_bars, d, pt, v, i) for b, d, pt, v, i in events if b < 4 * post_bars]
        total = beats + 4 * (pre_bars + post_bars)
        audio = render(pre + mid + post, total, style, (name,), tail_s=0.0, bpm=bpm, mix=mix)
        offset = 4 * pre_bars
    else:
        # One-shot and tail cues: one bar of count-in (snare pickup) before.
        lead_in = [(0, .2, 38, 60, 'snare'), (1, .2, 38, 60, 'snare'), (2, .2, 38, 70, 'snare'), (3, .2, 38, 80, 'snare')]
        total = beats + 4 + 4
        shifted = [(b + 4, d, pt, v, i) for b, d, pt, v, i in events]
        audio = render(lead_in + shifted, total, style, (name,), tail_s=0.0, bpm=bpm, mix=mix)
        offset = 4
    return audio, offset * 60.0 / bpm, beats


SLOT_SECONDS = 1.5


def accents(level):
    """Accent sprite: one 1.5 s slot per accent, in ACCENTS order, played at
    the level's tempo."""
    style = motifs.BATTLE[level]
    bpm = motifs.BPM[level]
    slot_beats = SLOT_SECONDS * bpm / 60.0
    out = []
    for name in motifs.ACCENTS:
        ev = motifs.accent_events(level, name)
        x = fit(render(ev, slot_beats, style, ('accent', level, name), tail_s=0.0, bpm=bpm), int(SLOT_SECONDS * SR))
        # Fade the last 150 ms so each slot ends silent.
        f = int(0.15 * SR)
        x[-f:] *= np.linspace(1, 0, f)[:, None] ** 2
        out.append(x)
    return np.concatenate(out)


def fit(x, n):
    return x[:n] if len(x) >= n else np.concatenate([x, np.zeros((n - len(x), 2))])


def strings_voice(pitch, dur_s, vel, key):
    """String ensemble: detuned saws, slow bow attack, gentle vibrato."""
    n = int((dur_s + 0.35) * SR)
    t = np.arange(n) / SR
    r = rng(*key)
    x = np.zeros(n)
    for d in (0.993, 0.998, 1.002, 1.007):
        vib = 1 + 0.004 * np.sin(TAU * (5.0 + r.uniform(-.5, .5)) * t + r.uniform(0, 6))
        x += saw(hz(pitch) * d, n, r.uniform(), vib=vib)
    x = filt(filt(x, 'lp', 3200, 0.7), 'hp', 120)
    x *= env_adsr(n, min(0.12, dur_s / 3), 0.4, 0.9, 0.3, int(dur_s * SR))
    return x * (vel / 127) * 0.12


def vocalise_voice(pitch, dur_s, vel, key):
    """Wordless soprano 'ah' with operatic vibrato (formant synthesis)."""
    n = int((dur_s + 0.4) * SR)
    t = np.arange(n) / SR
    r = rng(*key)
    vib = 1 + 0.018 * np.sin(TAU * 5.6 * t) * np.clip((t - 0.12) / 0.25, 0, 1)
    src = saw(hz(pitch), n, r.uniform(), vib=vib) + 0.4 * np.sin(TAU * np.cumsum(hz(pitch) * vib) / SR)
    out = np.zeros(n)
    for f, g, q in ((850, 1.0, 5), (1250, 0.55, 6), (2900, 0.35, 8), (3500, 0.2, 9)):
        out += filt(src, 'bp', f, q) * g
    out *= env_adsr(n, 0.09, 0.6, 0.9, 0.3, int(dur_s * SR))
    return out * (vel / 127) * 0.4


def hey_voice(vel, key):
    """Gang shout "hey!": several voices, aspirated onset, /e/ formants."""
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    r = rng('hey', *key)
    out = np.zeros(n)
    for v in range(6):
        f0 = r.uniform(140, 230)
        off = int(r.uniform(0, 0.015) * SR)
        ph = np.cumsum(np.full(n, f0) * (1 - 0.12 * t / 0.3)) / SR
        src = ((ph % 1.0) ** 3) * 2 - 0.5 + 0.4 * r.standard_normal(n) * np.exp(-t / 0.03)
        voice = sum(filt(src, 'bp', f, q) * g for f, g, q in ((550, 1.0, 5), (1850, 0.6, 6), (2600, 0.3, 7)))
        e = np.clip(t / 0.01, 0, 1) * np.exp(-np.clip(t - 0.08, 0, None) / 0.05)
        out[off:] += (voice * e)[:n - off]
    return np.tanh(out * 1.5) * (vel / 127) * 0.5


def cackle(seconds=3.0):
    """Cartoon demon laugh: 'HA-ha-ha-ha-ha... haaa', pitch falling, with a
    low growl double an octave down and a ring-modulated sheen. Formant
    synthesis of a glottal pulse train; aspirated 'h' onsets."""
    n = int(seconds * SR)
    out = np.zeros((n, 2))
    r = rng('cackle')
    # Syllable onsets (s), accelerating then a long final "haaa".
    # Laughter: short voiced bursts with clear gaps, ~5 per second.
    onsets = [0.0, 0.25, 0.47, 0.67, 0.86, 1.04, 1.22, 1.41, 1.61, 1.84]
    lengths = [0.13, 0.12, 0.11, 0.1, 0.1, 0.1, 0.1, 0.11, 0.12, 0.85]
    for i, (t0, ln) in enumerate(zip(onsets, lengths)):
        m = int((ln + 0.1) * SR)
        t = np.arange(m) / SR
        # Pitch: each syllable falls; the series falls overall (hysterical cackle).
        base = 330 * 0.94 ** i if i < 9 else 260
        f0 = base * (1.18 - 0.25 * np.clip(t / ln, 0, 1))
        if i == 9:
            f0 = base * (1.25 - 0.45 * np.clip(t / ln, 0, 1)) * (1 + 0.015 * np.sin(TAU * 5 * t))
        f0 *= 1 + 0.01 * r.standard_normal(m).cumsum() / np.sqrt(np.arange(1, m + 1))  # jitter
        ph = np.cumsum(f0) / SR
        pulse = (ph % 1.0) ** 6 * 2 - 0.3  # glottal-ish pulse
        voice = np.zeros(m)
        vowel = [(780, 1.0, 8), (1220, 0.7, 9), (2600, 0.35, 12), (3400, 0.15, 12)]  # "ah"
        for f, gn, q in vowel:
            voice += filt(pulse, 'bp', f, q) * gn
        e = np.clip(t / 0.025, 0, 1) * np.exp(-np.clip(t - ln * 0.7, 0, None) / (0.02 if i < 9 else 0.3))
        h = filt(r.standard_normal(m), 'bp', 1500, 1.0) * np.clip(1 - t / 0.04, 0, 1) * 0.15  # aspirated 'h' under the vowel onset
        syl = voice * e + h
        # Demon double: an octave down with growl (sub-harmonic + saturation).
        ph2 = np.cumsum(f0 / 2) / SR
        growl = np.tanh(3 * (((ph2 % 1.0) ** 4) * 2 - 0.4) * (1 + 0.5 * np.sin(TAU * 31 * t)))
        g2 = np.zeros(m)
        for f, gn, q in [(520, 1.0, 6), (900, 0.6, 6), (2400, 0.2, 8)]:
            g2 += filt(growl, 'bp', f, q) * gn
        syl2 = g2 * e * 0.7
        s = int(t0 * SR)
        seg = slice(s, min(n, s + m))
        k = seg.stop - seg.start
        out[seg, 0] += (syl[:k] * 1.0 + syl2[:k] * 0.8)
        out[seg, 1] += (syl[:k] * 0.9 + syl2[:k] * 0.9)
    # Cavernous room + a slight ring-mod sheen.
    t = np.arange(n) / SR
    out += 0.15 * out * np.sin(TAU * 90 * t)[:, None]
    wet = signal.fftconvolve(out, reverb_ir(1.8, ('cackle',)), axes=0)[:n]
    out = out + 0.35 * wet
    out = filt(out, 'hp', 70)
    f = int(0.3 * SR)
    out[-f:] *= np.linspace(1, 0, f)[:, None] ** 2
    return out / (np.abs(out).max() + 1e-9) * 0.9
