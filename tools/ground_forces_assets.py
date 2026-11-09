#!/usr/bin/env python3
"""Reproducible pipeline for the ground-forces atlas (demon ground army,
allied human ground units, ground effects, the ground-to-air missile).

Driven by ``art/families/ground-forces.json``.  Stages:

  jobs     write the ComfyUI generation queue (one LayerDiffuse transparent
           keyframe per unit / extra and candidate seed)
  run      execute the queue against the ComfyUI HTTP API (COMFY_URL,
           default http://studio:8188); outputs land in $GROUND_WORK/http
  ingest   copy raw outputs to $GROUND_RAW (never the repo), record provenance
           (workflow, prompt, seed, models, SHA-256) in
           art/families/ground-forces-runs.json, and refresh the small
           selected sources of record under art/sprites/sources/ground/
  pack     deterministic finish -> assets/images/ground-forces.png,
           lib/game/ground_atlas.dart, art/contact/ground-forces-contact.png
  offline  pack from the committed sources only (no GPU, no raws)
  all      jobs, run, ingest, pack

Silhouettes, launchers and every frame are AUTHORED on the texel grid (the
``build_*`` functions below), so move/telegraph/fire/wreck/limp frames stay
aligned pixel for pixel.  The selected AI keyframe of each unit contributes a
-1/0/+1 shading texture on its hull ramp (the same split as the combat
sprite pipeline: AI for shading, authored outlines).  Every random choice is
seeded, so reruns give identical bytes.  Requires Pillow + NumPy.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import flyover_assets as fa  # noqa: E402  (palette quantiser, HTTP helpers)

ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "art/families/ground-forces.json"
RUNS_PATH = ROOT / "art/families/ground-forces-runs.json"
SOURCES = ROOT / "art/sprites/sources/ground"
_SCRATCH = Path.home() / ".cache/demon-attack/ground-forces"
WORK = Path(os.environ.get("GROUND_WORK", str(_SCRATCH / "work")))
RAW = Path(os.environ.get("GROUND_RAW", str(_SCRATCH / "raw")))
ATLAS_OUT = ROOT / "assets/images/ground-forces.png"
DART_OUT = ROOT / "lib/game/ground_atlas.dart"
CONTACT_OUT = ROOT / "art/contact/ground-forces-contact.png"
SECTORS = ("krybor", "ringfall", "ember", "hollow")
SOURCE_W = 64  # sources of record are stored at most this wide


def spec() -> dict:
    return json.loads(SPEC_PATH.read_text())


def hexrgb(h: str) -> tuple:
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


# --------------------------------------------------------------------------
# GPU stages
# --------------------------------------------------------------------------


def job_list() -> list[dict]:
    s = spec()
    neg = s["negative_prompt"]
    jobs = []
    entries = [(u["id"], u["prompt"], u["seed"]) for u in s["units"]] + \
              [(e["id"], e["prompt"], e["seed"]) for e in s["extras"]]
    for uid, prompt, seed in entries:
        style = s["style_prompt"] if not uid in ("missile", "explosion") else \
            "pixel art, 16-bit arcade shooter game sprite, crisp square pixels, original artwork, centered, isolated"
        for c in range(s["sprite"]["candidates"]):
            jobs.append({
                "id": f"{uid}/{seed + c}",
                "unit": uid,
                "workflow": s["sprite"]["workflow"],
                "inputs": {},
                "overrides": {
                    "prompt": f"{style}, {prompt}, transparent background",
                    "negative_prompt": neg,
                    "seed": seed + c,
                    "$node:10.filename_prefix": "ground/sprite-rgb",
                    "$node:12.filename_prefix": "ground/sprite-alpha",
                },
            })
    return jobs


def cmd_jobs(_args) -> None:
    jobs = job_list()
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / "jobs.json").write_text(json.dumps(jobs, indent=1))
    print(f"{len(jobs)} jobs -> {WORK / 'jobs.json'}")


def cmd_run(args) -> None:
    """Direct ComfyUI HTTP backend; one job in flight at a time (shared GPU)."""
    url = args.url.rstrip("/")
    jobs = job_list()
    for job in jobs:
        if args.only and not job["id"].startswith(tuple(args.only.split(","))):
            continue
        dest = WORK / "http" / job["id"].replace("/", "__")
        if dest.exists() and len(list(dest.glob("*.png"))) >= 2 and not args.force:
            continue
        wf = fa.bind_workflow(job, {})
        pid = fa._http_json(url + "/prompt", {"prompt": wf})["prompt_id"]
        while True:
            hist = fa._http_json(url + f"/history/{pid}")
            if pid in hist:
                break
            time.sleep(3)
        shutil.rmtree(dest, ignore_errors=True)
        dest.mkdir(parents=True, exist_ok=True)
        for node_out in hist[pid]["outputs"].values():
            for im in node_out.get("images", []):
                q = urllib.parse.urlencode({"filename": im["filename"], "subfolder": im["subfolder"], "type": im["type"]})
                with urllib.request.urlopen(url + "/view?" + q, timeout=120) as r:
                    (dest / im["filename"]).write_bytes(r.read())
        (dest / "job.json").write_text(json.dumps(job, indent=1))
        print(job["id"], "ok", flush=True)


def cmd_ingest(_args) -> None:
    jobs = {j["id"]: j for j in job_list()}
    runs = json.loads(RUNS_PATH.read_text()) if RUNS_PATH.exists() else {}
    http = WORK / "http"
    n = 0
    for d in sorted(http.iterdir()) if http.exists() else []:
        jid = d.name.replace("__", "/")
        if jid not in jobs or not d.is_dir():
            continue
        dest = RAW / jid
        shutil.rmtree(dest, ignore_errors=True)
        dest.mkdir(parents=True, exist_ok=True)
        wf = json.loads((ROOT / jobs[jid]["workflow"]).read_text())
        models = sorted({v for nd in wf.values() for k, v in nd["inputs"].items()
                         if k in ("ckpt_name", "lora_name") and isinstance(v, str)})
        models += ["layer_xl_transparent_conv.safetensors", "vae_transparent_decoder.safetensors"]
        entry = {"workflow": jobs[jid]["workflow"],
                 "prompt": jobs[jid]["overrides"]["prompt"],
                 "negative_prompt": jobs[jid]["overrides"]["negative_prompt"],
                 "seed": jobs[jid]["overrides"]["seed"], "models": models, "outputs": []}
        for p in sorted(d.glob("*.png")):
            shutil.copyfile(p, dest / p.name)
            entry["outputs"].append({"file": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()})
        runs[jid] = entry
        n += 1
    RUNS_PATH.write_text(json.dumps(dict(sorted(runs.items())), indent=1) + "\n")
    print("ingested", n)
    write_sources()


def load_raw(jid: str):
    d = RAW / jid
    rgb = sorted(d.glob("sprite-rgb*.png")) if d.exists() else []
    al = sorted(d.glob("sprite-alpha*.png")) if d.exists() else []
    if not rgb or not al:
        return None
    return Image.open(rgb[0]).convert("RGB"), Image.open(al[0]).convert("L")


def write_sources() -> None:
    """Selected keyframes -> small RGBA sources of record (cropped to the
    LayerDiffuse alpha, box-downscaled to <= SOURCE_W px wide)."""
    s = spec()
    SOURCES.mkdir(parents=True, exist_ok=True)
    for e in s["units"] + s["extras"]:
        pick = e.get("selected")
        if pick is None:
            continue
        loaded = load_raw(f"{e['id']}/{pick}")
        if loaded is None:
            print("missing raw", e["id"], pick)
            continue
        rgb, al = loaded
        bb = fa.alpha_bbox(np.asarray(al), 140)
        if bb is None:
            continue
        rgb, al = rgb.crop(bb), al.crop(bb)
        w, h = rgb.size
        k = min(1.0, SOURCE_W / max(w, h))
        size = (max(1, round(w * k)), max(1, round(h * k)))
        im = rgb.resize(size, Image.Resampling.BOX).convert("RGBA")
        im.putalpha(al.resize(size, Image.Resampling.BOX))
        im.save(SOURCES / f"{e['id']}.png", optimize=True)
        print("source", e["id"], size)


# --------------------------------------------------------------------------
# Colour codes.  Units are authored as small integer code grids; a per-unit
# colour table maps codes to RGB at the end, so wreck/dent/texture passes are
# integer operations and every output colour comes from a bounded set (sector
# palette + reserved demon steel for demon hulls; reserved warm / cyan /
# ally hull / smoke / scorch sets).
# --------------------------------------------------------------------------

EMPTY = 0
H = [1, 2, 3, 4, 5]               # hull ramp h0 (darkest) .. h4 (highlight)
W = [10, 11, 12, 13, 14, 15, 16]  # warm w0 .. w6 (demon accents, fire)
C = [20, 21, 22, 23, 24]          # cyan c0 .. c4 (allied accents)
S = [30, 31, 32, 33, 34]          # smoke s0 .. s4
K = [40, 41, 42, 43]              # scorch k0 .. k3
OUT, RIM = 50, 51
CW, CH = 32, 24                   # atlas cell (texels)
COLS, ROWS = 12, 10
PAD = 6                           # authoring margin around a cell


def is_hull(g):
    return (g >= H[0]) & (g <= H[4])


def is_warm(g):
    return (g >= W[0]) & (g <= W[6])


def is_cyan(g):
    return (g >= C[0]) & (g <= C[4])


def blank():
    return np.zeros((CH + 2 * PAD, CW + 2 * PAD), dtype=np.int16)


class Canvas:
    """Integer code grid (with a PAD margin) plus a body offset (gait bob)
    and an optional hull texture (AI shading, -1/0/+1 per body texel)."""

    def __init__(self, tex=None):
        self.g = blank()
        self.dx = self.dy = 0
        self.tex = tex

    def put(self, x, y, code):
        x, y = int(round(x)), int(round(y))
        if self.tex is not None and H[1] <= code <= H[3] and 0 <= y < CH and 0 <= x < CW:
            code = int(np.clip(code + self.tex[y, x], H[1], H[4]))
        gx, gy = x + self.dx + PAD, y + self.dy + PAD
        if 0 <= gy < self.g.shape[0] and 0 <= gx < self.g.shape[1]:
            self.g[gy, gx] = code

    def rect(self, x0, y0, x1, y1, code):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                self.put(x, y, code)

    def disc(self, cx, cy, r, code):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.put(x, y, code)

    def line(self, x0, y0, x1, y1, code):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            self.put(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, code)

    def box(self, x0, x1, top, side_top, bottom, nose=0):
        """3/4 box lit from the upper left: top face rows [top, side_top),
        side face rows [side_top, bottom); `nose` slants the right end."""
        for y in range(top, bottom):
            cut = max(0, nose - (y - top)) if (nose and y < side_top) else 0
            for x in range(x0, x1 - cut):
                if y < side_top:
                    code = H[4] if (y == top and x < x0 + (x1 - x0) * 3 // 4) else H[3]
                else:
                    code = H[1] if y == bottom - 1 else H[2]
                if x == x1 - cut - 1:
                    code = max(H[1], code - 1)
                self.put(x, y, code)

    def tube(self, px, py, ang, length, thick, muzzles=(0.0,), cap=True, seams=(), nose=None):
        """Launcher tube/rack from a pivot at `ang` degrees (0 = right,
        + = up).  `seams`: perpendicular offsets of dark lines between tubes;
        `nose`: code painted on the muzzle texels (loaded warheads).
        Returns muzzle points in canvas coordinates with the direction."""
        a = np.radians(ang)
        d = np.array([np.cos(a), -np.sin(a)])
        n = np.array([np.sin(a), np.cos(a)])  # toward the underside
        p0 = np.array([px, py], dtype=float)
        for k2 in range(int(thick * 2) - 1, -1, -1):
            k = k2 / 2 - (thick - 1) / 2
            frac = k2 / max(1, thick * 2 - 1)
            code = H[4] if (k2 == 0 and thick >= 3) else (H[3] if frac < .3 else (H[2] if frac < .75 else H[1]))
            for t2 in range(int(length * 2) + 1):
                p = p0 + d * (t2 / 2) + n * k
                self.put(p[0], p[1], code)
        if cap:
            for k2 in range(int(thick * 2)):
                p = p0 + d * length + n * (k2 / 2 - (thick - 1) / 2)
                self.put(p[0], p[1], H[1])
        for sm in seams:
            for t2 in range(4, int(length * 2)):
                p = p0 + d * (t2 / 2) + n * sm
                self.put(p[0], p[1], H[0])
        pts = []
        for m in muzzles:
            p = p0 + d * length + n * m
            self.put(p[0], p[1], nose if nose is not None else H[0])
            pts.append((p[0] + self.dx, p[1] + self.dy, d))
        return pts


def wheel(c, cx, cy, r, phase, flat=False):
    """Tyre with six notches that turn 15 degrees per move frame."""
    if flat:  # blown tyre: squashed, hub knocked off-centre
        c.rect(cx - r, cy, cx + r + 1, cy + r + 1, H[0])
        c.rect(cx - r + 1, cy - 1, cx + r, cy, H[0])
        c.put(cx + 1, cy, H[2])
        return
    c.disc(cx, cy, r, H[0])
    for i in range(6):
        a = np.radians(i * 60 + phase * 15)
        c.put(cx + np.cos(a) * (r - .5), cy + np.sin(a) * (r - .5), H[2])
    c.disc(cx, cy, max(.6, r * .38), H[3])
    c.put(cx - .5, cy - .5, H[4])


def tread(c, x0, x1, y0, y1, phase):
    """Track with links that crawl one texel per frame and turning wheels."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            if (x in (x0, x1 - 1)) and (y in (y0, y1 - 1)):
                continue
            edge = y in (y0, y1 - 1)
            link = (x + (phase if y == y0 else -phase)) % 3 == 0
            c.put(x, y, H[2] if edge and link else H[0])
    cy = (y0 + y1 - 1) / 2
    for x in range(x0 + 2, x1 - 1, 4):
        c.disc(x + .5, cy, 1.1, H[2])
        a = np.radians(phase * 90)
        c.put(x + .5 + np.cos(a) * .8, cy + np.sin(a) * .8, H[4])


