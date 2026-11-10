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
CW, CH = 40, 32                   # atlas cell (texels)
COLS, ROWS = 16, 16
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




BUILDERS = {
    "demon-krybor": build_demon_krybor, "demon-ringfall": build_demon_ringfall,
    "demon-ember": build_demon_ember, "demon-hollow": build_demon_hollow,
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


# --------------------------------------------------------------------------
# Allied units (v3): seen from behind and above, driving up the ground plane
# toward the horizon with the player's convoy.  Authored with a tiny
# deterministic solid rasteriser on the texel grid: x right, f forward
# (toward the horizon), u up; an oblique projection with the flyover's
# forward foreshortening.  Each vehicle is two layers that share the cell
# frame: the hull (tread / wheel / gait cycle) and a turret drawn at one of
# ALLY_ANGLES (screen angles from straight ahead toward screen right; the
# renderer mirrors the cell for the left), so the turret traverses toward
# the demon unit it fights.  Infantry squads are one layer (walk, kneel and
# fire frames).
# --------------------------------------------------------------------------

FY, UY = 0.55, 0.85            # screen rows per texel of depth / of height
OX, OY = CW / 2, float(CH)     # geometric bottom centre of the cell
VIEW = np.array([0.0, UY, -FY])  # direction the camera looks along (world)
LIGHT = np.array([-0.5, -0.35, 0.8]) / np.linalg.norm([-0.5, -0.35, 0.8])
# Turret screen angles (degrees from straight ahead toward screen right);
# the depth-plane angle of each frame is atan(tan(screen) * FY / ... ).
ALLY_ANGLES = (0.0, 22.5, 45.0, 67.5, 90.0)
CREW = 60                      # crew helmet (code); 61 helmet light, 62 visor


def plane_theta(screen_deg):
    """Ground-plane yaw whose barrel points along `screen_deg` on screen."""
    if screen_deg >= 89.9:
        return 90.0
    return float(np.degrees(np.arctan(np.tan(np.radians(screen_deg)) * FY)))


def shade(n):
    lum = float(np.dot(n, LIGHT))
    return H[3] if lum >= .62 else (H[2] if lum >= .3 else H[1])


def fill_poly(c, pts, fn):
    """Even-odd fill of a screen polygon, sampling texel centres."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    n = len(pts)
    for j in range(int(np.floor(min(ys))), int(np.ceil(max(ys))) + 1):
        for i in range(int(np.floor(min(xs))), int(np.ceil(max(xs))) + 1):
            px, py = i + .5, j + .5
            inside = False
            for k in range(n):
                (x0, y0), (x1, y1) = pts[k], pts[(k + 1) % n]
                if (y0 > py) != (y1 > py) and px < x0 + (py - y0) * (x1 - x0) / (y1 - y0):
                    inside = not inside
            if inside:
                code = fn(i, j)
                if code:
                    c.put(i, j, code)


class View:
    """Projection of one rigid part (yaw `theta` degrees about `pivot`)."""

    def __init__(self, c, theta=0.0, pivot=(0.0, 0.0), lift=0.0):
        self.c = c
        self.t = np.radians(theta)
        self.p = pivot
        self.lift = lift

    def w(self, x, f, u):
        px, pf = self.p
        ct, st = np.cos(self.t), np.sin(self.t)
        return np.array([px + (x - px) * ct + (f - pf) * st,
                         pf - (x - px) * st + (f - pf) * ct, u + self.lift])

    @staticmethod
    def s(p):
        return OX + p[0], OY - p[1] * FY - p[2] * UY

    def at(self, x, f, u):
        return self.s(self.w(x, f, u))

    def dot(self, x, f, u, code):
        X, Y = self.at(x, f, u)
        self.c.put(int(np.floor(X)), int(np.floor(Y)), code)

    def solid(self, faces, fn=None):
        """faces: list of (world points, tag).  Back faces are culled
        against the solid's centroid; the rest are drawn far to near."""
        cen = np.mean([p for pts, _ in faces for p in pts], axis=0)
        todo = []
        for pts, tag in faces:
            a, b, e = pts[0], pts[1], pts[2]
            n = np.cross(b - a, e - a)
            ln = np.linalg.norm(n)
            if ln < 1e-9:
                continue
            n = n / ln
            fc = np.mean(pts, axis=0)
            if np.dot(n, fc - cen) < 0:
                n = -n
            if np.dot(n, VIEW) >= -1e-3:
                continue
            todo.append((float(np.dot(fc, VIEW)), pts, tag, n))
        for _, pts, tag, n in sorted(todo, key=lambda t: -t[0]):
            base = shade(n)
            scr = [self.s(p) for p in pts]
            fill_poly(self.c, scr, (lambda i, j, tag=tag, base=base, n=n:
                                    camo(i, j, fn(tag, i, j, base, n) if fn else base, n)))

    def prism(self, poly, u0, u1, fn=None):
        """Vertical prism over a polygon in the (x, f) plane."""
        bot = [self.w(x, f, u0) for x, f in poly]
        top = [self.w(x, f, u1) for x, f in poly]
        faces = [(top, "top"), (bot, "bottom")]
        for k in range(len(poly)):
            k2 = (k + 1) % len(poly)
            faces.append(([bot[k], bot[k2], top[k2], top[k]], f"side{k}"))
        self.solid(faces, fn)

    def box(self, x0, x1, f0, f1, u0, u1, fn=None):
        self.prism([(x0, f0), (x1, f0), (x1, f1), (x0, f1)], u0, u1, fn)

    def along_x(self, prof, x0, x1, fn=None):
        """Extrusion along x of a profile in the (f, u) plane (wheels,
        sloped hulls): profile edges become the visible faces."""
        a = [self.w(x0, f, u) for f, u in prof]
        b = [self.w(x1, f, u) for f, u in prof]
        faces = [(a, "end"), (b, "end")]
        for k in range(len(prof)):
            k2 = (k + 1) % len(prof)
            faces.append(([a[k], a[k2], b[k2], b[k]], f"edge{k}"))
        self.solid(faces, fn)

    def rod(self, a, b, width=1.0, codes=(H[3], H[2], H[1])):
        """A thin cylinder (barrels, legs, antennas) between local points."""
        A, B = np.array(self.at(*a)), np.array(self.at(*b))
        d = B - A
        L = max(1e-6, np.linalg.norm(d))
        nrm = np.array([-d[1], d[0]]) / L
        if nrm[0] + nrm[1] > 0:                        # toward the upper left
            nrm = -nrm
        n = int(L * 2) + 1
        offs = np.linspace(-(width - 1) / 2, (width - 1) / 2, max(1, int(round(width * 2)) - 1)) \
            if width > 1 else [0.0]
        for o in offs:
            code = codes[0] if o > .25 else (codes[1] if o > -.25 else codes[2])
            if width <= 1:
                code = codes[1]
            for t in range(n + 1):
                p = A + d * (t / n) + nrm * o
                self.c.put(int(np.floor(p[0])), int(np.floor(p[1])), code)
        return B


def octagon(cf, cu, r):
    k = r * .41
    return [(cf - k, cu - r), (cf + k, cu - r), (cf + r, cu - k), (cf + r, cu + k),
            (cf + k, cu + r), (cf - k, cu + r), (cf - r, cu + k), (cf - r, cu - k)]


def tread_fn(phase, stopped=False):
    """Track / tyre surface: cleats crawl up the screen one row per frame."""
    def fn(tag, i, j, base, n):
        if tag in ("top", "edge1", "edge2", "edge3", "edge4", "edge5") or n[2] > .5:
            ph = 0 if stopped else phase
            return H[2] if (j + ph) % 3 == 0 else (H[1] if (j + ph) % 3 == 1 else H[0])
        return H[0] if base <= H[2] else H[1]
    return fn


CAMO = {"style": None, "noise": None}


def set_camo(style, seed):
    CAMO["style"] = style
    CAMO["noise"] = value_noise(seed, CW + 2, CH + 2, 3) if style else None


def camo(i, j, code, n):
    """Sector camouflage over hull ramp texels (screen space): Krybor snow
    blotches, Ringfall patch plates, teal disruptive bands elsewhere."""
    st, nz = CAMO["style"], CAMO["noise"]
    if not st or code is None or not (H[1] <= code <= H[3]) or not (0 <= i < CW and 0 <= j < CH):
        return code
    v = nz[j, i]
    top = n[2] > .5
    if st == "snow":
        return H[4] if (v > .6 and top) else (H[3] if v > .7 else code)
    if st == "patch":
        k = ((i // 3) * 7 + (j // 2) * 13) % 9
        return H[1] if k == 0 else (H[3] if k == 4 and top else code)
    if st == "teal":
        return C[1] if v > .64 else (H[1] if v < .22 and not top else code)
    return code


def bevel(g):
    """Lit edge where a top face meets the rear face below it."""
    out = g.copy()
    below = np.roll(g, -1, 0)
    out[(g == H[3]) & ((below == H[2]) | (below == H[1]))] = H[4]
    return out


def hull_fn(deck=None):
    """Hull faces: lit top deck, mid rear plate; `deck(i, j)` may override."""
    def fn(tag, i, j, base, n):
        if deck and n[2] > .5:
            d = deck(i, j)
            if d:
                return d
        return base
    return fn


def track(v, x0, x1, length, phase, height=3.0, stopped=False, broken=False):
    """Tracked running gear: an elongated track with sloped ends."""
    prof = [(0.6, 0), (length - .6, 0), (length, 1.4), (length - .8, height),
            (.6, height), (-.2, 1.6)]
    v.along_x(prof, x0, x1, tread_fn(phase, stopped))
    # Rear sprocket hub (rotates with the phase) on the track's rear face.
    cx = (x0 + x1) / 2
    a = np.radians(phase * 90 + 45)
    v.dot(cx, 0, 1.4, H[2])
    if not stopped:
        v.dot(cx + np.cos(a) * .9, 0, 1.4 + np.sin(a) * .9, H[3])
    if broken:                                     # thrown track: a gap
        for k in range(3):
            v.dot(cx - .5 + k * .5, length * .45, height, EMPTY)
            v.dot(cx - .5 + k * .5, length * .45 + .8, height, EMPTY)


def wheels(v, x0, x1, fs, r, phase, flat=-1):
    for k, f in sorted(enumerate(fs), key=lambda t: -t[1]):
        if k == flat:
            v.along_x([(f - r, 0), (f + r, 0), (f + r * .6, r * .9), (f - r * .6, r * .9)],
                      x0, x1, lambda *a: H[0])
            continue
        v.along_x(octagon(f, r, r), x0, x1, tread_fn(phase))
        hub = x0 if x0 < 0 else x1
        v.dot(hub, f, r, H[3])


def lights(v, pts, code):
    for x, f, u in pts:
        v.dot(x, f, u, code)


def crew_head(v, x, f, u, visor=False):
    """A crew member's helmet and shoulders in a hatch (local coords)."""
    v.box(x - 1.4, x + 1.4, f - 1, f + 1, u, u + 1.2, lambda *a: H[1])
    v.box(x - .9, x + .9, f - .7, f + .8, u + 1.2, u + 2.6,
          lambda tag, i, j, base, n: 61 if n[2] > .5 else CREW)
    if visor:
        v.dot(x + .2, f + .9, u + 1.9, C[4])


# -- hull layers -------------------------------------------------------------
# Each hull(c, phase, limp) draws running gear and hull; each turret(c, theta,
# limp) draws the rotating part and returns the muzzle point (screen).


def chevron(i, j, cx, cy):
    """Friendly IFF chevron on a roof (screen coords)."""
    dx = abs(i + .5 - cx)
    return C[3] if abs((j + .5 - cy) + dx * .6) < .55 and dx < 3 else None


def hull_rover(c, ph, limp):          # Krybor A: six-wheel scout rover
    v = View(c)
    fs = (3.0, 9.4, 15.8)
    wheels(v, -11.6, -7.6, fs, 2.8, ph, flat=0 if limp else -1)
    wheels(v, 7.6, 11.6, fs, 2.8, ph)
    prof = [(0, 2), (18, 2), (19.2, 3.6), (16.5, 6.4), (3, 6.6), (.4, 5)]
    grille = lambda i, j: (H[1] if 21 <= j <= 22 and i % 2 == 0 and abs(i + .5 - OX) < 5 else None)
    v.along_x(prof, -7.4, 7.4, hull_fn(grille))
    v.box(-8.2, -7.2, 1, 17.5, 4.4, 5.2, lambda *a: C[2])    # teal side rails
    v.box(7.2, 8.2, 1, 17.5, 4.4, 5.2, lambda *a: C[2])
    # Spare wheel on the rear plate, tail lamps, exhaust.
    v.along_x(octagon(-.3, 4, 1.6), -2, 2, lambda tag, i, j, base, n: H[0] if base < H[3] else H[1])
    v.dot(0, -1, 4.2, H[3])
    lights(v, [(-6.2, 0, 4.4), (6.2, 0, 4.4)], C[0] if limp else C[4])
    lights(v, [(-6.2, 0, 3.4), (6.2, 0, 3.4)], C[2])
    v.rod((-5.6, 3, 6.6), (-7, 3.4, 14), 1, (H[3],) * 3)  # whip antenna
    v.dot(-7.1, 3.4, 14.2, C[3] if ph % 2 == 0 else C[1])
    v.box(3, 6, 12, 15, 6.4, 7.6)                         # stowage box
    return {"dust": [(-9.6, 0, 0), (9.6, 0, 0)]}


def turret_rover(c, theta, limp):
    v = View(c, theta, (0, 8.5))
    v.prism([(-4.4, 4.6), (4.4, 4.6), (5.4, 7.4), (4.2, 11.8), (-4.2, 11.8), (-5.4, 7.4)], 6.6, 9.2)
    v.box(-1.6, 1.6, 11.4, 12.8, 7, 8.8)                 # mantlet
    m = v.rod((-.8, 12.6, 7.9), (-.8, 19.5, 8.1), 1, (H[1],) * 3)
    v.rod((.8, 12.6, 7.9), (.8, 19.5, 8.1), 1, (H[1],) * 3)
    v.dot(-3.6, 6, 9.2, C[3]); v.dot(3.6, 6, 9.2, C[3])
    v.dot(0, 5, 9.2, C[2])
    crew_head(v, -1.8, 7.6, 9.2)
    return m


def hull_apc(c, ph, limp):           # Krybor B: tall tracked snow APC
    v = View(c)
    track(v, -11.5, -7.4, 19, ph, 3.2, stopped=limp, broken=limp)
    track(v, 7.4, 11.5, 19, ph, 3.2, stopped=limp)
    prof = [(0, 1.8), (19, 1.8), (19.6, 4.5), (17, 8.2), (1, 8.2), (0, 7)]
    deck = lambda i, j: (H[1] if 20 <= j <= 21 and i % 2 == 0 and abs(i + .5 - OX) < 6 else None)
    v.along_x(prof, -9.6, 9.6, hull_fn(deck))
    v.box(-9.8, 9.8, 4, 6, 5.2, 5.8)                   # side stowage rails
    # Rear ramp door with a cyan stripe and two lamps.
    v.box(-3.5, 3.5, -.4, 0, 2.4, 7.2, lambda tag, i, j, base, n: H[1] if n[1] < -.5 else base)
    v.rod((-9, -.2, 6.6), (9, -.2, 6.6), 1, (C[2],) * 3)
    lights(v, [(-8.2, -.2, 3.2), (8.2, -.2, 3.2)], C[0] if limp else C[4])
    v.rod((7, 15, 8.2), (8.5, 15.5, 15), 1, (H[3],) * 3)
    return {"dust": [(-9.5, 0, 0), (9.5, 0, 0)]}


def turret_apc(c, theta, limp):
    v = View(c, theta, (0, 11))
    v.prism([(-2.8, 9), (2.8, 9), (3.4, 11), (2.8, 13.4), (-2.8, 13.4), (-3.4, 11)], 8.2, 9.8)
    m = v.rod((0, 13, 9.1), (0, 18.5, 9.4), 1, (H[1],) * 3)
    v.dot(0, 11, 9.8, C[3])
    crew_head(v, 0, 10.4, 9.8)
    return m


def hull_halftrack(c, ph, limp):     # Ringfall A: salvage half-track technical
    v = View(c)
    track(v, -11, -7.6, 10, ph, 3, stopped=limp, broken=limp)
    track(v, 7.6, 11, 10, ph, 3, stopped=limp)
    wheels(v, -10.6, -7.8, (16,), 2.6, ph)
    wheels(v, 7.8, 10.6, (16,), 2.6, ph, flat=0 if limp else -1)
    bed = [(0, 2.2), (11.5, 2.2), (11.5, 5), (0, 5)]   # open cargo bed
    patch = lambda i, j: (H[1] if (i // 3 + j // 2) % 5 == 0 else None)
    v.along_x(bed, -8.4, 8.4, hull_fn(patch))
    v.box(-8.4, 8.4, 0, 11.5, 5, 5.9, lambda tag, i, j, base, n: H[0] if n[2] > .5 and abs(i + .5 - OX) < 7 and 22 <= j <= 26 else base)
    cab = [(11.5, 2.2), (19, 2.2), (19.4, 4.6), (17.8, 6.2), (14.5, 8.6), (11.5, 8.6)]
    v.along_x(cab, -7.4, 7.4, hull_fn(lambda i, j: C[1] if j <= 18 and abs(i + .5 - OX) < 5 else None))
    lights(v, [(-7.6, 0, 4.3), (7.6, 0, 4.3)], C[0] if limp else C[3])
    v.rod((-8.2, .1, 2.6), (8.2, .1, 2.6), 1, (C[2],) * 3)
    v.rod((6, 12, 8.6), (6.8, 12.4, 15), 1, (H[3],) * 3)
    v.dot(6.9, 12.4, 15.2, C[3] if ph < 2 else C[1])
    return {"dust": [(-9.3, 0, 0), (9.3, 0, 0)]}


def turret_halftrack(c, theta, limp):
    v = View(c, theta, (0, 5.5))
    v.prism([(-1.6, 4), (1.6, 4), (2.2, 5.5), (1.6, 7), (-1.6, 7), (-2.2, 5.5)], 5.9, 8.2)  # pintle
    v.box(-3.4, 3.4, 7.2, 8, 7.4, 9.4)                 # gun shield
    m = v.rod((-.8, 8, 8.4), (-.8, 14.5, 9), 1, (H[1],) * 3)
    v.rod((.8, 8, 8.4), (.8, 14.5, 9), 1, (H[1],) * 3)
    v.dot(-3, 7.6, 9.4, C[3]); v.dot(3, 7.6, 9.4, C[3])
    crew_head(v, 0, 5.2, 7.2)                          # standing gunner
    return m


def hull_mbt(c, ph, limp):           # Ember A: heavy foundry battle tank
    v = View(c)
    track(v, -12, -7.6, 20, ph, 3.6, stopped=limp, broken=limp)
    track(v, 7.6, 12, 20, ph, 3.6, stopped=limp)
    prof = [(0, 1.6), (20, 1.6), (20.8, 3.4), (18, 5.4), (1.4, 5.6), (0, 4.4)]
    grille = lambda i, j: (H[0] if 25 <= j <= 27 and (i % 2 == 0) and abs(i + .5 - OX) < 6 else None)
    v.along_x(prof, -8, 8, hull_fn(grille))
    v.box(7.8, 12.4, 1.2, 19.4, 3.6, 4.4,
          lambda tag, i, j, base, n: C[2] if n[2] > .5 and j == 26 else base)
    v.box(-12.4, -7.8, 1.2, 19.4, 3.6, 4.4,
          lambda tag, i, j, base, n: C[2] if n[2] > .5 and j == 26 else base)
    lights(v, [(-10, 1.2, 3.6), (10, 1.2, 3.6)], C[0] if limp else C[4])
    v.rod((-3, .2, 4), (3, .2, 4), 1, (H[0],) * 3)
    return {"dust": [(-9.8, 0, 0), (9.8, 0, 0)]}




def turret_mbt(c, theta, limp):
    v = View(c, theta, (0, 9))
    roof = (lambda i, j: chevron(i, j, OX, 20.6)) if theta < 30 else (lambda i, j: None)
    v.prism([(-5.6, 4.6), (5.6, 4.6), (6.6, 7), (5.2, 13.4), (-5.2, 13.4), (-6.6, 7)], 5.6, 8.6,
            hull_fn(roof))
    v.box(-6.9, -5.8, 5.2, 9, 6, 8, lambda *a: H[1])      # stowage racks
    v.box(5.8, 6.9, 5.2, 9, 6, 8, lambda *a: H[1])
    v.box(-1.5, 1.5, 13, 14.6, 6.2, 8.2)                 # mantlet
    v.rod((0, 14.4, 7.2), (0, 24.5, 7.4), 2, (H[3], H[2], H[1]))
    v.box(-.9, .9, 23.6, 25.4, 6.7, 8, lambda *a: H[1])  # muzzle brake
    v.dot(-4.6, 6, 8.6, C[2]); v.dot(-3.8, 6, 8.6, C[3])
    crew_head(v, 2.6, 7.4, 8.6)
    v.rod((-4.4, 5, 8.6), (-5.4, 4.4, 15), 1, (H[3],) * 3)
    return v.at(0, 25.4, 7.4)


def hull_spg(c, ph, limp):           # Ember B: self-propelled howitzer
    v = View(c)
    track(v, -11.6, -7.6, 21, ph, 3.4, stopped=limp, broken=limp)
    track(v, 7.6, 11.6, 21, ph, 3.4, stopped=limp)
    prof = [(0, 1.6), (21, 1.6), (21.6, 3.2), (19.6, 5), (1, 5), (0, 4)]
    v.along_x(prof, -8.2, 8.2)
    v.box(-2.6, 2.6, -1.2, 0, 1.2, 2.6, lambda *a: H[1])  # recoil spade
    lights(v, [(-7.4, 0, 3.8), (7.4, 0, 3.8)], C[0] if limp else C[4])
    v.rod((-8, 0, 2.2), (8, 0, 2.2), 1, (C[2],) * 3)
    return {"dust": [(-9.6, 0, 0), (9.6, 0, 0)]}


def turret_spg(c, theta, limp):
    v = View(c, theta, (0, 7.5))
    v.prism([(-6.2, 1), (6.2, 1), (6.6, 3), (6.2, 13), (-6.2, 13), (-6.6, 3)], 5, 10.2)
    v.box(-6.4, 6.4, 1.2, 2, 6, 9,
          lambda tag, i, j, base, n: C[2] if n[1] < -.5 and j % 3 == 0 else base)
    el = np.radians(24)
    L = 13
    a = (0, 13, 8.4)
    b = (0, 13 + L * np.cos(el), 8.4 + L * np.sin(el))
    v.box(-1.6, 1.6, 12.6, 14.2, 7, 9.6)
    v.rod(a, b, 2, (H[3], H[2], H[1]))
    tip = (0, b[1] + .9 * np.cos(el), b[2] + .9 * np.sin(el))
    v.rod(b, tip, 2.4, (H[1],) * 3)
    v.dot(-4.6, 4, 10.2, C[3]); v.dot(4.6, 4, 10.2, C[3])
    crew_head(v, -3.6, 9.4, 10.2)
    return v.at(*tip)


MECH_BOB = (0, 1, 0, 1)
ALLY_CAMO = {"rover": "snow", "apc": "snow", "halftrack": "patch", "mbt": "teal",
             "spg": "teal", "mech": "teal"}


def hull_mech(c, ph, limp):          # Hollow A: resistance walker (legs, hips)
    bob = 0 if limp else MECH_BOB[ph]
    v = View(c, lift=bob)
    legs = []
    for x, grp in ((-6, 0), (6, 1)):
        lift, sx = gait(ph, grp)
        if limp and grp == 0:
            lift, sx = 0, -3
        foot = (x * 1.3, 7 + sx * 2, lift * 1.4 - bob)
        knee = (x * 1.45, 4 + sx * .8, 5.8)
        hip = (x * 1.1, 7, 10)
        legs.append((foot, knee, hip))
    for foot, knee, hip in sorted(legs, key=lambda t: -t[0][1]):
        fx, ff, fu = foot
        v.rod(hip, knee, 3)
        v.rod(knee, (fx, ff, fu + 1.2), 2.4)
        v.box(fx - 2, fx + 2, ff - 2, ff + 2.6, fu, fu + 1.2,
              lambda tag, i, j, base, n: H[1] if n[2] < .5 else H[2])
        v.dot(knee[0], knee[1], knee[2], C[2] if not limp else C[0])
    v.box(-6.6, 6.6, 5, 9.4, 9.4, 11.6)                 # hips
    return {"dust": [(-5.5, 6, 0), (5.5, 6, 0)]}


def turret_mech(c, theta, limp):
    v = View(c, theta, (0, 7))
    v.prism([(-6, 2.4), (6, 2.4), (7, 6), (5, 11.6), (-5, 11.6), (-7, 6)], 11.6, 17.6)
    for x0, x1 in ((-10, -7), (7, 10)):                 # arm gun pods
        v.box(x0, x1, 4, 11, 12, 14.8)
    v.rod((8.5, 11, 13.4), (8.5, 17.5, 13.4), 1.5, (H[2], H[1], H[0]))
    v.rod((-8.5, 11, 13.4), (-8.5, 17.5, 13.4), 1.5, (H[2], H[1], H[0]))
    for x in (-3, -1, 1, 3):                            # engine vents glow
        v.dot(x, 2.4, 14.6, C[2])
    v.box(-3, 3, 10, 12, 15.6, 17.4,
          lambda tag, i, j, base, n: C[3] if n[1] > -.2 else C[1])
    v.rod((4.4, 3.4, 17.6), (5.2, 2.8, 23.5), 1, (H[3],) * 3)
    v.dot(5.3, 2.7, 23.8, C[3])
    return v.at(8.5, 17.5, 13.4)


# -- infantry ----------------------------------------------------------------

def soldier(c, x, f, ph, mode, heavy=False, rocket=False):
    X, Y = View.s((x, f, 0))
    X, Y = int(np.floor(X)), int(np.floor(Y)) - 1
    w = 4 if heavy else 3
    lx = X - w // 2
    bob = 1 if (mode in ("walk", "run") and ph % 2 == 1) else 0
    kneel = mode in ("kneel", "fire")
    if kneel:
        c.rect(lx, Y - 1, lx + w, Y + 1, H[1])
        c.put(lx + w, Y, H[0])
        top = Y - 1
    else:
        stride = 2 if mode == "run" else 1
        la = (1, 0, 0, 0)[ph] * stride
        lb = (0, 0, 1, 0)[ph] * stride
        c.rect(lx, Y - 2 + la - bob, lx + 1, Y + 1 - bob, H[1])
        c.rect(lx + w - 1, Y - 2 + lb - bob, lx + w, Y + 1 - bob, H[1])
        c.put(lx, Y - bob, H[0]); c.put(lx + w - 1, Y - bob, H[0])
        top = Y - 2 - bob
    lean = 1 if mode == "run" else 0
    t0 = top - 3 - (1 if heavy else 0)
    c.rect(lx + lean, t0, lx + w + lean, top, H[3])          # torso
    c.rect(lx + lean, t0, lx + 1 + lean, top, H[4])
    c.put(lx + lean - 1, t0 + 1, H[2]); c.put(lx + w + lean, t0 + 1, H[2])  # arms
    c.rect(lx + lean + 1, t0 + 1, lx + lean + w - (0 if heavy else 1), top - (0 if heavy else 1), H[1])  # pack
    c.put(lx + w - 1 + lean, t0, C[3])                       # pack lamp
    hx = lx + lean + (1 if heavy else 0)
    c.rect(hx, t0 - 2, hx + 3 if heavy else hx + 3, t0, CREW)  # helmet
    c.rect(hx, t0 - 2, hx + 2, t0 - 1, 61)
    if rocket:                                               # launcher tube
        for k in range(6):
            c.put(lx - 1 + k, t0 - k // 2, H[1] if k < 5 else C[3])
    rx = lx + w + lean
    if kneel:
        pts = [(rx, t0 + 1), (rx, t0), (rx + 1, t0 - 1), (rx + 1, t0 - 2)]
    elif mode == "run":
        pts = [(rx - 1, t0 + 2), (rx, t0 + 1), (rx + 1, t0 + 1)]
    else:
        pts = [(rx, t0 + 2), (rx, t0 + 1), (rx, t0), (rx + 1, t0 - 1)]
    for px, py in pts:
        c.put(px, py, H[0])
    tip = pts[-1]
    return (tip[0] + .5, tip[1] + .5)


SQUADS = {
    "militia": [(-7.5, 3.5), (6.5, 2.0), (-1.5, 9.0), (8.5, 11.5), (-9.5, 13)],
    "heavy": [(-6.5, 3), (6.5, 1.5), (0.0, 9.5)],
}


def squad(c, kind, ph, mode):
    heavy = kind == "heavy"
    members = SQUADS[kind][:-1] if mode == "run" else SQUADS[kind]
    tips = []
    for k, (x, f) in sorted(enumerate(members), key=lambda t: -t[1][1]):
        tips.append((k, soldier(c, x, f, (ph + k) % 4, mode, heavy=heavy, rocket=heavy and k == 2)))
    tips.sort()
    return [t for _, t in tips]


def squad_flash(g, tips, which):
    for k, (x, y) in enumerate(tips):
        if k in which:
            overlay(g, x, y - 1.5, C[4])
            for ox, oy in ((1, 0), (-1, 0), (0, -1)):
                overlay(g, x + ox, y - 1.5 + oy, C[3], True)
            overlay(g, x, y - 3.5, C[2], True)


# kind: 0 vehicle (hull + turret layers), 1 infantry squad, 2 walker (hull
# + torso layers; the torso bobs with the gait).
ALLY_VARIANTS = {
    "rover": (0, hull_rover, turret_rover),
    "apc": (0, hull_apc, turret_apc),
    "halftrack": (0, hull_halftrack, turret_halftrack),
    "mbt": (0, hull_mbt, turret_mbt),
    "spg": (0, hull_spg, turret_spg),
    "mech": (2, hull_mech, turret_mech),
    "militia": (1, None, None),
    "heavy": (1, None, None),
}


def brighten(g):
    g = g.copy()
    m = is_hull(g)
    g[m] = np.minimum(H[4], g[m] + 1)
    return g


def ally_frames_v3(kind_id, seed, tex):
    """Ally row: 0-3 move, 4 hit, 5-6 totalled, 7 pod, 8-12 turret angles
    (vehicles) or 8-9 fire / 10 kneel (squads).  Returns frames (None for
    empty cells), muzzle points per turret angle (cell coordinates) and
    the per-move-frame torso bob."""
    kind, hull, turret = ALLY_VARIANTS[kind_id]
    frames = [None] * COLS
    rng = np.random.default_rng(seed)
    set_camo(ALLY_CAMO.get(kind_id), seed)
    if kind == 1:
        for ph in range(4):
            c = Canvas(); squad(c, kind_id, ph, "walk"); frames[ph] = outline(c.g)
        c = Canvas(); squad(c, kind_id, 0, "walk")
        g = outline(brighten(c.g)); sparks(g, np.random.default_rng(seed + 3), 2, (C[4], C[3]))
        frames[4] = g
        for f in range(2):
            c = Canvas(); squad(c, kind_id, f * 2 + 1, "run"); frames[5 + f] = outline(c.g)
        frames[7] = escape_pod()
        n = len(SQUADS[kind_id])
        tips = None
        for f, which in enumerate((set(range(0, n, 2)), set(range(1, n, 2)))):
            c = Canvas(); tips = squad(c, kind_id, 0, "fire")
            g = outline(c.g); squad_flash(g, tips, which); frames[8 + f] = g
        c = Canvas(); squad(c, kind_id, 0, "kneel"); frames[10] = outline(c.g)
        return frames, [tips[0]] * len(ALLY_ANGLES), (0, 0, 0, 0)
    for ph in range(4):
        c = Canvas(tex); hull(c, ph, False); frames[ph] = outline(bevel(c.g))
    c = Canvas(tex); hull(c, 0, False)
    g = outline(brighten(bevel(c.g))); sparks(g, np.random.default_rng(seed + 3), 3, (C[4], C[3]))
    frames[4] = g
    for f in range(2):
        c = Canvas(tex); hull(c, f * 2 + 1, True)
        g = outline(dent_pass(c.g, seed + 5 + f))
        sparks(g, np.random.default_rng(seed + 20 + f), 1, (C[4], C[3]))
        frames[5 + f] = g
    frames[7] = escape_pod()
    muzzles = []
    for k, a in enumerate(ALLY_ANGLES):
        c = Canvas(tex)
        mz = turret(c, plane_theta(a), False)
        frames[8 + k] = outline(bevel(c.g))
        muzzles.append((float(mz[0]), float(mz[1])))
    _ = rng
    set_camo(None, 0)
    return frames, muzzles, MECH_BOB if kind == 2 else (0, 0, 0, 0)


def escape_pod():
    """Crew escape capsule with a cyan thruster (ally column 7)."""
    c = Canvas()
    c.dx, c.dy = 4, 8
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
        overlay(g, x + 4, y + 8, code)
    return g
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


def periodic_noise(seed, w, h, cell):
    """Value noise that wraps vertically with period h (h % cell == 0)."""
    rng = np.random.default_rng(seed)
    gh, gw = h // cell, w // cell + 2
    grid = rng.random((gh, gw)).astype(np.float32)
    ys, xs = np.mgrid[0:h, 0:w] / cell
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = xs - x0, ys - y0
    y1 = (y0 + 1) % gh
    y0 = y0 % gh
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = grid[y0, x0] * (1 - fx) + grid[y0, x0 + 1] * fx
    b = grid[y1, x0] * (1 - fx) + grid[y1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


GX, GROUND = (CW - 1) / 2, CH - 1   # cell centre column, ground row


def explosion_frames(seed, tex):
    """Ten frames: white flash -> fireball growing to a peak -> fire sinking
    under a rising, rolling smoke cap -> thinning smoke with settled
    debris.  The shock ring, flying debris and scorch are separate layers."""
    ys, xs = np.mgrid[0:CH, 0:CW].astype(np.float32)
    frames = []
    f0 = blank()
    burst(f0, GX, GROUND - 6, 4, warm=True)
    for x in range(int(GX) - 8, int(GX) + 9):
        if x % 2 == 0:
            overlay(f0, x, GROUND, W[4] if abs(x - GX) < 5 else W[3], True)
    frames.append(f0)
    cfg = [(5.5, 4.5, 1.7, 0.0, 0), (8.5, 6.5, 1.55, 0.0, 0), (11, 8, 1.4, .02, .5),
           (12.5, 8.5, 1.25, .06, 1), (13, 8.5, 1.1, .14, 2), (13.5, 8, .98, .24, 3),
           (14, 7.5, .86, .34, 4), (14, 7, .76, .45, 5), (13.5, 6.5, .66, .55, 6)]
    for f, (rx, ry, gain, bias, rise) in enumerate(cfg, start=1):
        cy = GROUND + 1 - ry * .8 - rise
        n = value_noise(seed + f, CW, CH, 3)
        n2 = value_noise(seed + 50 + f, CW, CH, 2)
        d = np.sqrt(((xs - GX) / rx) ** 2 + ((ys - cy) / ry) ** 2)
        heat = (1 - d) * gain + (n - .5) * .55 + (n2 - .5) * .2
        if f >= 5:                                     # mushroom: a stem of fire
            stem = np.clip(1 - np.abs(xs - GX) / (3 + f * .3), 0, 1) * (ys > cy) * (1.1 - f * .08)
            heat = np.maximum(heat, np.where(stem > 0, stem + (n - .5) * .4, -1))
        if tex is not None:
            heat += tex * .06
        heat[ys > GROUND] = 0
        heat *= np.clip((ys - 1) / 4, 0, 1)            # never touch the cell top
        shade = np.clip(n * .8 + (GX - xs) / 44 + (cy - ys) / 30, 0, 1)
        g = heat_codes(np.clip(heat, 0, 1), bias, shade)
        rng = np.random.default_rng(seed + 100 + f)
        if f >= 4:                                     # smoke cap above the fire
            g[is_warm(g) & (ys < cy - ry * .25)] = S[2]
        if f >= 7:
            g[(g >= S[0]) & (g <= S[4]) & (rng.random(g.shape) < (f - 6) * .14)] = 0
        if f >= 3:                                     # embers in the smoke
            hot = np.nonzero((g >= S[1]) & (g <= S[3]))
            for i in rng.choice(len(hot[0]), size=min(6, len(hot[0])), replace=False):
                g[hot[0][i], hot[1][i]] = W[3] if f < 7 else W[1]
        g = despeckle(g)
        if f >= 6:                                     # debris settled on the ground
            for _ in range(6):
                x = int(GX + rng.uniform(-1, 1) * rx * 1.2)
                if 0 <= x < CW - 1:
                    g[GROUND, x] = H[0]
                    g[GROUND, x + 1] = H[1]
        frames.append(pad_cell(g))
    return frames


def burst(g, cx, cy, r, warm=True, rays=True):
    """Radial flash (direction neutral): core, cross rays, diagonal sparks."""
    ramp = (W[3], W[4], W[5], W[6]) if warm else (C[1], C[2], C[3], C[4])
    cx, cy = int(cx), int(cy)
    for oy in range(-r - 3, r + 4):
        for ox in range(-r - 3, r + 4):
            d = np.hypot(ox, oy)
            axis = ox == 0 or oy == 0
            diag = abs(ox) == abs(oy)
            if d <= r * .45:
                code = ramp[3]
            elif d <= r * .8:
                code = ramp[2]
            elif d <= r and not diag:
                code = ramp[1]
            elif rays and axis and d <= r + 3:
                code = ramp[1] if d <= r + 1.5 else ramp[0]
            elif rays and diag and r * .9 <= d <= r + 1.5:
                code = ramp[0]
            else:
                continue
            overlay(g, cx + ox, cy + oy, code)


def shock_frames():
    """Ground shock ring seen in perspective: a flat ellipse that expands
    and cools from white-hot to a dust ring, broken up as it goes."""
    frames = []
    ys, xs = np.mgrid[0:CH, 0:CW].astype(np.float32)
    n = value_noise(4242, CW, CH, 2)
    ang = np.arctan2(ys - (GROUND - 3), xs - GX)
    for f, (rx, codes, holes) in enumerate(((7, (W[6], W[5], W[3]), 0), (11.5, (W[5], W[3], S[3]), .1),
                                            (16, (W[3], S[3], S[2]), .25), (19.5, (S[3], S[2], S[1]), .45))):
        ry = rx * .3
        e = np.sqrt(((xs - GX) / rx) ** 2 + ((ys - (GROUND - 2.5)) / ry) ** 2)
        g = np.zeros((CH, CW), dtype=np.int16)
        band = np.abs(e - 1) * rx
        brk = (np.sin(ang * 7 + f) * .5 + .5) * .6 + n * .4
        g[(band < .7)] = codes[0]
        g[(band >= .7) & (band < 1.5) & (e > 1)] = codes[1]
        g[(band >= .7) & (band < 1.6) & (e < 1)] = codes[2]
        g[brk < holes] = 0
        g[ys > GROUND] = 0
        frames.append(pad_cell(despeckle(g, 1)))
    return frames


def scorch_decal(rng, rx=15.0, ry=3.6, spokes=9):
    """Blast mark on the ground: a dark ellipse with radial streaks, a few
    cooling embers.  Flat (ground plane)."""
    g = np.zeros((CH, CW), dtype=np.int16)
    phase = rng.uniform(0, 6.28)
    cy = GROUND - ry
    for y in range(CH):
        for x in range(CW):
            dx, dy = (x - GX) / rx, (y - cy) / ry
            r = np.hypot(dx, dy)
            a = np.arctan2(dy, dx)
            spoke = max(0.0, np.cos(a * spokes + phase)) ** 6 * .45
            e = r - spoke + rng.random() * .12
            if e <= 1:
                g[y, x] = K[0] if e > .78 else (K[1] if e > .45 else (K[2] if e > .2 else K[3]))
    for _ in range(4):
        x, y = int(GX + rng.uniform(-.5, .5) * rx), int(cy + rng.uniform(-.4, .4) * ry)
        if 0 <= y < CH and g[y, x]:
            g[y, x] = W[0]
    return pad_cell(g)


def puff(seed, rx, ry, holes, light=0, cy=None, codes=None):
    rng = np.random.default_rng(seed)
    g = np.zeros((CH, CW), dtype=np.int16)
    cy = GROUND - ry + .5 if cy is None else cy
    n = value_noise(seed + 20, CW, CH, 2)
    codes = codes or (S[2], S[3], S[4])
    for y in range(CH):
        for x in range(CW):
            e = ((x - GX) / rx) ** 2 + ((y - cy) / ry) ** 2 + (n[y, x] - .5) * .5
            if e > 1 or rng.random() < holes:
                continue
            lit = -(x - GX) / rx - (y - cy) / ry + (n[y, x] - .5)
            code = codes[2] if lit > .8 else (codes[1] if lit > -.2 else codes[0])
            g[y, x] = max(S[0], code - light)
    return pad_cell(despeckle(g, 1))


def dust_frames(seed):
    """Dust kicked up by tracks and feet: a low cloud that swells, lifts
    and thins over four frames (ground anchored)."""
    out = []
    for f, (rx, ry, holes, lift) in enumerate(((4, 2.6, 0, 0), (6, 3.6, .08, .5), (8, 4.6, .24, 1.5), (9.5, 5.2, .45, 2.5))):
        out.append(puff(seed + f, rx, ry, holes, light=0, cy=GROUND - ry + .5 - lift,
                        codes=(S[3], S[4], S[4])))
    return out


def smoke_frames(seed):
    """Rising smoke puff life (centred): dense and dark, then larger,
    lighter and broken."""
    out = []
    for f, (r, holes, light) in enumerate(((3, 0, 1), (4.5, 0, 1), (6, .08, 0), (7.5, .2, 0), (9, .42, 0))):
        out.append(puff(seed + 10 + f, r, r * .85, holes, light=light, cy=CH / 2,
                        codes=(S[2], S[3], S[4])))
    return out


def spark_frames(seed):
    """Hull sparks: a hot star, then sparks flying up and out, then a few
    falling embers (centred)."""
    rng = np.random.default_rng(seed)
    out = []
    cx, cy = GX, CH / 2
    for f in range(3):
        g = blank()
        if f == 0:
            burst(g, cx, cy, 2, warm=True)
        for k in range(8):
            a = rng.uniform(-np.pi * .95, -np.pi * .05)
            v = rng.uniform(3, 7)
            t = (f + .6) * .5
            x = cx + np.cos(a) * v * t
            y = cy + np.sin(a) * v * t + 4 * t * t
            overlay(g, x, y, W[6] if f == 0 else (W[5] if f == 1 else W[3]))
            if f < 2:
                overlay(g, x - np.cos(a) * .9, y - np.sin(a) * .9, W[4], True)
        out.append(g)
    return out


def flame_frames(seed):
    """Burning-wreck flame tongue loop: noise scrolls up one period over
    six frames, so the loop is seamless (ground anchored)."""
    P = 24
    n = periodic_noise(seed, CW, P, 4)
    n2 = periodic_noise(seed + 1, CW, P, 3)
    ys, xs = np.mgrid[0:CH, 0:CW].astype(np.float32)
    out = []
    for f in range(6):
        sy = ((ys + f * 4) % P).astype(int)
        nn = n[sy, xs.astype(int)]
        nb = n2[sy, xs.astype(int)]
        t = np.clip((GROUND - ys) / 17.0, 0, 1)
        sway = (nn - .5) * 3 * t
        hw = 5.2 * (1 - t) ** .6 + .3
        across = np.abs(xs - GX - sway) / hw
        heat = (1 - across) * (1 - t) ** .45 * 1.35 + ((nb - .5) * .7 * t + (nn - .5) * .25) * (1 - t) ** .3
        heat[(ys > GROUND) | (ys < GROUND - 18)] = 0
        g = np.zeros((CH, CW), dtype=np.int16)
        for thr, code in ((.1, W[1]), (.2, W[2]), (.34, W[3]), (.5, W[4]), (.66, W[5]), (.82, W[6])):
            g[heat > thr] = code
        out.append(pad_cell(despeckle(g, 2)))
    return out


def debris_frames():
    """A tumbling hull chunk in four rotations (centred, tiny)."""
    out = []
    for f in range(4):
        g = blank()
        a = f * np.pi / 4
        d = np.array([np.cos(a), np.sin(a)])
        nrm = np.array([-d[1], d[0]])
        for t in np.linspace(-2.2, 2.2, 10):
            for o in (-.6, .6):
                p = np.array([GX, CH / 2]) + d * t + nrm * o
                overlay(g, p[0], p[1], H[3] if o < 0 else H[1])
        tip = np.array([GX, CH / 2]) + d * 2.4
        overlay(g, tip[0], tip[1], W[4])
        out.append(outline(g, rim=False))
    return out


def muzzle_frames(warm):
    """Muzzle flash: big star, small star with sparks, fading puff (centred)."""
    out = []
    cx, cy = GX, CH / 2
    g = blank(); burst(g, cx, cy, 3, warm=warm); out.append(g)
    g = blank(); burst(g, cx, cy, 2, warm=warm)
    for ox, oy in ((4, -2), (-4, -2), (2, -4), (-3, 3)):
        overlay(g, cx + ox, cy + oy, W[4] if warm else C[3])
    out.append(g)
    g = blank()
    for ox, oy, code in ((0, 0, W[4] if warm else C[3]), (1, 0, S[3]), (-1, 0, S[3]), (0, -1, S[4]),
                         (0, 1, S[2]), (1, -2, S[3]), (-1, -2, S[2]), (0, -3, S[2])):
        overlay(g, cx + ox, cy + oy, code)
    out.append(g)
    return out


def impact_frames(warm, seed):
    """Tracer impact on a hull: hot point and a spray of sparks bouncing
    up, then the spray falling with a puff of grit (centred)."""
    rng = np.random.default_rng(seed)
    hot = (W[3], W[4], W[5], W[6]) if warm else (C[1], C[2], C[3], C[4])
    cx, cy = GX, CH / 2
    sparks_ = [(rng.uniform(-np.pi * .95, -np.pi * .05), rng.uniform(4, 8)) for _ in range(7)]
    out = []
    for f in range(3):
        g = blank()
        if f == 0:
            burst(g, cx, cy, 2, warm=warm, rays=True)
        elif f == 1:
            overlay(g, cx, cy, hot[3]); overlay(g, cx + 1, cy, hot[2]); overlay(g, cx, cy - 1, hot[2])
            for ox, oy in ((-1, 0), (0, 1)):
                overlay(g, cx + ox, cy + oy, S[3])
        else:
            for ox, oy, code in ((0, 0, S[3]), (1, -1, S[3]), (-1, -1, S[2]), (0, -2, S[2]), (1, 0, S[2])):
                overlay(g, cx + ox, cy + oy, code)
        for a, v in sparks_:
            t = (f + 1) * .45
            x = cx + np.cos(a) * v * t
            y = cy + np.sin(a) * v * t + 6 * t * t
            overlay(g, x, y, hot[3] if f == 0 else (hot[2] if f == 1 else hot[0]))
        out.append(g)
    return out


def launch_flash():
    g = blank()
    cx, cy = GX, GROUND - 14
    burst(g, cx, cy, 4, warm=True)
    for y in range(int(cy) + 5, GROUND + 1):                # blast cone on the ground
        k = y - (cy + 3)
        for x in range(int(cx - k), int(cx + k) + 1):
            if g[y + PAD, x + PAD] == 0 and (x + y) % 2 == 0:
                g[y + PAD, x + PAD] = W[3] if y < GROUND - 1 else S[2]
    return g


def tracer_spark():
    g = blank()
    cx, cy = int(GX), GROUND - 4
    pts = [((0, 0), W[6]), ((1, 0), W[6]), ((-1, 0), W[5]), ((0, -1), W[5]), ((0, 1), W[5]),
           ((2, 0), W[4]), ((-2, 0), W[4]), ((0, -2), W[4]), ((1, -1), W[5]), ((-1, -1), W[4]),
           ((2, -2), W[3]), ((-2, -2), W[3]), ((3, 0), W[3]), ((-3, 0), W[3]), ((0, -3), W[3]),
           ((4, -3), W[4]), ((-4, -2), W[4]), ((1, -5), W[3])]
    for (ox, oy), code in pts:
        overlay(g, cx + ox, cy + oy, code)
    for x in range(cx - 2, cx + 3):
        overlay(g, x, GROUND, S[2] if abs(x - cx) < 2 else S[1])
    return g


def small_blast(seed):
    n = value_noise(seed, CW, CH, 2)
    ys, xs = np.mgrid[0:CH, 0:CW].astype(np.float32)
    d = np.sqrt(((xs - GX) / 6) ** 2 + ((ys - (GROUND - 4.5)) / 5) ** 2)
    heat = (1 - d) * 1.3 + (n - .5) * .45
    heat[ys > GROUND] = 0
    shade = np.clip(n * .8 + (GX - xs) / 30 + (GROUND - 5 - ys) / 20, 0, 1)
    return pad_cell(despeckle(heat_codes(np.clip(heat, 0, 1), 0, shade)))


def missile_frames(seed, tex):
    """Nose-on demon ground missile: dark iron warhead, four fins in an X,
    a ring of warm exhaust behind; two frames of exhaust flicker."""
    frames = []
    cx, cy = (CW - 1) / 2, (CH - 1) / 2
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


def unit_frames(uid: str, seed: int):
    """Demon unit row (authored on the v2 32x24 frame, bottom-centred in
    the larger v3 cell)."""
    tex = hull_texture(uid)

    def make(**st):
        c = Canvas(tex)
        info = BUILDERS[uid](c, st)
        return c.g, info

    frames = demon_frames(uid, seed, make)
    u = np.zeros_like(frames[0], dtype=bool)
    for f in frames[:4]:
        u |= (f != 0) & ~((f >= S[0]) & (f <= S[4]))
    x0, y0, x1, y1 = content_box(u)
    dx = (PAD + (CW - (x1 - x0)) // 2) - x0
    dy = (PAD + CH) - y1
    frames = [place(f, dx, dy, f"{uid} col {i}") for i, f in enumerate(frames)]
    return frames, (int(x1 - x0), int(y1 - y0))


ROW_EFFECT, ROW_FX, ROW_FLAME, ROW_MISSILE = 12, 13, 14, 15


def ally_row(sector_index, variant):
    return 4 + sector_index * 2 + variant


def build_atlas():
    s = spec()
    atlas = np.zeros((CH * ROWS, CW * COLS, 4), dtype=np.uint8)
    sizes = {"demon": [None] * 4, "ally": [None] * 8}
    meta = {"kind": [None] * 8, "bob": [None] * 8, "muzzle": [None] * 8}

    def put_cell(row, col, g, tab):
        if g is not None:
            atlas[row * CH:(row + 1) * CH, col * CW:(col + 1) * CW] = render(g, tab)

    for u in s["units"]:
        if u["side"] != "demon":
            continue
        frames, size = unit_frames(u["id"], u["seed"])
        tab = colour_table(s, "demon", u["sector"])
        for col, g in enumerate(frames):
            put_cell(u["row"], col, g, tab)
        sizes["demon"][SECTORS.index(u["sector"])] = size
    crew = [hexrgb(h) for h in s["reserved"]["ally_crew"]]
    for a in s["allies"]:
        si = SECTORS.index(a["sector"])
        row = ally_row(si, a["variant"])
        tab = colour_table(s, "ally", a["sector"])
        tab[CREW], tab[61] = crew[0], crew[1]
        tex = hull_texture(a["texture"]) if a.get("texture") else None
        if tex is not None:                            # sparse grit only
            tex = np.where(np.random.default_rng(a["seed"]).random(tex.shape) < .08, tex, 0).astype(np.int16)
        frames, muzzles, bob = ally_frames_v3(a["kind"], a["seed"], tex)
        for col, g in enumerate(frames):
            put_cell(row, col, g, tab)
        u = np.zeros((CH + 2 * PAD, CW + 2 * PAD), dtype=bool)
        for f in frames[:4]:
            u |= f != 0
        x0, y0, x1, y1 = content_box(u)
        sizes["ally"][row - 4] = (int(x1 - x0), int(y1 - y0))
        meta["kind"][row - 4] = ALLY_VARIANTS[a["kind"]][0]
        meta["bob"][row - 4] = tuple(bob)
        meta["muzzle"][row - 4] = [(round(x - CW / 2, 1), round(CH - y, 1)) for x, y in muzzles]
    fx = colour_table(s, "fx", None)
    ex = {e["id"]: e for e in s["extras"]}
    eseed, mseed = ex["explosion"]["seed"], ex["missile"]["seed"]
    # Effect row: explosion 0-9, scorch 10-12, launch 13, tracer 14, blast 15.
    for col, g in enumerate(explosion_frames(eseed, hull_texture("explosion"))):
        put_cell(ROW_EFFECT, col, g, fx)
    for k, (rx, ry, sp) in enumerate(((15, 3.6, 9), (12.5, 3.2, 7), (17, 4, 11))):
        put_cell(ROW_EFFECT, 10 + k, scorch_decal(np.random.default_rng(eseed + k), rx, ry, sp), fx)
    put_cell(ROW_EFFECT, 13, launch_flash(), fx)
    put_cell(ROW_EFFECT, 14, tracer_spark(), fx)
    put_cell(ROW_EFFECT, 15, small_blast(eseed + 7), fx)
    # Fx row: shock ring 0-3, dust 4-7, smoke puff 8-12, sparks 13-15.
    for col, g in enumerate(shock_frames()):
        put_cell(ROW_FX, col, g, fx)
    for col, g in enumerate(dust_frames(eseed + 60)):
        put_cell(ROW_FX, 4 + col, g, fx)
    for col, g in enumerate(smoke_frames(eseed + 70)):
        put_cell(ROW_FX, 8 + col, g, fx)
    for col, g in enumerate(spark_frames(eseed + 80)):
        put_cell(ROW_FX, 13 + col, g, fx)
    # Flame row: flames 0-5, debris 6-9, cyan muzzle 10-12, warm muzzle 13-15.
    for col, g in enumerate(flame_frames(eseed + 90)):
        put_cell(ROW_FLAME, col, g, fx)
    for col, g in enumerate(debris_frames()):
        put_cell(ROW_FLAME, 6 + col, g, fx)
    for col, g in enumerate(muzzle_frames(False)):
        put_cell(ROW_FLAME, 10 + col, g, fx)
    for col, g in enumerate(muzzle_frames(True)):
        put_cell(ROW_FLAME, 13 + col, g, fx)
    # Missile row: warhead 0-1, trail 2-4, cyan impact 5-7, warm impact 8-10.
    for col, g in enumerate(missile_frames(mseed, hull_texture("missile"))):
        put_cell(ROW_MISSILE, col, g, fx)
    for i, (rx, ry, holes) in enumerate(((6, 5, 0.0), (4.6, 4, .18), (3.2, 2.8, .42))):
        put_cell(ROW_MISSILE, 2 + i, puff(mseed + 50 + i, rx, ry, holes, light=1 if i == 2 else 0,
                                          cy=CH / 2 - .5), fx)
    for col, g in enumerate(impact_frames(False, eseed + 110)):
        put_cell(ROW_MISSILE, 5 + col, g, fx)
    for col, g in enumerate(impact_frames(True, eseed + 120)):
        put_cell(ROW_MISSILE, 8 + col, g, fx)
    atlas[atlas[..., 3] == 0] = 0
    return atlas, sizes, meta


DART = """// Generated by tools/ground_forces_assets.py (pack). Do not edit by hand:
// change art/families/ground-forces.json and rerun the pipeline.
//
// Cell layout of `assets/images/ground-forces.png` (stored 1x, one texel per
// pixel). Every cell is [cellW] x [cellH] texels. Demon units stand
// bottom-centred on the cell's last row, authored side-on facing screen
// right (toward the central lane from the left band); the renderer mirrors
// them for the right band. Allies are seen from behind and above, driving up
// the plane toward the horizon; a vehicle is two layers that share the cell
// frame (hull, then turret), so drawing both at the same anchor aligns them.

/// Grid contract of the ground-forces atlas (v3). Presentation only.
abstract final class GroundAtlas {
  static const String file = 'ground-forces.png';
  static const int cellW = CELLW, cellH = CELLH, columns = COLUMNS, rows = ROWS;

  /// Rows 0-3: demon ground units for sectors 0-3 (Krybor, Ringfall, Ember,
  /// Hollow). Rows 4-11: allied units, [allyVariants] per sector.
  static int demonRow(int sector) => sector.clamp(0, 3);
  static const int allyVariants = 2;
  static int allyRow(int sector, [int variant = 0]) =>
      4 + sector.clamp(0, 3) * allyVariants + variant % allyVariants;
  static const int effectRow = 12, fxRow = 13, flameRow = 14, missileRow = 15;

  // Demon unit columns.
  static const int moveCol = 0, moveFrames = 4; // 0-3 move cycle
  static const int telegraphCol = 4; // 4 launcher raised, 5 muzzle glow
  static const int fireCol = 6; // launch flash + recoil
  static const int postFireCol = 7; // smoking tube, settling
  static const int wreckCol = 8; // 8-9 burning hulk

  // Allied unit columns (allies never die: they are totalled and limp off).
  static const int allyMoveCol = 0, allyMoveFrames = 4; // 0-3 treads/gait
  static const int allyHitCol = 4; // hull flashes, sparks
  static const int allyLimpCol = 5; // 5-6 totalled: dented, track thrown
  static const int allyPodCol = 7; // crew escape pod
  /// Vehicles and walkers: turret (torso) layer, one column per screen
  /// angle in [allyTurretAngles] (degrees from straight up the plane toward
  /// screen right; mirror the cell for the left).
  static const int allyTurretCol = 8, allyTurretFrames = 5;
  static const List<double> allyTurretAngles = [ANGLES];
  /// Infantry squads: 8-9 kneeling volley (alternate shooters), 10 kneeling.
  static const int squadFireCol = 8, squadKneelCol = 10;

  /// Per ally row (row - 4): 0 vehicle (hull + turret), 1 infantry squad,
  /// 2 walker (hull + torso; the torso rises by [allyBob] texels per move
  /// frame).
  static const List<int> allyKind = [KIND];
  static const List<List<int>> allyBob = [BOB];

  /// Muzzle per ally row and turret angle: (dx from the cell centre, dy above
  /// the cell bottom), texels, unmirrored.
  static const List<List<(double, double)>> allyMuzzle = [
MUZZLE
  ];

  // Effect row columns.
  static const int explosionCol = 0, explosionFrames = 10; // 0-9
  static const int scorchCol = 10, scorchVariants = 3; // 10-12 ground decals
  static const int launchFlashCol = 13;
  static const int tracerCol = 14; // warm impact star
  static const int smallBlastCol = 15;

  // Fx row columns.
  static const int shockCol = 0, shockFrames = 4; // ground shock ring
  static const int dustCol = 4, dustFrames = 4; // kicked-up dust (ground)
  static const int puffCol = 8, puffFrames = 5; // rising smoke (centred)
  static const int sparkCol = 13, sparkFrames = 3; // hull sparks (centred)

  // Flame row columns.
  static const int flameCol = 0, flameFrames = 6; // flame tongue loop
  static const int debrisCol = 6, debrisFrames = 4; // tumbling chunk
  static const int muzzleCyanCol = 10, muzzleWarmCol = 13, muzzleFrames = 3;

  // Missile row columns.
  static const int missileCol = 0; // 0-1 nose toward camera, exhaust flicker
  static const int smokeCol = 2; // 2-4 trail puffs (dense -> thin)
  static const int impactCyanCol = 5, impactWarmCol = 8, impactFrames = 3;

  /// Visible content box (texels, bottom-centred) per demon sector and per
  /// ally row (hull move frames).
  static const List<(int, int)> demonSize = [DEMON];
  static const List<(int, int)> allySize = [ALLY];
}
"""


def write_dart(sizes, meta):
    fmt = lambda xs: ", ".join(f"({w}, {h})" for w, h in xs)
    mz = "\n".join("    [" + ", ".join(f"({x}, {y})" for x, y in row) + "],"
                   for row in meta["muzzle"])
    out = (DART.replace("CELLW", str(CW)).replace("CELLH", str(CH)).replace("COLUMNS", str(COLS))
           .replace("ROWS", str(ROWS)).replace("ANGLES", ", ".join(str(a) for a in ALLY_ANGLES))
           .replace("KIND", ", ".join(str(k) for k in meta["kind"]))
           .replace("BOB", ", ".join("[" + ", ".join(str(b) for b in bb) + "]" for bb in meta["bob"]))
           .replace("MUZZLE", mz)
           .replace("DEMON", fmt(sizes["demon"])).replace("ALLY", fmt(sizes["ally"])))
    DART_OUT.write_text(out)


def save_png(arr, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(path, optimize=True)


ROW_NAMES = ["0 demon krybor", "1 demon ringfall", "2 demon ember", "3 demon hollow",
             "4 krybor rover", "5 krybor apc", "6 ringfall halftrack", "7 ringfall militia",
             "8 ember tank", "9 ember howitzer", "10 hollow walker", "11 hollow heavy sq",
             "12 effects", "13 fx", "14 flame/muzzle", "15 missile/impact"]
COL_NAMES = {
    "demon": ["move0", "move1", "move2", "move3", "teleA", "teleB", "fire", "post", "wreck", "wreck'"],
    "ally": ["move0", "move1", "move2", "move3", "hit", "limp", "limp'", "pod", "tur0", "tur22", "tur45",
             "tur67", "tur90"],
    "squad": ["walk0", "walk1", "walk2", "walk3", "hit", "run", "run'", "pod", "fireA", "fireB", "kneel"],
    12: [f"exp{i}" for i in range(10)] + ["scorch", "scorch'", "scorch\"", "launch", "tracer", "blast"],
    13: ["shock0", "shock1", "shock2", "shock3", "dust0", "dust1", "dust2", "dust3",
         "puff0", "puff1", "puff2", "puff3", "puff4", "spark0", "spark1", "spark2"],
    14: [f"flame{i}" for i in range(6)] + [f"debris{i}" for i in range(4)] +
        ["muzC0", "muzC1", "muzC2", "muzW0", "muzW1", "muzW2"],
    15: ["missile", "missile'", "trail0", "trail1", "trail2", "impC0", "impC1", "impC2",
         "impW0", "impW1", "impW2"],
}


def cell_img(atlas, r, col):
    return Image.fromarray(np.ascontiguousarray(atlas[r * CH:(r + 1) * CH, col * CW:(col + 1) * CW]), "RGBA")


def contact(atlas, meta):
    """Labelled 3x atlas with a cell grid; then each allied row composed
    (hull + turret layers) on its sector ground tile at 2x arena scale (the
    near band) and 1x, shown at 2x so phone-size readability can be judged."""
    Z = 3
    lab = 120
    aw, ah = COLS * CW * Z, ROWS * CH * Z
    pw, ph = 12 * 52 + 8, 2 * CH + 4 + CH + 6         # panel, arena units
    pz = 2
    comp_h = 8 * (ph * pz + 6)
    sheet = Image.new("RGB", (lab + max(aw, pw * pz), 22 + ah + 26 + comp_h), (12, 14, 20))
    d = ImageDraw.Draw(sheet)
    d.text((4, 4), f"ground-forces.png v3: {COLS}x{ROWS} cells of {CW}x{CH} texels, shown {Z}x (checker = transparent)",
           fill=(200, 210, 220))
    yy, xx = np.mgrid[0:ah, 0:aw]
    cb = np.full((ah, aw, 4), 255, dtype=np.uint8)
    cb[..., :3] = (34, 38, 48)
    cb[((yy // 6 + xx // 6) % 2) == 0, :3] = (27, 30, 39)
    bg = Image.fromarray(cb, "RGBA")
    bg.alpha_composite(Image.fromarray(atlas, "RGBA").resize((aw, ah), Image.Resampling.NEAREST))
    sheet.paste(bg.convert("RGB"), (lab, 22))
    for r in range(ROWS + 1):
        d.line([(lab, 22 + r * CH * Z), (lab + aw, 22 + r * CH * Z)], fill=(70, 76, 90))
    for c_ in range(COLS + 1):
        d.line([(lab + c_ * CW * Z, 22), (lab + c_ * CW * Z, 22 + ah)], fill=(70, 76, 90))
    for r in range(ROWS):
        if r < 4:
            names = COL_NAMES["demon"]
        elif r < 12:
            names = COL_NAMES["squad" if meta["kind"][r - 4] == 1 else "ally"]
        else:
            names = COL_NAMES[r]
        d.text((4, 22 + r * CH * Z + 40), ROW_NAMES[r], fill=(200, 210, 220))
        for c_, n in enumerate(names):
            d.text((lab + c_ * CW * Z + 3, 22 + r * CH * Z + 2), n, fill=(120, 130, 150))
    y0 = 22 + ah + 6
    d.text((4, y0), "allies composed (hull + turret) on the sector ground: top 2x (near band), bottom 1x; view 2x",
           fill=(200, 210, 220))
    y0 += 20
    for k in range(8):
        r = 4 + k
        sector = SECTORS[k // 2]
        ground = Image.open(ROOT / f"assets/images/flyover-{sector}-ground.png").convert("RGB")
        tile = ground.crop((0, 0, (pw + 1) // 2, (ph + 1) // 2)).resize((pw, ph), Image.Resampling.NEAREST)
        panel = tile.convert("RGBA")
        kind = meta["kind"][k]

        def comp(hull_col, tur, scale, mirror=False, bob=0):
            im = Image.new("RGBA", (CW, CH + 2))
            im.alpha_composite(cell_img(atlas, r, hull_col), (0, 2))
            if kind != 1 and tur is not None:
                t = cell_img(atlas, r, 8 + tur)
                im.alpha_composite(t.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if mirror else t, (0, 2 - bob))
            w, h = round(CW * scale), round((CH + 2) * scale)
            return im.resize((w, h), Image.Resampling.NEAREST)

        bobs = meta["bob"][k]
        if kind == 1:
            seq = [(c_, None, False, 0) for c_ in (0, 1, 2, 3, 4, 5, 6, 8, 9, 10)]
        else:
            seq = [(c_, 0, False, bobs[c_]) for c_ in range(4)] + [(0, t, False, 0) for t in (1, 2, 3, 4)] + \
                  [(0, 2, True, 0), (4, 0, False, 0), (5, 1, False, 0), (6, 1, False, 0)]
        for i, (hc, tur, mir, bob) in enumerate(seq[:12]):
            panel.alpha_composite(comp(hc, tur, 2 * 0.65, mir, bob), (4 + i * 52, 0))
            panel.alpha_composite(comp(hc, tur, 1 * 0.65, mir, bob), (4 + i * 52 + 12, 2 * CH))
        sheet.paste(panel.convert("RGB").resize((pw * pz, ph * pz), Image.Resampling.NEAREST),
                    (lab, y0 + k * (ph * pz + 6)))
        d.text((4, y0 + k * (ph * pz + 6) + 60), ROW_NAMES[r], fill=(200, 210, 220))
    CONTACT_OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(CONTACT_OUT, optimize=True)


def cmd_offline(_args) -> None:
    atlas, sizes, meta = build_atlas()
    assert atlas.shape == (ROWS * CH, COLS * CW, 4)
    assert set(np.unique(atlas[..., 3]).tolist()) <= {0, 255}
    save_png(atlas, ATLAS_OUT)
    write_dart(sizes, meta)
    contact(atlas, meta)
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

