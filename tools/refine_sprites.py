"""Image helpers for the big-model refinement pass (Qwen-Image-Edit-2511 + BiRefNet).

GPU work goes through studio.run_workflow; this only does the pixel plumbing around it.
Run: uv run -q --no-project --with pillow python -I tools/refine_sprites.py <cmd> ...

  stage  SRC DST                 copy a source of record to the studio input folder (RGBA PNG)
  master RENDER MATTE OUT        RGBA master: render RGB + BiRefNet matte as alpha
  opaque RENDER OUT              RGBA master without a matte (full scenes, textures)
  game   MASTER WxH OUT [--rgb]  area downscale to the shipped size (alpha kept; --rgb flattens on light grey)
  fit    MASTER WxH OUT          area downscale, cropped to the master's alpha bbox, fitted inside WxH
  strip  OUT IMG...              side-by-side strip (nearest upscale to a common height) for review
  sheet  OUT LABEL BEFORE AFTER [LABEL BEFORE AFTER ...]
                                 before/after contact sheet on a checker, nearest upscale
"""
import sys
from PIL import Image, ImageDraw


def size(s):
    w, h = s.lower().split("x")
    return int(w), int(h)


def load_rgba(p):
    return Image.open(p).convert("RGBA")


def premul_box(img, wh):
    # Area downscale with premultiplied alpha so the grey background does not bleed into edges.
    r, g, b, a = img.split()
    from PIL import ImageChops
    pr = ImageChops.multiply(r, a)
    pg = ImageChops.multiply(g, a)
    pb = ImageChops.multiply(b, a)
    sm = [c.resize(wh, Image.BOX) for c in (pr, pg, pb, a)]
    a2 = sm[3]
    out = Image.new("RGBA", wh)
    px = out.load()
    rr, gg, bb, aa = (c.load() for c in sm)
    for y in range(wh[1]):
        for x in range(wh[0]):
            al = aa[x, y]
            if al == 0:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (min(255, rr[x, y] * 255 // al), min(255, gg[x, y] * 255 // al),
                            min(255, bb[x, y] * 255 // al), al)
    return out


def checker(w, h, s=8):
    im = Image.new("RGB", (w, h), (40, 40, 48))
    d = ImageDraw.Draw(im)
    for y in range(0, h, s):
        for x in range(0, w, s):
            if (x // s + y // s) % 2:
                d.rectangle([x, y, x + s - 1, y + s - 1], fill=(56, 56, 66))
    return im


def up(img, h):
    k = max(1, h // img.height) if img.height <= h else h / img.height
    w2, h2 = max(1, int(img.width * k)), max(1, int(img.height * k))
    return img.resize((w2, h2), Image.NEAREST if k >= 1 else Image.LANCZOS)


def main(a):
    cmd = a[0]
    if cmd == "stage":
        load_rgba(a[1]).save(a[2])
    elif cmd == "master":
        im = Image.open(a[1]).convert("RGB")
        m = Image.open(a[2]).convert("L").resize(im.size, Image.BILINEAR)
        im = im.convert("RGBA")
        im.putalpha(m)
        im.save(a[3])
    elif cmd == "opaque":
        Image.open(a[1]).convert("RGBA").save(a[2])
    elif cmd == "game":
        out = premul_box(load_rgba(a[1]), size(a[2]))
        if "--rgb" in a:
            # Flat light grey under the matte: the colour-key finish stages key on the border.
            bg = Image.new("RGBA", out.size, (224, 224, 224, 255))
            out = Image.alpha_composite(bg, out).convert("RGB")
        out.save(a[3])
    elif cmd == "fit":
        im = load_rgba(a[1])
        bb = im.getchannel("A").point(lambda v: 255 if v >= 140 else 0).getbbox() or (0, 0, im.width, im.height)
        im = im.crop(bb)
        W, H = size(a[2])
        k = min(W / im.width, H / im.height)
        out = premul_box(im, (max(1, round(im.width * k)), max(1, round(im.height * k))))
        out.save(a[3])
    elif cmd == "strip":
        ims = [load_rgba(p) for p in a[2:]]
        H = 256
        ups = [up(i, H) for i in ims]
        W = sum(i.width for i in ups) + 8 * (len(ups) + 1)
        bg = checker(W, H + 16)
        x = 8
        for i in ups:
            bg.paste(i, (x, 8), i)
            x += i.width + 8
        bg.save(a[1])
    elif cmd == "sheet":
        rows = [(a[i], load_rgba(a[i + 1]), load_rgba(a[i + 2])) for i in range(2, len(a), 3)]
        H = 160
        def pair(b, f):
            # One scale for both sides so sizes compare honestly.
            mh = max(b.height, f.height)
            k = max(1, H // mh) if mh <= H else H / mh
            rs = lambda i: i.resize((max(1, int(i.width * k)), max(1, int(i.height * k))),
                                    Image.NEAREST if k >= 1 else Image.LANCZOS)
            return rs(b), rs(f)
        cells = [(l, *pair(b, f)) for l, b, f in rows]
        cw = max(max(b.width, f.width) for _, b, f in cells)
        W = 200 + 2 * (cw + 16) + 16
        sheet = checker(W, len(cells) * (H + 16) + 40)
        d = ImageDraw.Draw(sheet)
        d.text((8, 8), "label", fill=(230, 230, 230))
        d.text((216, 8), "before (shipped source)", fill=(230, 230, 230))
        d.text((216 + cw + 16, 8), "after (refined)", fill=(230, 230, 230))
        y = 32
        for l, b, f in cells:
            d.text((8, y + H // 2), l, fill=(230, 230, 230))
            sheet.paste(b, (216, y), b)
            sheet.paste(f, (216 + cw + 16, y), f)
            y += H + 16
        sheet.save(a[1])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