def gait(phase, group):
    """Two-group leg cycle: (lift, stride x offset) of a leg group."""
    ph = (phase + 2 * group) % 4
    return (1 if ph == 0 else 0), (1, 0, -1, 0)[ph]


def blink(phase, on, off):
    return on if phase in (0, 1) else off


# --------------------------------------------------------------------------
# Unit builders.  st: phase (0-3 move cycle), ang (launcher angle), wreck;
# allies: fire (0 none, 1 big recoil, 2 small), limp.  Each returns a dict:
# m = muzzle points, ex = exhaust point (or None), all canvas coordinates.
# --------------------------------------------------------------------------


def build_demon_krybor(c, st):
    ph = st["phase"]
    for i, x in enumerate((5, 13, 21)):
        wheel(c, x, 20, 2.6, ph)
    c.dy = -(ph % 2)
    c.box(1, 26, 13, 15, 19, nose=3)
    c.rect(23, 16, 26, 18, H[1])                       # ram bumper
    c.put(24, 17, H[3])
    c.put(25, 16, blink(ph, W[5], W[3]))               # hazard lamps
    c.put(1, 15, blink(ph, W[3], W[5]))
    for x in (9, 17):
        c.put(x, 17, W[3]); c.put(x + 1, 17, W[2])     # furnace slits
    c.rect(1, 12, 3, 13, H[1])                         # exhaust stack
    # Roll cage and imp driver.
    c.line(17, 13, 17, 10, H[2]); c.line(23, 13, 22, 10, H[2]); c.line(17, 10, 22, 10, H[3])
    c.rect(19, 11, 21, 13, H[0])
    c.put(18, 10, W[2]); c.put(18, 9, W[3]); c.put(21, 10, W[2]); c.put(22, 9, W[3])  # horns
    c.put(20, 11, W[6]); c.put(19, 11, W[5])           # eyes
    ex = (1 + c.dx, 11 + c.dy)
    if st.get("wreck"):
        c.rect(5, 12, 8, 13, H[0])
        return {"m": [(12, 12, np.array([1.0, 0]))], "ex": None}
    c.rect(4, 11, 8, 13, H[1])                         # launcher cradle
    if st["ang"] > 15:
        c.line(10, 13, 11, 13 - (st["ang"] - 6) / 6, H[1])
    return {"m": c.tube(4, 11, st["ang"], 10, 4, muzzles=(-1, 1), seams=(0,), nose=W[2]), "ex": ex}


