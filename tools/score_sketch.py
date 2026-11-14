#!/usr/bin/env python3
"""Composition sketch of a committed score through the old guide synth.

This is for judging the ARRANGEMENT (form, parts, voicing, density) before the
real-instrument studio renders it. It is not the sound: the guide synth is the
one the operator rejected. Output stays out of the repo (persistent cache).

Run:  uv run --no-project --with numpy --with scipy --with soundfile \
        python -I tools/score_sketch.py --out ~/.cache/demon-attack/scores/l3-sketch.flac
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
import music_guide as synth  # noqa: E402
import score_l3 as score  # noqa: E402

DRUM = {36: 'kick', 38: 'snare', 42: 'hat', 46: 'ohat', 49: 'crash', 57: 'crash', 51: 'ride', 53: 'ride',
        52: 'china', 48: 'tom', 45: 'tom', 43: 'tom', 41: 'tom'}
PART_INST = {'bass': 'bass', 'lead': 'lead', 'lead2': 'lead2', 'lead-clean': 'clean', 'clean': 'clean',
             'choir': 'choir', 'organ': 'organ', 'brass': 'brass', 'strings': 'strings', 'timpani': 'timp'}
TAIL_S = 2.5


def sketch_events():
    score.compose()
    ev = []
    for b, d, q, v, part in score.EV:
        if part == 'drums':
            ev.append((b, d, q, v, DRUM[q]))
        elif part in PART_INST:
            ev.append((b, d, q, v, PART_INST[part]))
    # The synth's guitar voice builds the power chord from the root and
    # double-tracks it itself, so feed it the left take's roots only.
    for b, d, r, v, part in score.ROOT_LOG:
        if part == 'gtrL':
            ev.append((b, d, r, v, 'gtr'))
        elif part == 'gtrL-pm':
            ev.append((b, d, r, v, 'mute'))
    return ev


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    ev = sketch_events()
    # One call for the whole piece: the synth normalises each call to its own
    # 99.9th percentile, so per-block renders would flatten the dynamic arc.
    out = synth.render(ev, score.BARS * 4, style='battle', key=('score-sketch',), tail_s=TAIL_S, bpm=score.BPM)
    peak = float(np.max(np.abs(out)))
    if peak > 0.89:
        out *= 0.89 / peak
    args.out.parent.mkdir(parents=True, exist_ok=True)
    sf.write(args.out, out, synth.SR, subtype='PCM_24')
    print(f'{args.out}: {len(out) / synth.SR:.2f} s, peak before trim {peak:.3f}')


if __name__ == '__main__':
    main()
