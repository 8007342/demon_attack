#!/usr/bin/env python3
"""Numerical adapter to the existing numpy/scipy music synthesizer.

Lua owns job orchestration. This renders a composed 96-bar guide, not an
extended copy of the old eight-bar shipped loop. No external model is loaded.
"""
import argparse
import json
import sys
from pathlib import Path
import numpy as np
import soundfile as sf
sys.path.insert(0, str(Path(__file__).resolve().parent))
import music_guide as synth
import music_motifs as motifs

ROOT = Path(__file__).resolve().parents[1]

def events_for(level, block, theme):
    tier = (1, 2, 2, 3, 2, 3, 1, 2, 3, 4, 4, 2)[block]
    ev = motifs.battle_bass(level, tier)
    ev += motifs.battle_pads(level, tier)
    if block not in (0, 11):
        ev += motifs.battle_rhythm(level, tier)
        ev += motifs.battle_drums(level, tier)
    else:
        # Arrival/exit leave space for radio and for a sustained bridge pivot.
        ev += [(b, 3.8, p, 58, 'clean') for b, _, p, _, _ in motifs.battle_rhythm(level, 1) if b % 4 == 0]
        if block == 0 and level > 1:
            ev += [(b,d,p,int(v*.65),i) for b,d,p,v,i in motifs.battle_drums(level,1) if b >= 16]
    # A recurring original campaign theme appears in each key. Its rhythm is
    # the same; placement, register, instrument and answer develop by section.
    notes = [motifs.p(n) for n in theme]
    inst = 'clean' if block in (0, 6, 11) else 'lead'
    for bar in (0, 2, 4, 6):
        if block in (4, 5):
            pitches = list(reversed(notes))
        elif block in (6, 7):
            pitches = [notes[0],notes[3],notes[2],notes[0]]
        else:
            pitches = notes
        offset = 12 if block in (8, 9, 10) else 0
        beat = bar * 4
        for pitch, duration in zip(pitches, (1.5,.5,1,1)):
            ev.append((beat,duration*.93,pitch+offset,84 if block<8 else 105,inst))
            if block in (9,10):
                ev.append((beat,duration*.9,pitch,78,'lead2'))
            beat += duration
    # The established level hook answers the shared campaign theme, and never
    # occupies exactly the same phrases throughout the entire arrangement.
    if block in (2,3,5,7,10):
        ev += [(b,d,p,v,i) for b,d,p,v,i in motifs.battle_lead(level,tier) if 16 <= b < 32]
    if block in (6,7):
        ev = [(b,d,p,int(v*.75),i) for b,d,p,v,i in ev]
    return ev

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--level',type=int,required=True,choices=range(1,6))
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    plan=json.loads((ROOT/'art/music/campaign.json').read_text())
    level=plan['levels'][args.level-1]
    bpm=motifs.bpm_of(f'l{args.level}-t1')
    samples_per_block=8*motifs.BAR_SAMPLES[args.level]
    args.out.parent.mkdir(parents=True,exist_ok=True)
    with sf.SoundFile(args.out,'w',samplerate=synth.SR,channels=2,format='FLAC',subtype='PCM_24') as f:
        for block in range(12):
            audio=synth.render(events_for(args.level,block,level['theme']),32,
                style=motifs.BATTLE[args.level],key=('campaign-v1',args.level,block),tail_s=0,bpm=bpm)
            assert len(audio)==samples_per_block
            fade=min(240,len(audio)//2)
            audio[:fade] *= np.linspace(0,1,fade)[:,None]
            audio[-fade:] *= np.linspace(1,0,fade)[:,None]
            f.write(audio*.78)
    info=sf.info(args.out)
    assert info.frames==96*motifs.BAR_SAMPLES[args.level]
    meta={'schema':'demon-attack.campaign-guide/v1','level':args.level,'bars':96,
        'bar_samples':motifs.BAR_SAMPLES[args.level],'samples':info.frames,'sample_rate':synth.SR,
        'bpm':bpm,'seconds':info.duration,'sections':plan['sections'],
        'source':'tools/music_motifs.py and tools/campaign_guide.py','model':None}
    args.out.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
    print(f'{args.out}: {info.duration:.3f}s, 96 composed bars',flush=True)

if __name__=='__main__': main()