def build_demon_ringfall(c, st):
    ph = st["phase"]
    tread(c, 1, 27, 18, 23, ph)
    c.dy = -(1 if ph in (1, 2) else 0)
    c.box(2, 26, 11, 14, 18, nose=4)
    for x in (8, 15, 21):
        c.line(x, 14, x, 16, H[1])                     # salvage plate seams
    for x in (4, 11, 18):
        c.put(x, 12, H[4])                             # rivets
    for i, x in enumerate((10, 11, 12)):               # furnace vents pulse
        c.put(x, 15, W[4] if (i + ph) % 3 else W[5])
    c.put(11, 16, W[2])
    c.put(24, 15, W[6]); c.put(23, 15, W[5])           # sensor eyes
    c.put(25, 13, blink(ph, W[4], W[2]))
    ex = (2 + c.dx, 12 + c.dy)
    if st.get("wreck"):
        c.rect(6, 10, 9, 11, H[0])
        return {"m": [(12, 10, np.array([1.0, 0]))], "ex": None}
    c.rect(4, 10, 8, 12, H[1])
    if st["ang"] > 12:
        c.line(13, 11, 13, 11 - (st["ang"] - 4) / 5, H[1])
    pts = c.tube(5, 10, st["ang"], 12, 3, cap=False)
    x, y, d = pts[0]                                   # seated missile warhead
    c.put(x - c.dx - d[0], y - c.dy - d[1], W[2])
    c.put(x - c.dx - d[0], y - c.dy - d[1] + 1, W[1])
    c.put(x - c.dx, y - c.dy, W[3])
    return {"m": pts, "ex": ex}


def build_demon_ember(c, st):
    ph = st["phase"]
    limbs = ((7, True, 1), (18, True, 0), (4, False, 0), (15, False, 1))
    for lx, far, grp in limbs:
        lift, sx = gait(ph, grp)
        code = H[1] if far else H[2]
        o = (1 if far else 0) + sx
        c.rect(lx + o, 17, lx + 3 + o, 22 - lift, code)
        c.put(lx + o, 17, H[3] if not far else H[2])
        c.rect(lx - 1 + o, 22 - lift, lx + 4 + o, 23 - lift, H[0])
        c.put(lx + 3 + o, 22 - lift, H[2])            # claw
    c.dy = -(1 if ph in (1, 3) else 0)
    for y in range(11, 18):                            # hunched basalt body
        half = [7, 9, 10, 10, 10, 10, 9][y - 11]
        for x in range(13 - half, 13 + half):
            code = H[3] if y < 13 else (H[2] if y < 16 else H[1])
            if y == 11:
                code = H[4]
            c.put(x, y, code)
    cracks = ((6, 14), (7, 15), (8, 15), (9, 16), (14, 13), (15, 14), (15, 15), (19, 15), (11, 12))
    for i, (x, y) in enumerate(cracks):                # molten cracks throb
        c.put(x, y, W[4] if (i + ph) % 4 else W[5])
    c.put(8, 14, W[2]); c.put(16, 15, W[3])
    c.rect(21, 13, 27, 17, H[2]); c.rect(21, 13, 26, 14, H[3]); c.rect(22, 17, 26, 18, H[1])
    c.put(27, 16, H[1])
    c.put(22, 12, H[3]); c.put(23, 11, H[4]); c.put(24, 10, H[4]); c.put(25, 10, H[3])  # horn
    c.put(25, 14, W[6]); c.put(26, 14, W[5])           # eyes
    c.put(26, 16, W[4] if ph % 2 else W[3]); c.put(25, 16, W[2])  # maw
    ex = (27 + c.dx, 15 + c.dy)
    if st.get("wreck"):
        c.rect(10, 10, 13, 11, H[0])
        return {"m": [(14, 10, np.array([1.0, 0]))], "ex": None}
    c.rect(9, 9, 14, 11, H[1]); c.put(9, 9, H[3])      # mortar trunnion
    return {"m": c.tube(11, 9, st["ang"], 6, 4, nose=W[1]), "ex": ex, "breath": True}


def build_demon_hollow(c, st):
    ph = st["phase"]
    for lx, grp in ((5, 0), (13, 1)):
        lift, sx = gait(ph, grp)
        c.rect(lx + sx, 19, lx + 4 + sx, 22 - lift, H[1])
        c.put(lx + sx, 19, H[2])
        c.rect(lx - 1 + sx, 22 - lift, lx + 5 + sx, 23 - lift, H[0])
        c.put(lx + 4 + sx, 22 - lift, H[2])
    c.dy = -(1 if ph in (1, 3) else 0)
    c.box(3, 19, 10, 12, 20)
    for x in range(3, 19, 3):                          # crenellations
        c.rect(x, 9, x + 2, 10, H[4])
    for y in range(13, 19):                            # pointed arch, burning rune
        w = 1 if y == 13 else 2
        for x in range(10 - w, 10 + w):
            c.put(x, y, H[0])
    c.put(8, 13, H[3]); c.put(11, 13, H[3])
    rune = W[5] if ph in (0, 3) else W[4]
    c.put(9, 16, rune); c.put(10, 16, rune); c.put(9, 15, W[4]); c.put(10, 17, W[3]); c.put(9, 17, W[2])
    c.put(5, 14, blink(ph, W[3], W[2])); c.put(5, 18, blink(ph, W[2], W[3]))
    c.rect(16, 11, 22, 16, H[2]); c.rect(16, 11, 22, 12, H[3]); c.rect(18, 16, 22, 17, H[1])
    c.put(17, 10, H[4]); c.put(16, 9, H[3]); c.put(21, 10, H[4]); c.put(22, 9, H[3])  # horns
    c.put(19, 13, W[6]); c.put(21, 13, W[5])           # eyes
    c.put(20, 15, W[3])
    if st.get("wreck"):
        return {"m": [(10, 8, np.array([0.0, -1]))], "ex": None}
    c.rect(6, 8, 11, 9, H[1])
    return {"m": c.tube(8, 8, st["ang"], 6, 4, nose=W[2]), "ex": None}


def build_ally_krybor(c, st):
    ph = st["phase"]
    limp = st.get("limp")
    wheel(c, 5, 20, 2.5, ph, flat=bool(limp))
    wheel(c, 15, 20, 2.5, ph)
    c.dy = -(ph % 2)
    c.box(1, 20, 14, 16, 19, nose=2)
    c.rect(2, 17, 19, 18, C[2]); c.put(8, 17, C[3])    # stripe
    c.put(16, 14, C[3]); c.put(17, 14, C[4])           # cab window
    c.put(19, 16, C[4])                                # headlight
    c.put(1, 16, blink(ph, C[3], C[1]))                # tail beacon
    c.rect(7, 12, 12, 14, H[2]); c.rect(7, 12, 11, 13, H[3])  # turret
    c.put(9, 12, C[3])
    rec = 1 if st.get("fire") == 1 else 0
    ang = -10 if limp else 8
    return {"m": c.tube(11 - rec, 12, ang, 6, 1, cap=False), "ex": (0 + c.dx, 15 + c.dy)}


def build_ally_ringfall(c, st):
    ph = st["phase"]
    limp = st.get("limp")
    for i, x in enumerate((4, 10.5, 17)):
        if limp and i == 0:
            c.line(2, 22, 6, 19, H[1])                 # axle dragging, wheel gone
            continue
        wheel(c, x, 20.5, 2, ph)
    c.dy = -(1 if ph in (1, 2) else 0)
    c.box(1, 21, 15, 17, 20, nose=3)
    c.rect(5, 17, 9, 19, H[3]); c.rect(13, 17, 15, 19, H[1])  # patch plates
    c.put(6, 18, H[4])
    c.rect(2, 19, 20, 20, C[2])
    c.put(20, 18, C[4]); c.put(19, 18, C[3])
    c.put(2, 16, blink(ph, C[3], C[1]))
    c.rect(8, 13, 13, 15, H[2]); c.rect(8, 13, 12, 14, H[3])
    rec = 1 if st.get("fire") == 1 else 0
    pts = c.tube(12 - rec, 13, 10, 5, 1, cap=False)
    pts += c.tube(12 - rec, 14, 10 if not limp else -8, 5, 1, cap=False)
    return {"m": pts, "ex": (0 + c.dx, 17 + c.dy)}


