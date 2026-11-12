#!/usr/bin/env python3
"""One resident process for required Kokoro/Chatterbox model libraries.

Lua owns scheduling/checkpoints; this local-only HTTP adapter retains model
instances between requests instead of reloading gigabytes for every short line.
"""
import contextlib
import importlib.util
import json
import re
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
def kokoro(config):
    if 'kokoro' not in models: models['kokoro']=original_kokoro(config)
    return models['kokoro']
def chatterbox(config,threads):
    if 'chatterbox' not in models: models['chatterbox']=original_chatterbox(config,threads)
    return models['chatterbox']
pipeline.Kokoro=kokoro;pipeline.load_chatterbox=chatterbox
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
            if mode not in ('refs','voices','expressive'): raise ValueError('unsupported model stage')
            if not re.fullmatch(r'[A-Za-z0-9_.-]+',clip): raise ValueError('invalid clip id')
            start=time.monotonic()
            with contextlib.redirect_stdout(sys.stderr):
                pipeline.main([mode,'--only',clip,'--exact','--limit','1','--threads','4','--performed-demons'])
            if mode=='expressive':
                record=json.loads((pipeline.WORK/'expressive.json').read_text())[clip]
                if record['error']: raise RuntimeError(record['error'])
                if not (pipeline.WORK/'expressive'/f'{clip}.wav').exists(): raise RuntimeError('missing expressive output')
            self.answer(200,{'ok':True,'mode':mode,'id':clip,'seconds':round(time.monotonic()-start,3)})
        except Exception as exc:
            traceback.print_exc();self.answer(500,{'ok':False,'error':str(exc)})
        finally: last=time.monotonic()
server=HTTPServer(('127.0.0.1',18851),Handler);server.timeout=30
print('voice worker ready on localhost:18851; one process, four threads',flush=True)
while time.monotonic()-last<900:
    server.handle_request()
print('voice worker idle for 15 minutes; stopping',flush=True)
