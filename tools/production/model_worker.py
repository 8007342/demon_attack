#!/usr/bin/env python3
"""One resident process for required Kokoro/Chatterbox model libraries.

Lua owns scheduling/checkpoints; this local-only HTTP adapter retains model
instances between requests instead of reloading gigabytes for every short line.
"""
import contextlib
import importlib.util
import json
import hashlib
import os
import re
import subprocess
import sys
import time
import traceback
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

path=Path(__file__).resolve().parents[1]/'comms_pipeline.py'
spec=importlib.util.spec_from_file_location('comms_pipeline',path)
pipeline=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipeline)
original_kokoro=pipeline.Kokoro
original_chatterbox=pipeline.load_chatterbox
models={}
threads=int(os.environ.get('COMMS_THREADS','20'))
if not 1 <= threads <= (os.cpu_count() or 1):
    raise ValueError('COMMS_THREADS must fit the available CPU count')
def kokoro(config):
    if 'kokoro' not in models: models['kokoro']=original_kokoro(config)
    return models['kokoro']
def chatterbox(config,threads):
    if 'chatterbox' not in models: models['chatterbox']=original_chatterbox(config,threads)
    return models['chatterbox']
pipeline.Kokoro=kokoro;pipeline.load_chatterbox=chatterbox

def produce(clip):
    import numpy as np
    import soundfile as sf
    cast, lines=pipeline.load_specs()
    entries={i:(trigger,kind,line) for i,trigger,kind,line in pipeline.clip_entries(lines)}
    trigger,kind,line=entries[clip]
    common=['--exact','--limit','1','--threads',str(threads),'--performed-demons']
    pipeline.main(['refs','--only',line['speaker'],*common])
    for stage in ('voices','expressive','radio'):
        pipeline.main([stage,'--only',clip,*common])
    record=json.loads((pipeline.WORK/'expressive.json').read_text())[clip]
    if record['error']: raise RuntimeError(record['error'])
    meta=json.loads((pipeline.WORK/'radio.json').read_text())[clip]
    out=pipeline.WORK/'candidates'/clip;out.mkdir(parents=True,exist_ok=True)
    masters={}
    for name,folder in (('baseline','raw'),('expressive','expressive'),('voice','performed')):
        source=pipeline.WORK/folder/f'{clip}.wav'
        audio=pipeline.read_wav(source)
        gain=min(1.,.98/max(1e-9,float(np.abs(audio).max())))
        target=out/f'{name}.flac';temporary=out/f'{name}.tmp.flac'
        sf.write(temporary,audio*gain,pipeline.SR,subtype='PCM_24');os.replace(temporary,target)
        masters[name]={'path':str(target),'sha256':pipeline.sha256(target),
            'float_source_sha256':pipeline.sha256(source),'gain':gain,'pcm_bits':24}
    ogg=out/'radio.ogg'
    subprocess.run(['/home/linuxbrew/.linuxbrew/bin/ffmpeg','-v','error','-y','-i',
        str(pipeline.WORK/'radio'/f'{clip}.wav'),'-map_metadata','-1',
        '-c:a','libopus','-b:a','48k','-vbr','on','-application','audio',str(ogg)],check=True)
    meta.update({'schema':'demon-attack.voice-candidate/v1','id':clip,'text':line.get('text') or line['gloss'],
        'review':'pending listening and contextual mouth review','masters':masters,
        'performance':record,'seed':pipeline.seed_of('cb:'+clip),
        'input_hashes':{str(path.relative_to(pipeline.ROOT)):pipeline.sha256(path)
            for path in (pipeline.CAST,pipeline.LINES,pipeline.AUDIO,pipeline.ROOT/'art/comms/demon-delivery.json')},
        'models':{'kokoro':pipeline.audio_spec()['kokoro'],
            'chatterbox':{k:pipeline.audio_spec()['chatterbox'][k] for k in ('repo','revision')}},
        'codec':{'name':'opus','bitrate_kbps':48,'sha256':pipeline.sha256(ogg)}})
    temporary=out/'metadata.tmp.json';temporary.write_text(json.dumps(meta,indent=2)+'\n')
    os.replace(temporary,out/'metadata.json')
    return str(out)
last=time.monotonic()
class Handler(BaseHTTPRequestHandler):
    def answer(self,status,value):
        data=json.dumps(value).encode();self.send_response(status)
        self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)))
        self.end_headers();self.wfile.write(data)
    def do_GET(self):
        self.answer(200,{'status':'ready','models':list(models),'adapter':'demon-attack-voice-worker/v1'})
    def do_POST(self):
        global last
        if self.path!='/render': return self.answer(404,{'error':'unknown endpoint'})
        try:
            size=int(self.headers.get('Content-Length','0'))
            if not 0<size<4096: raise ValueError('invalid request size')
            body=json.loads(self.rfile.read(size));mode=body['mode'];clip=body['id']
            if mode not in ('refs','voices','expressive','produce'): raise ValueError('unsupported model stage')
            if not re.fullmatch(r'[A-Za-z0-9_.-]+',clip): raise ValueError('invalid clip id')
            start=time.monotonic()
            with contextlib.redirect_stdout(sys.stderr):
                if mode=='produce':
                    output=produce(clip)
                else:
                    output=None
                    pipeline.main([mode,'--only',clip,'--exact','--limit','1','--threads',str(threads),'--performed-demons'])
            if mode=='expressive':
                record=json.loads((pipeline.WORK/'expressive.json').read_text())[clip]
                if record['error']: raise RuntimeError(record['error'])
                if not (pipeline.WORK/'expressive'/f'{clip}.wav').exists(): raise RuntimeError('missing expressive output')
            self.answer(200,{'ok':True,'mode':mode,'id':clip,'output':output,'seconds':round(time.monotonic()-start,3)})
        except Exception as exc:
            traceback.print_exc();self.answer(500,{'ok':False,'error':str(exc)})
        finally: last=time.monotonic()
server=HTTPServer(('127.0.0.1',18851),Handler);server.timeout=30
print(f'voice worker ready on localhost:18851; one process, {threads} threads',flush=True)
while time.monotonic()-last<900:
    server.handle_request()
print('voice worker idle for 15 minutes; stopping',flush=True)