def build_ally_ember(c, st):
    # Fixed turret: the move cycle is a slow traverse, a sensor sweep and a
    # radar mast that turns.
    ph = st["phase"]
    limp = st.get("limp")
    c.box(1, 17, 18, 20, 23)
    c.put(0, 22, H[1]); c.put(17, 22, H[1])
    c.rect(2, 21, 16, 22, C[2]); c.put(3 + ph * 3, 21, C[4])  # running light
    c.disc(9, 15, 3.6, H[2])
    for y in range(11, 15):
        for x in range(5, 13):
            if (x - 9) ** 2 + (y - 15) ** 2 <= 13 and y < 14:
                c.put(x, y, H[3])
    c.put(7, 12, H[4]); c.put(8, 12, H[4])
    c.put(10, 15, C[4]); c.put(11, 15, C[3])
    c.line(4, 13, 4, 10, H[2])                         # radar mast
    c.put(4 + (-1, 0, 1, 0)[ph], 9, C[3]); c.put(4, 9, H[3])
    rec = 1 if st.get("fire") == 1 else 0
    ang = -14 if limp else (12, 14, 16, 14)[ph]
    return {"m": c.tube(11 - rec, 13.5, ang, 6, 2, cap=False), "ex": None}


def build_ally_hollow(c, st):
    ph = st["phase"]
    limp = st.get("limp")
    for lx, grp, code in ((6, 1, H[1]), (10, 0, H[2])):  # digitigrade legs
        lift, sx = gait(ph, grp)
        if limp and grp == 1:                          # rear leg dragging
            lift, sx = 0, -2
            c.line(lx, 16, lx - 2, 19, code); c.line(lx - 2, 19, lx - 4, 22, code)
            c.rect(lx - 6, 22, lx - 2, 23, H[0])
            continue
        c.line(lx, 16, lx - 1, 18, code); c.line(lx + 1, 16, lx, 18, code)
        c.line(lx - 1, 18, lx + 1 + sx, 21 - lift, code); c.line(lx, 18, lx + 2 + sx, 21 - lift, code)
        c.rect(lx - 1 + sx, 22 - lift, lx + 4 + sx, 23 - lift, H[0])
    c.dy = -(1 if ph in (0, 2) else 0)
    c.box(3, 15, 10, 12, 16, nose=2)
    c.rect(10, 12, 14, 14, C[2]); c.put(13, 12, C[4]); c.put(12, 12, C[3])  # visor
    c.put(4, 10, blink(ph, C[4], C[2]))                # hatch lamp
    c.rect(5, 13, 10, 16, H[3]); c.rect(5, 15, 10, 16, H[1])  # gun pod
    c.put(6, 14, C[2])
    rec = 1 if st.get("fire") == 1 else 0
    return {"m": c.tube(9 - rec, 14, -12 if limp else 0, 6, 1, cap=False), "ex": None}


BUILDERS = {
    "demon-krybor": build_demon_krybor, "demon-ringfall": build_demon_ringfall,
    "demon-ember": build_demon_ember, "demon-hollow": build_demon_hollow,
    "ally-krybor": build_ally_krybor, "ally-ringfall": build_ally_ringfall,
    "ally-ember": build_ally_ember, "ally-hollow": build_ally_hollow,
}
# Launcher angles: idle, raised (telegraph), fire (recoil), post-fire.
ANGLES = {"demon-krybor": (6, 32, 28, 20), "demon-ringfall": (4, 30, 26, 18),
          "demon-ember": (22, 55, 50, 40), "demon-hollow": (10, 50, 44, 32)}


# --------------------------------------------------------------------------
# Passes on code grids (padded coordinates unless noted)
# --------------------------------------------------------------------------


def outline(g: np.ndarray, rim=True) -> np.ndarray:
    """Dark 1-texel ring; ring texels above lit top edges become RIM."""
    a = g > 0
    nb = np.zeros_like(a)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nb |= np.roll(np.roll(a, dy, 0), dx, 1)
    ring = nb & ~a
    out = g.copy()
    out[ring] = OUT
    if rim:
        below = np.roll(a, -1, 0)
        lit = ring & below & ~np.roll(a, 1, 0) & ~np.roll(a, 1, 1)
        # Rim only over hull tops (not over glow/smoke texels).
        under = np.roll(g, -1, 0)
        out[lit & is_hull(under) & (under >= H[2])] = RIM
    return out


def overlay(g, x, y, code, only_empty=False):
    """Canvas coordinates (no PAD)."""
    x, y = int(round(x)) + PAD, int(round(y)) + PAD
    if 0 <= y < g.shape[0] and 0 <= x < g.shape[1]:
        if not only_empty or g[y, x] in (EMPTY, OUT):
            g[y, x] = code


def glow(g, pts, level):
    for x, y, d in pts:
        tip = (x + d[0], y + d[1])
        if level == 1:
            overlay(g, x, y, W[4])
            overlay(g, *tip, W[3], True)
        else:
            overlay(g, x, y, W[6])
            overlay(g, *tip, W[6])
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                overlay(g, tip[0] + ox, tip[1] + oy, W[5], True)
            for ox, oy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
                overlay(g, tip[0] + ox, tip[1] + oy, W[3], True)
            overlay(g, tip[0] + 2 * d[0], tip[1] + 2 * d[1], W[4], True)


def flash(g, pts, warm=True, size=1):
    """Muzzle / launch flash: core, cross rays, diagonal sparks."""
    ramp = W[3:] if warm else C[1:]
    for x, y, d in pts:
        cx, cy = x + d[0] * (1 + size), y + d[1] * (1 + size)
        r = 1 + size
        for oy in range(-r - 2, r + 3):
            for ox in range(-r - 2, r + 3):
                dist = abs(ox) + abs(oy)
                diag = abs(ox) == abs(oy)
                if dist == 0:
                    code = ramp[-1]
                elif dist <= r and not (diag and dist > 1):
                    code = ramp[-2]
                elif (ox == 0 or oy == 0) and dist <= r + 2:
                    code = ramp[-3] if dist <= r + 1 else ramp[0]
                elif diag and dist == 2 * r + (0 if size else 2):
                    code = ramp[0]
                else:
                    continue
                overlay(g, cx + ox, cy + oy, code)


def puffs(g, x, y, phase, n=2, drift=(-.5, -1.2)):
    """Exhaust puffs leaving (x, y) (canvas coords): they drift and thin
    out one step per move frame, so the 4-frame cycle loops."""
    for i in range(n):
        t = phase + 4 * i
        px, py = x + drift[0] * t * .6, y + drift[1] * t * .5
        code = S[3] if t < 2 else (S[2] if t < 5 else S[1])
        overlay(g, px, py, code, True)
        if 2 <= t < 6:
            overlay(g, px + 1, py, code, True)
            overlay(g, px, py - 1, S[3] if t < 4 else S[2], True)


def smoke_wisp(g, x, y, rng, n=5, dark=False):
    """Rising curl of smoke from (x, y) in padded coordinates."""
    ramp = (S[2], S[1], S[0]) if dark else (S[3], S[2], S[1])
    for i in range(n):
        px = x + int(rng.integers(-1, 2)) + (i // 2)
        py = y - i
        if 0 <= py < g.shape[0] and 0 <= px + 1 < g.shape[1] and g[py, px] in (EMPTY, OUT):
            g[py, px] = ramp[0] if i < 2 else (ramp[1] if i < 4 else ramp[2])
            if i % 2 == 0 and g[py, px + 1] == EMPTY:
                g[py, px + 1] = ramp[1]


def sparks(g, rng, n, codes):
    """Star sparks on random hull texels (padded coordinates)."""
    ys, xs = np.nonzero(is_hull(g))
    if not len(xs):
        return
    for i in rng.choice(len(xs), size=min(n, len(xs)), replace=False):
        y, x = ys[i], xs[i]
        g[y, x] = codes[0]
        for k, (ox, oy) in enumerate(((1, -1), (-1, -1), (0, -2))):
            if 0 <= y + oy and g[y + oy, x + ox] in (EMPTY, OUT) or is_hull(g[y + oy, x + ox]):
                if k < 2 or rng.random() < .5:
                    g[y + oy, x + ox] = codes[1]


def top_surface(g):
    """Topmost opaque texel per column -> {x: y} (padded coordinates)."""
    out = {}
    for x in range(g.shape[1]):
        col = np.nonzero(g[:, x])[0]
        if len(col):
            out[x] = int(col.min())
    return out


def wreck_pass(g, seed):
    """Darken, quench accents, tear the top, punch holes (demons only)."""
    rng = np.random.default_rng(seed)
    out = g.copy()
    hull = is_hull(out)
    out[hull] = np.maximum(H[0], out[hull] - np.where(out[hull] >= H[3], 2, 1))
    out[is_warm(out)] = W[0]
    out[is_cyan(out)] = H[0]
    ys, xs = np.nonzero(out)
    if len(xs):
        hgt = ys.max() - ys.min() + 1
        prof = np.cumsum(rng.integers(-1, 2, out.shape[1])) % 4
        for x in range(xs.min(), xs.max() + 1):
            col = np.nonzero(out[:, x])[0]
            if len(col):
                out[col.min(): col.min() + int(prof[x] + hgt * .12), x] = EMPTY
        for _ in range(3):
            i = rng.integers(len(xs))
            out[ys[i]: ys[i] + 2, xs[i]: xs[i] + 2] = EMPTY
    return out


def dent_pass(g, seed):
    """Allies totalled but intact: dark dents, a few dead lights, nicks out
    of the silhouette top.  No fire, no scorch."""
    rng = np.random.default_rng(seed)
    out = g.copy()
    ys, xs = np.nonzero(is_hull(out))
    for i in rng.choice(len(xs), size=min(2, len(xs)), replace=False):
        y, x = ys[i], xs[i]
        m = is_hull(out[y - 1: y + 1, x - 1: x + 2])
        out[y - 1: y + 1, x - 1: x + 2][m] = H[0]
    cy = np.nonzero(is_cyan(out))
    for j in range(0, len(cy[0]), 2):
        out[cy[0][j], cy[1][j]] = C[0]
    return out


def flames(g, sites, rng, heights=(5, 3, 2)):
    """Burning hulk: a flame tongue above each site (padded coordinates);
    the tallest is 2-3 texels wide, heights flicker by one per frame."""
    for (x, y), base_h in zip(sites, heights):
        h = max(1, base_h + int(rng.integers(-1, 2)))
        lean = int(rng.integers(-1, 2))
        if base_h >= 4:  # wide body of the main fire
            for i in range(h - 2):
                for ox in (-1, 1):
                    if g[y - 1 - i, x + ox] in (EMPTY, OUT) or is_hull(g[y - 1 - i, x + ox]):
                        g[y - 1 - i, x + ox] = W[3] if i < h - 3 else W[2]
        for i in range(h):
            px = x + (lean if i >= h - 1 else 0)
            code = (W[5], W[4], W[3], W[2])[min(3, i)] if i < h - 1 else W[3]
            if g[y - 1 - i, px] in (EMPTY, OUT) or not is_hull(g[y - 1 - i, px]):
                g[y - 1 - i, px] = code
            if i == 0:
                for ox in (-1, 1):
                    if g[y - 1, x + ox] in (EMPTY, OUT):
                        g[y - 1, x + ox] = W[3]
        g[y, x] = W[6]


def scorch_under(g, rng):
    ys, xs = np.nonzero(g)
    x0, x1, bot = xs.min(), xs.max(), ys.max()
    cx = (x0 + x1) / 2
    rx = min((x1 - x0) / 2 + 3, cx - PAD - .5, PAD + CW - 1.5 - cx)
    for y in range(bot - 2, bot + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            e = ((x - cx) / rx) ** 2 + ((y - bot + .5) / 2.2) ** 2
            if e <= 1 and g[y, x] == EMPTY:
                g[y, x] = K[2] if e < .35 else (K[1] if e < .7 else K[0])
    for _ in range(4):
        x = int(rng.integers(int(cx - rx), int(cx + rx)))
        if g[bot - 1, x] in K:
            g[bot - 1, x] = K[3]


def despeckle(g, keep=2):
    """Drop texels with fewer than `keep` 8-neighbours (binary-alpha specks)."""
    a = g > 0
    p = np.pad(a, 1)
    nb = sum(p[1 + dy: 1 + dy + a.shape[0], 1 + dx: 1 + dx + a.shape[1]].astype(int)
             for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    out = g.copy()
    out[a & (nb < keep)] = 0
    return out


# --------------------------------------------------------------------------
# AI shading texture
# --------------------------------------------------------------------------


def load_source(uid: str):
    p = SOURCES / f"{uid}.png"
    return Image.open(p).convert("RGBA") if p.exists() else None


def hull_texture(uid: str):
    """Selected AI keyframe -> -1/0/+1 shading offsets on a 32x24 grid
    (high-pass luminance, thresholded at +-1.4 sigma)."""
    src = load_source(uid)
    if src is None:
        return None
    rgb = np.asarray(src.convert("RGB").resize((CW, CH), Image.Resampling.BOX)).astype(np.float32)
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    p = np.pad(lum, 1, mode="edge")
    blur = sum(p[1 + dy: 1 + dy + CH, 1 + dx: 1 + dx + CW] for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9
    hp = lum - blur
    sd = float(hp.std()) or 1.0
    return np.where(hp > 1.4 * sd, 1, np.where(hp < -1.4 * sd, -1, 0)).astype(np.int16)


# --------------------------------------------------------------------------
# Colour tables
# --------------------------------------------------------------------------


def _lum(c):
    return (np.asarray(c, dtype=np.float32) @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)) / 255


def ramp_from(pal, targets, chroma):
    pl = _lum(pal)
    pc = (pal.max(1) - pal.min(1)) / 255
    ok = np.where(pc <= chroma)[0]
    return [tuple(int(v) for v in pal[ok[np.argmin(np.abs(pl[ok] - t))]]) for t in targets]


def colour_table(s, side, sector):
    r = s["reserved"]
    tab = {}
    for codes, key in ((W, "demon_warm"), (C, "ally_cyan"), (S, "smoke"), (K, "scorch")):
        for i, h in enumerate(r[key]):
            tab[codes[i]] = hexrgb(h)
    cap = s["caps"]
    if side == "demon":
        pal = fa.load_palette(sector)
        cand = np.concatenate([pal, np.array([hexrgb(h) for h in r["demon_steel"]], dtype=np.float32)])
        ramp = ramp_from(cand, cap["demon_ramp"], cap["demon_hull_chroma"])
        tab[OUT] = tuple(int(v) for v in pal[np.argmin(pal.sum(1))])
        tab[RIM] = ramp_from(cand, [cap["demon_rim_luma"]], cap["demon_hull_chroma"])[0]
    elif side == "ally":
        hull = [hexrgb(h) for h in r["ally_hull"]]
        ramp, tab[OUT], tab[RIM] = hull[:5], hexrgb("#070B16"), hull[5]
    else:  # effects / missile / pod: iron from the smoke ramp
        ramp = [hexrgb(h) for h in r["smoke"]]
        tab[OUT], tab[RIM] = hexrgb("#070B16"), hexrgb(r["smoke"][4])
    for i in range(5):
        tab[H[i]] = ramp[i]
    return tab


def render(g, tab) -> np.ndarray:
    """Padded code grid -> RGBA cell, binary alpha."""
    core = g[PAD: PAD + CH, PAD: PAD + CW]
    out = np.zeros((CH, CW, 4), dtype=np.uint8)
    for code, rgb in tab.items():
        m = core == code
        out[m, :3] = rgb
        out[m, 3] = 255
    return out


# --------------------------------------------------------------------------
# Unit frames
# --------------------------------------------------------------------------


def place(g, dx, dy, what=""):
    out = np.roll(np.roll(g, dy, 0), dx, 1)
    core = np.zeros_like(out)
    core[PAD: PAD + CH, PAD: PAD + CW] = out[PAD: PAD + CH, PAD: PAD + CW]
    if (out != 0).sum() != (core != 0).sum():
        print("WARN clipped:", what)
    return core


def content_box(g):
    ys, xs = np.nonzero(g)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def demon_frames(uid, seed, make):
    rng = np.random.default_rng(seed)
    idle, raised, recoil, post = ANGLES[uid]
    frames = []
    for ph in range(4):                               # 0-3 move
        g, info = make(phase=ph, ang=idle)
        g = outline(g)
        if info.get("ex"):
            puffs(g, *info["ex"], ph)
        if info.get("breath"):                         # ember beast: breath sparks
            x, y = info["ex"]
            overlay(g, x + 1 + ph % 2, y - ph // 2, W[3] if ph < 2 else W[2], True)
        frames.append(g)
    g, info = make(phase=0, ang=raised)                # 4 telegraph A
    g = outline(g); glow(g, info["m"], 1); frames.append(g)
    g, info = make(phase=0, ang=raised)                # 5 telegraph B
    g = outline(g); glow(g, info["m"], 2); frames.append(g)
    g, info = make(phase=0, ang=recoil)                # 6 fire
    g = outline(g); flash(g, info["m"], warm=True, size=0)
    x, y, d = info["m"][0]
    smoke_wisp(g, int(x - d[0] * 4) + PAD, int(y + 2) + PAD, rng, 3)
    frames.append(g)
    g, info = make(phase=1, ang=post)                  # 7 post-fire: smoking tube
    g = outline(g)
    for x, y, d in info["m"]:
        overlay(g, x, y, W[2])
        for i in range(4):
            overlay(g, x + d[0] * 1.5 + (i % 2) + i * .4, y - 1 - i, S[3] if i < 2 else S[2], True)
        overlay(g, x + d[0] * 2 + 2, y - 2, S[2], True)
    frames.append(g)
    base, info = make(phase=0, ang=idle, wreck=True)   # 8-9 burning wreck
    base = wreck_pass(base, seed)
    base = outline(base, rim=False)
    scorch_under(base, np.random.default_rng(seed + 1))
    top = top_surface(np.where(is_hull(base) | (base == OUT), base, 0))
    xs = sorted(top)
    pick = [xs[int(len(xs) * f)] for f in (.42, .7, .2)]
    sites = [(x, top[x] + 1) for x in pick]
    for f in range(2):
        g = base.copy()
        frng = np.random.default_rng(seed + 10 + f)
        flames(g, sites, frng)
        hull_px = np.nonzero(is_hull(g))
        for i in frng.choice(len(hull_px[0]), size=min(5, len(hull_px[0])), replace=False):
            g[hull_px[0][i], hull_px[1][i]] = W[3] if i % 2 else W[2]
        sx, sy = sites[0]
        smoke_wisp(g, sx + f, sy - 6, frng, 5, dark=True)
        frames.append(g)
    return frames


def ally_frames(uid, seed, make):
    rng = np.random.default_rng(seed)
    frames = []
    for ph in range(4):                               # 0-3 move
        g, info = make(phase=ph)
        g = outline(g)
        if info.get("ex"):
            puffs(g, *info["ex"], ph, n=2, drift=(-1, -.6))
        frames.append(g)
    for f in (1, 2):                                   # 4-5 cyan muzzle flash
        g, info = make(phase=0, fire=f)
        g = outline(g)
        flash(g, info["m"] if f == 1 else info["m"][:1], warm=False, size=1 if f == 1 else 0)
        frames.append(g)
    g, info = make(phase=0)                            # 6 hit: hull flashes, sparks
    hull = is_hull(g)
    g[hull] = np.minimum(H[4], g[hull] + 1)
    g = outline(g)
    sparks(g, np.random.default_rng(seed + 3), 3, (C[4], C[3]))
    frames.append(g)
    for f in range(2):                                 # 7-8 totalled, limping
        g, info = make(phase=f * 2 + 1, limp=True)
        g = dent_pass(g, seed + 5)
        g = outline(g)
        frng = np.random.default_rng(seed + 20 + f)
        sparks(g, frng, 1, (C[4], C[3]))
        ys, xs = np.nonzero(g)
        smoke_wisp(g, int(np.median(xs)) - 2 + f, int(ys.min()) - 1, frng, 6)
        frames.append(g)
    return frames


def unit_frames(uid: str, seed: int):
    tex = hull_texture(uid)

    def make(**st):
        c = Canvas(tex)
        info = BUILDERS[uid](c, st)
        return c.g, info

    frames = demon_frames(uid, seed, make) if uid.startswith("demon") else ally_frames(uid, seed, make)
    # Bottom-centre on the union of the move frames; same shift for all.
    u = np.zeros_like(frames[0], dtype=bool)
    for f in frames[:4]:
        u |= (f != 0) & ~((f >= S[0]) & (f <= S[4]))
    x0, y0, x1, y1 = content_box(u)
    dx = (PAD + (CW - (x1 - x0)) // 2) - x0
    dy = (PAD + CH) - y1
    frames = [place(f, dx, dy, f"{uid} col {i}") for i, f in enumerate(frames)]
    return frames, (int(x1 - x0), int(y1 - y0))


def escape_pod():
    """Crew escape capsule with a cyan thruster (ally column 9)."""
    c = Canvas()
    for y in range(13, 20):
        for x in range(12, 21):
            e = ((x - 16) / 3.6) ** 2 + ((y - 16.2) / 3.4) ** 2
            if e <= 1:
                lit = (16 - x) / 3.6 + (16 - y) / 3.4
                c.put(x, y, H[4] if lit > 1 else (H[3] if lit > .1 else (H[2] if lit > -.9 else H[1])))
    c.put(17, 15, C[3]); c.put(18, 15, C[4]); c.put(17, 16, C[2])  # window
    c.put(12, 18, H[1]); c.put(20, 18, H[1])           # fins
    c.rect(15, 20, 18, 21, H[1])                       # nozzle
    g = outline(c.g)
    for x, y, code in ((15, 21, C[3]), (16, 21, C[4]), (17, 21, C[3]), (16, 22, C[4]), (15, 22, C[2]),
                       (17, 22, C[2]), (16, 23, C[2])):
        overlay(g, x, y, code)
    return g


# --------------------------------------------------------------------------
# Effects and missile
# --------------------------------------------------------------------------


def value_noise(seed, w, h, cell=3):
    rng = np.random.default_rng(seed)
    grid = rng.random((h // cell + 2, w // cell + 2)).astype(np.float32)
    ys, xs = np.mgrid[0:h, 0:w] / cell
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = xs - x0, ys - y0
    a = grid[y0, x0] * (1 - fx) + grid[y0, x0 + 1] * fx
    b = grid[y0 + 1, x0] * (1 - fx) + grid[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def heat_codes(heat, smoke_bias, shade):
    """Heat field -> fire ramp; below the fire threshold, smoke shaded by
    `shade` (0-1, lit from the upper left)."""
    g = np.zeros(heat.shape, dtype=np.int16)
    for thr, code in ((.36, W[2]), (.46, W[3]), (.58, W[4]), (.72, W[5]), (.86, W[6])):
        g[heat > thr + smoke_bias] = code
    sm = (heat > .06) & (g == 0)
    lv = np.digitize(shade + heat * .5, [.5, .8, 1.05])
    g[sm] = np.array([S[1], S[2], S[3], S[4]])[lv[sm]]
    return g


def pad_cell(g):
    full = blank()
    full[PAD: PAD + CH, PAD: PAD + CW] = g
    return full


def explosion_frames(seed, tex):
    """flash -> fireball -> big fireball -> rolling smoke -> smoke + debris
    -> thinning smoke and settled debris."""
    ys, xs = np.mgrid[0:CH, 0:CW].astype(np.float32)
    cx, base = 16, 23
    frames = []
    f0 = blank()                                       # 0 flash
    flash(f0, [(13, 18, np.array([1.0, 0]))], warm=True, size=2)
    for x in range(10, 23):
        if (x % 2 == 0):
            overlay(f0, x, 23, W[3], True)
    frames.append(f0)
    cfg = [(7, 6, 1.5, 0.0), (10, 8.5, 1.35, .04), (12, 9.5, 1.15, .14), (12.5, 9.5, .95, .3), (13, 9, .8, .5)]
    for f, (rx, ry, gain, bias) in enumerate(cfg, start=1):
        rise = max(0, f - 2) * 1.6
        cy = base - ry * .75 - rise
        n = value_noise(seed + f, CW, CH, 3)
        d = np.sqrt(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2)
        heat = (1 - d) * gain + (n - .5) * .55
        if tex is not None:
            heat += tex * .08
        heat[ys > base] = 0
        shade = np.clip(n * .8 + (cx - xs) / 40 + (cy - ys) / 30, 0, 1)
        g = heat_codes(np.clip(heat, 0, 1), bias, shade)
        rng = np.random.default_rng(seed + 100 + f)
        if f >= 3:  # smoke-dominant: fire survives only low down
            g[is_warm(g) & (ys < cy + 1)] = S[2]
        if f == 5:  # thinning: holes in the smoke
            g[(g >= S[0]) & (g <= S[4]) & (rng.random(g.shape) < .3)] = 0
        g = despeckle(g)
        if f >= 3:  # debris flung out, then settled on the ground
            for _ in range(7 if f < 5 else 5):
                a = rng.uniform(np.pi * 1.05, np.pi * 1.95)
                r = rng.uniform(rx * .9, rx * 1.25)
                x = int(cx + np.cos(a) * r)
                y = int(base - 1 if f == 5 else cy + np.sin(a) * r * .8)
                if 0 <= x < CW and 0 <= y < CH:
                    g[y, x] = H[0]
                    if x + 1 < CW:
                        g[y, x + 1] = H[1]
        frames.append(pad_cell(g))
    return frames


def scorch_decal(rng):
    g = np.zeros((CH, CW), dtype=np.int16)
    for y in range(CH):
        for x in range(CW):
            e = ((x - 16) / 11.5) ** 2 + ((y - 20.5) / 2.8) ** 2 + rng.random() * .18
            if e <= 1:
                g[y, x] = K[0] if e > .75 else (K[1] if e > .4 else K[2])
    for _ in range(5):
        x, y = int(rng.integers(8, 24)), int(rng.integers(19, 23))
        if g[y, x]:
            g[y, x] = K[3]
    return pad_cell(g)


def launch_flash():
    g = blank()
    flash(g, [(13, 14, np.array([1.0, 0]))], warm=True, size=3)
    for y in range(19, 24):                            # blast cone on the ground
        for x in range(16 - (y - 17), 17 + (y - 17)):
            if g[y + PAD, x + PAD] == 0 and (x + y) % 2 == 0:
                g[y + PAD, x + PAD] = W[3] if y < 22 else S[2]
    return g


def tracer_spark():
    g = blank()
    cx, cy = 16, 19
    pts = [((0, 0), W[6]), ((1, 0), W[6]), ((-1, 0), W[5]), ((0, -1), W[5]), ((0, 1), W[5]),
           ((2, 0), W[4]), ((-2, 0), W[4]), ((0, -2), W[4]), ((1, -1), W[5]), ((-1, -1), W[4]),
           ((2, -2), W[3]), ((-2, -2), W[3]), ((3, 0), W[3]), ((-3, 0), W[3]), ((0, -3), W[3]),
           ((4, -3), W[4]), ((-4, -2), W[4]), ((1, -5), W[3])]
    for (ox, oy), code in pts:
        overlay(g, cx + ox, cy + oy, code)
    for x in range(cx - 2, cx + 3):
        overlay(g, x, 23, S[2] if abs(x - cx) < 2 else S[1])
    return g


def small_blast(seed):
    n = value_noise(seed, CW, CH, 2)
    ys, xs = np.mgrid[0:CH, 0:CW].astype(np.float32)
    d = np.sqrt(((xs - 16) / 6) ** 2 + ((ys - 18.5) / 5) ** 2)
    heat = (1 - d) * 1.3 + (n - .5) * .45
    heat[ys > 23] = 0
    shade = np.clip(n * .8 + (16 - xs) / 30 + (18 - ys) / 20, 0, 1)
    return pad_cell(despeckle(heat_codes(np.clip(heat, 0, 1), 0, shade)))


def puff(seed, rx, ry, holes, light=0):
    rng = np.random.default_rng(seed)
    g = np.zeros((CH, CW), dtype=np.int16)
    cx, cy = 16, 23 - ry + .5
    n = value_noise(seed + 20, CW, CH, 2)
    for y in range(CH):
        for x in range(CW):
            e = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + (n[y, x] - .5) * .5
            if e > 1 or rng.random() < holes:
                continue
            lit = -(x - cx) / rx - (y - cy) / ry + (n[y, x] - .5)
            code = S[4] if lit > .8 else (S[3] if lit > -.2 else S[2])
            g[y, x] = max(S[1], code - light)
    return pad_cell(despeckle(g, 1))


def missile_frames(seed, tex):
    """Nose-on demon ground missile: dark iron warhead, four fins in an X,
    a ring of warm exhaust behind; two frames of exhaust flicker."""
    frames = []
    cx, cy = 15.5, 12.5
    ys, xs = np.mgrid[0:CH, 0:CW].astype(np.float32)
    dx, dy = xs - cx, ys - cy
    r = np.sqrt(dx ** 2 + dy ** 2)
    ang = np.arctan2(dy, dx)
    for f in range(2):
        g = np.zeros((CH, CW), dtype=np.int16)
        tongues = np.random.default_rng(seed + f).random(16)
        k = ((ang + np.pi) / (2 * np.pi) * 16).astype(int) % 16
        outer = 8.6 + tongues[k] * (2.2 if f == 0 else 1.6) + (.6 if f else 0)
        flame = (r > 4.5) & (r <= outer)
        heat = np.clip(1 - (r - 5.5) / (outer - 5.5 + 1e-3) + (value_noise(seed + 10 + f, CW, CH, 2) - .5) * .35, 0, 1)
        g[flame] = np.where(heat[flame] > .7, W[6] if f else W[5],
                            np.where(heat[flame] > .45, W[4], np.where(heat[flame] > .22, W[3], W[2])))
        for q in (1, 3, 5, 7):                         # fins on the diagonals
            a = q * np.pi / 4
            along = dx * np.cos(a) + dy * np.sin(a)
            across = -dx * np.sin(a) + dy * np.cos(a)
            fin = (np.abs(across) <= 1.1) & (along > 4) & (along <= 10.4)
            lit = q in (5, 7)
            code = np.where(across < 0, H[3] if lit else H[2], H[2] if lit else H[1])
            g[fin] = code[fin]
        body = r <= 5.6
        nz = np.sqrt(np.clip(1 - (r / 5.6) ** 2, 0, 1))
        light = (-dx * .55 - dy * .65) / 5.6 + nz * .6
        if tex is not None:
            light = light + tex * .12
        lv = np.digitize(light, [-.05, .25, .5, .72])
        g[body] = np.array(H)[lv[body]]
        ring = (r > 4.2) & (r <= 5.0)
        g[ring] = np.where(g[ring] >= H[3], H[2], H[1])
        g[r <= 1.2] = W[3]
        g[r <= .6] = W[5] if f == 0 else W[6]
        frames.append(outline(pad_cell(g), rim=False))
    return frames


# --------------------------------------------------------------------------
# Pack
# --------------------------------------------------------------------------


def build_atlas():
    s = spec()
    atlas = np.zeros((CH * ROWS, CW * COLS, 4), dtype=np.uint8)
    sizes = {"demon": [None] * 4, "ally": [None] * 4}

    def put_cell(row, col, g, tab):
        atlas[row * CH:(row + 1) * CH, col * CW:(col + 1) * CW] = render(g, tab)

    for u in s["units"]:
        frames, size = unit_frames(u["id"], u["seed"])
        tab = colour_table(s, u["side"], u["sector"])
        for col, g in enumerate(frames):
            put_cell(u["row"], col, g, tab)
        if u["side"] == "ally":
            put_cell(u["row"], 9, escape_pod(), tab)
        sizes[u["side"]][SECTORS.index(u["sector"])] = size
    fx = colour_table(s, "fx", None)
    ex = {e["id"]: e for e in s["extras"]}
    eseed, mseed = ex["explosion"]["seed"], ex["missile"]["seed"]
    for col, g in enumerate(explosion_frames(eseed, hull_texture("explosion"))):
        put_cell(8, col, g, fx)
    put_cell(8, 6, scorch_decal(np.random.default_rng(eseed)), fx)
    put_cell(8, 7, launch_flash(), fx)
    put_cell(8, 8, tracer_spark(), fx)
    put_cell(8, 9, small_blast(eseed + 7), fx)
    put_cell(8, 10, puff(eseed + 30, 3.6, 3.0, 0.0), fx)
    put_cell(8, 11, puff(eseed + 31, 6.5, 5.2, 0.0), fx)
    for col, g in enumerate(missile_frames(mseed, hull_texture("missile"))):
        put_cell(9, col, g, fx)
    for i, (rx, ry, holes) in enumerate(((6, 5, 0.0), (4.6, 4, .18), (3.2, 2.8, .42))):
        put_cell(9, 2 + i, puff(mseed + 50 + i, rx, ry, holes, light=1 if i == 2 else 0), fx)
    atlas[atlas[..., 3] == 0] = 0
    return atlas, sizes


DART = """// Generated by tools/ground_forces_assets.py (pack). Do not edit by hand:
// change art/families/ground-forces.json and rerun the pipeline.
//
// Cell layout of `assets/images/ground-forces.png` (stored 1x, one texel per
// pixel). Every cell is [cellW] x [cellH] texels; ground units stand
// bottom-centred on the cell's last row and are authored facing screen right
// (toward the central lane from the left band); the renderer mirrors them
// for the right band.

/// Grid contract of the ground-forces atlas (v2). Presentation only.
abstract final class GroundAtlas {
  static const String file = 'ground-forces.png';
  static const int cellW = 32, cellH = 24, columns = 12, rows = 10;

  /// Rows 0-3: demon ground units for sectors 0-3 (Krybor, Ringfall, Ember,
  /// Hollow). Rows 4-7: allied ground units for the same sectors.
  static int demonRow(int sector) => sector.clamp(0, 3);
  static int allyRow(int sector) => 4 + sector.clamp(0, 3);
  static const int effectRow = 8, missileRow = 9;

  // Demon unit columns.
  static const int moveCol = 0, moveFrames = 4; // 0-3 move cycle
  static const int telegraphCol = 4; // 4 launcher raised, 5 muzzle glow
  static const int fireCol = 6; // launch flash + recoil
  static const int postFireCol = 7; // smoking tube, settling
  static const int wreckCol = 8; // 8-9 burning hulk

  // Allied unit columns (allies never die: they are totalled and limp off).
  static const int allyMoveCol = 0, allyMoveFrames = 4; // 0-3
  static const int allyFireCol = 4; // 4-5 cyan muzzle flash
  static const int allyHitCol = 6; // sparks on the hull
  static const int allyLimpCol = 7; // 7-8 totalled: smoking, dragging
  static const int allyPodCol = 9; // crew escape pod

  // Effect row columns.
  static const int explosionCol = 0, explosionFrames = 6; // 0-5
  static const int scorchCol = 6;
  static const int launchFlashCol = 7;
  static const int tracerCol = 8;
  static const int smallBlastCol = 9;
  static const int smokeSmallCol = 10, smokeLargeCol = 11;

  // Missile row columns.
  static const int missileCol = 0; // 0-1 nose toward camera, exhaust flicker
  static const int smokeCol = 2; // 2-4 trail puffs (dense -> thin)

  /// Visible content box (texels, bottom-centred) per sector.
  static const List<(int, int)> demonSize = [DEMON];
  static const List<(int, int)> allySize = [ALLY];
}
"""


def write_dart(sizes):
    fmt = lambda xs: ", ".join(f"({w}, {h})" for w, h in xs)
    DART_OUT.write_text(DART.replace("DEMON", fmt(sizes["demon"])).replace("ALLY", fmt(sizes["ally"])))


def save_png(arr, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(path, optimize=True)


ROW_NAMES = ["0 demon krybor", "1 demon ringfall", "2 demon ember", "3 demon hollow",
             "4 ally krybor", "5 ally ringfall", "6 ally ember", "7 ally hollow", "8 effects", "9 missile"]
COL_NAMES = {
    "demon": ["move0", "move1", "move2", "move3", "teleA", "teleB", "fire", "post", "wreck", "wreck'"],
    "ally": ["move0", "move1", "move2", "move3", "fire", "fire'", "hit", "limp", "limp'", "pod"],
    "fx": ["exp0", "exp1", "exp2", "exp3", "exp4", "exp5", "scorch", "launch", "tracer", "blast", "puffS", "puffL"],
    "missile": ["missile", "missile'", "trail0", "trail1", "trail2"],
}


def contact(atlas):
    """Labelled 4x atlas with a cell grid; then every unit's frames over its
    sector ground tile at 2x and 1x arena scale (near / mid) and fogged at
    the horizon, enlarged 2x so phone-size readability can be judged."""
    Z = 4
    lab = 110
    aw, ah = COLS * CW * Z, ROWS * CH * Z
    pz = 2                                           # view zoom of the depth panels
    pw, ph = 10 * 66 + 8, 48 + 4 + 24 + 4 + 12       # panel, arena units
    comp_h = 8 * (ph * pz + 6)
    sheet = Image.new("RGB", (lab + max(aw, pw * pz), 22 + ah + 26 + comp_h), (12, 14, 20))
    d = ImageDraw.Draw(sheet)
    d.text((4, 4), "ground-forces.png v2: 12x10 cells of 32x24 texels, shown 4x (checker = transparent)",
           fill=(200, 210, 220))
    yy, xx = np.mgrid[0:ah, 0:aw]
    cb = np.full((ah, aw, 4), 255, dtype=np.uint8)
    cb[..., :3] = (34, 38, 48)
    cb[((yy // 8 + xx // 8) % 2) == 0, :3] = (27, 30, 39)
    bg = Image.fromarray(cb, "RGBA")
    bg.alpha_composite(Image.fromarray(atlas, "RGBA").resize((aw, ah), Image.Resampling.NEAREST))
    sheet.paste(bg.convert("RGB"), (lab, 22))
    for r in range(ROWS + 1):
        d.line([(lab, 22 + r * CH * Z), (lab + aw, 22 + r * CH * Z)], fill=(70, 76, 90))
    for c_ in range(COLS + 1):
        d.line([(lab + c_ * CW * Z, 22), (lab + c_ * CW * Z, 22 + ah)], fill=(70, 76, 90))
    for r in range(ROWS):
        names = COL_NAMES["demon" if r < 4 else "ally" if r < 8 else "fx" if r == 8 else "missile"]
        d.text((4, 22 + r * CH * Z + 40), ROW_NAMES[r], fill=(200, 210, 220))
        for c_, n in enumerate(names):
            d.text((lab + c_ * CW * Z + 3, 22 + r * CH * Z + 2), n, fill=(120, 130, 150))
    y0 = 22 + ah + 6
    d.text((4, y0), "on the sector ground tile: top 2x (near, z=z0), middle 1x (z=2z0), bottom-left horizon (z=9z0, fogged); view 2x",
           fill=(200, 210, 220))
    y0 += 20
    z0 = (520 - 172) / 2
    zfar = 14 * z0
    fog_of = lambda z: max(0.0, min(1.0, (zfar - z) / (zfar - 2.2 * z0)))
    for r in range(8):
        sector = SECTORS[r % 4]
        ground = Image.open(ROOT / f"assets/images/flyover-{sector}-ground.png").convert("RGB")
        tile = ground.crop((0, 0, (pw + 1) // 2, (ph + 1) // 2)).resize((pw, ph), Image.Resampling.NEAREST)
        panel = tile.convert("RGBA")
        ncol = 10

        def sprite(col, scale, fog):
            cell = Image.fromarray(np.ascontiguousarray(atlas[r * CH:(r + 1) * CH, col * CW:(col + 1) * CW]), "RGBA")
            w, h = max(1, round(CW * scale)), max(1, round(CH * scale))
            a = np.asarray(cell.resize((w, h), Image.Resampling.NEAREST)).astype(np.float32)
            a[..., :3] *= fog * (235 / 255)
            return Image.fromarray(a.astype(np.uint8), "RGBA")

        for col in range(ncol):
            panel.alpha_composite(sprite(col, 2, fog_of(z0)), (4 + col * 66, 0))
            panel.alpha_composite(sprite(col, 1, fog_of(2 * z0)), (4 + col * 66 + 16, 52))
        for i, col in enumerate((0, 5 if r < 4 else 4)):
            panel.alpha_composite(sprite(col, 2 / 9, fog_of(9 * z0)), (4 + i * 12, ph - 9))
        sheet.paste(panel.convert("RGB").resize((pw * pz, ph * pz), Image.Resampling.NEAREST),
                    (lab, y0 + r * (ph * pz + 6)))
        d.text((4, y0 + r * (ph * pz + 6) + 60), ROW_NAMES[r], fill=(200, 210, 220))
    CONTACT_OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(CONTACT_OUT, optimize=True)


def cmd_offline(_args) -> None:
    atlas, sizes = build_atlas()
    assert atlas.shape == (ROWS * CH, COLS * CW, 4)
    assert set(np.unique(atlas[..., 3]).tolist()) <= {0, 255}
    save_png(atlas, ATLAS_OUT)
    write_dart(sizes)
    contact(atlas)
    print("atlas", ATLAS_OUT.relative_to(ROOT), atlas.shape[1], "x", atlas.shape[0],
          "demon", sizes["demon"], "ally", sizes["ally"])


def cmd_pack(args) -> None:
    if RAW.exists():
        write_sources()
    cmd_offline(args)


def cmd_all(args) -> None:
    cmd_jobs(args)
    cmd_run(args)
    cmd_ingest(args)
    cmd_pack(args)


# ==MAIN==
def main(argv=None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("jobs")
    r = sub.add_parser("run")
    r.add_argument("--url", default=os.environ.get("COMFY_URL", "http://studio:8188"))
    r.add_argument("--only", help="job id prefix filter, e.g. demon-krybor")
    r.add_argument("--force", action="store_true")
    sub.add_parser("ingest")
    sub.add_parser("pack")
    sub.add_parser("offline")
    a = sub.add_parser("all")
    a.add_argument("--url", default=os.environ.get("COMFY_URL", "http://studio:8188"))
    a.add_argument("--only")
    a.add_argument("--force", action="store_true")
    args = p.parse_args(argv)
    {"jobs": cmd_jobs, "run": cmd_run, "ingest": cmd_ingest, "pack": cmd_pack,
     "offline": cmd_offline, "all": cmd_all}[args.cmd](args)


if __name__ == "__main__":
    main()
