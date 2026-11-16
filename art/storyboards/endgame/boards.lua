#!/usr/bin/env lua
-- Thumbnail storyboards for the end-game cinematic (change `endgame-cinematic`).
-- Writes one SVG per shot plus a contact sheet into the directory given as arg[1] (default: this script's directory).
-- No GPU, no model: flat vector sketches only. They fix staging, camera and the colour script, not the final look.
--
--   lua art/storyboards/endgame/boards.lua art/storyboards/endgame
--   for f in art/storyboards/endgame/*.svg; do magick -font <a .ttf> "$f" "${f%.svg}.png"; done
--
-- ImageMagick's built-in SVG renderer is the only rasteriser in the forge. It ignores gradients and mishandles
-- `transform`, so every shape here is flat-filled and placed with absolute coordinates.

local out_dir = arg[1] or (arg[0]:match("^(.*)/[^/]*$") or ".")

-- Colour script (docs/styleguide/endgame-cinematic.md §5).
local K = {
  ink = "#1b1430", paper = "#fff6e6", note = "#5b4a6b",
  navy = "#0b1026", teal = "#2de2c8", coral = "#ff5a4d", violet = "#9b5cff", gold = "#ffc94a",
  amber = "#f6b25a", cream = "#ffe9c4", plum = "#4a2b52", sea = "#2e8f9b", sand = "#e8c48a",
  wood = "#a8683c", wood2 = "#8a5230", dusk = "#c2507a", sky = "#f9cf8f", red = "#d8433b", white = "#ffffff",
  skinA = "#6b4226", skinB = "#c98f62", skinC = "#f0c8a0", skinD = "#8d5a3a", grey = "#c9ccd6",
}

local W, FH, HEAD, FOOT = 960, 540, 56, 104
local H = HEAD + FH + FOOT
local buf

local function add(s) buf[#buf + 1] = s end
local function esc(s) return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
local function y_(y) return y + HEAD end

local function R(x, y, w, h, fill, op, stroke)
  add(string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%s" stroke="%s" stroke-width="2"/>',
    x, y_(y), w, h, fill, op or 1, stroke or "none"))
end
local function C(cx, cy, r, fill, op, stroke)
  add(string.format('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" fill-opacity="%s" stroke="%s" stroke-width="2"/>',
    cx, y_(cy), r, fill, op or 1, stroke or "none"))
end
local function E(cx, cy, rx, ry, fill, op, stroke)
  add(string.format('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" fill-opacity="%s" stroke="%s" stroke-width="2"/>',
    cx, y_(cy), rx, ry, fill, op or 1, stroke or "none"))
end
local function P(pts, fill, op, stroke)
  local t = {}
  for i = 1, #pts, 2 do t[#t + 1] = string.format("%.1f,%.1f", pts[i], y_(pts[i + 1])) end
  add(string.format('<polygon points="%s" fill="%s" fill-opacity="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>',
    table.concat(t, " "), fill, op or 1, stroke or "none"))
end
local function L(x1, y1, x2, y2, stroke, w, dash)
  add(string.format('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%s" stroke-linecap="round"%s/>',
    x1, y_(y1), x2, y_(y2), stroke, w or 2, dash and (' stroke-dasharray="' .. dash .. '"') or ""))
end
local function T(x, y, s, size, fill, anchor, weight)
  add(string.format('<text x="%.1f" y="%.1f" font-family="Noto Sans" font-size="%d" font-weight="%s" text-anchor="%s" fill="%s">%s</text>',
    x, y, size or 16, weight or "normal", anchor or "start", fill or K.ink, esc(s)))
end
local function TF(x, y, s, size, fill, anchor, weight) T(x, y_(y), s, size, fill, anchor, weight) end

-- A camera or motion arrow, with a computed head (no transforms).
local function arrow(x1, y1, x2, y2, col, label)
  col = col or K.white
  L(x1, y1, x2, y2, K.ink, 7)
  L(x1, y1, x2, y2, col, 4)
  local a = math.atan(y2 - y1, x2 - x1)
  local s, sp = 16, 0.45
  P({ x2 + 6 * math.cos(a), y2 + 6 * math.sin(a), x2 - s * math.cos(a - sp), y2 - s * math.sin(a - sp),
      x2 - s * math.cos(a + sp), y2 - s * math.sin(a + sp) }, col, 1, K.ink)
  if label then
    TF((x1 + x2) / 2 + 17, (y1 + y2) / 2 - 11, label, 14, K.ink, "start", "bold")
    TF((x1 + x2) / 2 + 16, (y1 + y2) / 2 - 12, label, 14, col, "start", "bold")
  end
end

-- A bean person: o = {skin, hair, top, horns, apron, smile, back, arm = {dx, dy}, tall}
local function person(x, y, s, o)
  local bw, bh = 46 * s, (o.tall or 70) * s
  P({ x - bw * 0.72, y, x - bw * 0.55, y - bh, x + bw * 0.55, y - bh, x + bw * 0.72, y }, o.top, 1, K.ink)
  if o.apron then P({ x - bw * 0.4, y, x - bw * 0.34, y - bh * 0.72, x + bw * 0.34, y - bh * 0.72, x + bw * 0.4, y }, K.cream, 1, K.ink) end
  local hy, hr = y - bh - 20 * s, 24 * s
  if o.horns then
    P({ x - hr * 0.9, hy - hr * 0.5, x - hr * 1.25, hy - hr * 1.7, x - hr * 0.3, hy - hr * 0.95 }, o.top, 1, K.ink)
    P({ x + hr * 0.9, hy - hr * 0.5, x + hr * 1.25, hy - hr * 1.7, x + hr * 0.3, hy - hr * 0.95 }, o.top, 1, K.ink)
    C(x, hy, hr * 1.18, o.top, 1, K.ink)
  end
  C(x, hy, hr, o.skin, 1, K.ink)
  if o.back then
    C(x, hy, hr, o.hair, 1, K.ink)
  else
    P({ x - hr, hy - hr * 0.15, x - hr * 0.8, hy - hr * 0.95, x, hy - hr * 1.2, x + hr * 0.8, hy - hr * 0.95, x + hr, hy - hr * 0.15,
        x + hr * 0.5, hy - hr * 0.55, x - hr * 0.5, hy - hr * 0.55 }, o.hair, 1, K.ink)
    C(x - hr * 0.36, hy + hr * 0.05, 2.6 * s, K.ink)
    C(x + hr * 0.36, hy + hr * 0.05, 2.6 * s, K.ink)
    if o.smile then
      P({ x - hr * 0.5, hy + hr * 0.34, x + hr * 0.5, hy + hr * 0.34, x + hr * 0.28, hy + hr * 0.68, x - hr * 0.28, hy + hr * 0.68 }, K.white, 1, K.ink)
    else
      L(x - hr * 0.3, hy + hr * 0.5, x + hr * 0.3, hy + hr * 0.5, K.ink, 2)
    end
  end
  if o.arm then
    local ax, ay = x + (o.arm[1] < 0 and -bw * 0.5 or bw * 0.5), y - bh * 0.8
    L(ax, ay, ax + o.arm[1] * s, ay + o.arm[2] * s, K.ink, 15 * s)
    L(ax, ay, ax + o.arm[1] * s, ay + o.arm[2] * s, o.top, 11 * s)
    C(ax + o.arm[1] * s, ay + o.arm[2] * s, 7 * s, o.skin, 1, K.ink)
  end
end

-- Plastic figures: one flat colour, a round base, a seam highlight.
local function base(x, y, s, col) E(x, y, 15 * s, 5 * s, col, 1, K.ink) end
local function gargoyle(x, y, s, col)
  base(x, y, s, col)
  P({ x - 6 * s, y - 16 * s, x - 22 * s, y - 34 * s, x - 6 * s, y - 28 * s }, col, 1, K.ink)
  P({ x + 6 * s, y - 16 * s, x + 22 * s, y - 34 * s, x + 6 * s, y - 28 * s }, col, 1, K.ink)
  P({ x - 9 * s, y - 2 * s, x - 7 * s, y - 26 * s, x + 7 * s, y - 26 * s, x + 9 * s, y - 2 * s }, col, 1, K.ink)
  P({ x - 7 * s, y - 36 * s, x - 9 * s, y - 46 * s, x - 2 * s, y - 39 * s }, col, 1, K.ink)
  P({ x + 7 * s, y - 36 * s, x + 9 * s, y - 46 * s, x + 2 * s, y - 39 * s }, col, 1, K.ink)
  C(x, y - 32 * s, 8 * s, col, 1, K.ink)
  L(x - 4 * s, y - 20 * s, x - 4 * s, y - 6 * s, K.white, 2)
end
local function tank(x, y, s, col)
  base(x, y, s * 1.3, col)
  R(x - 16 * s, y - 14 * s, 32 * s, 12 * s, col, 1, K.ink)
  R(x - 8 * s, y - 23 * s, 16 * s, 10 * s, col, 1, K.ink)
  L(x + 8 * s, y - 19 * s, x + 26 * s, y - 23 * s, K.ink, 5 * s)
end
local function ship(x, y, s, col)
  base(x, y, s, col)
  L(x, y - 2 * s, x, y - 18 * s, K.ink, 3)
  P({ x - 16 * s, y - 16 * s, x, y - 44 * s, x + 16 * s, y - 16 * s, x, y - 22 * s }, col, 1, K.ink)
end
local function die(x, y, s, n)
  R(x, y, 22 * s, 22 * s, K.white, 1, K.ink)
  local pips = ({ { { 11, 11 } }, { { 6, 6 }, { 16, 16 } }, [6] = { { 6, 5 }, { 16, 5 }, { 6, 11 }, { 16, 11 }, { 6, 17 }, { 16, 17 } } })[n]
  for _, p in ipairs(pips) do C(x + p[1] * s, y + p[2] * s, 2.2 * s, K.ink) end
end
local function glass(x, y, s, level)
  P({ x - 14 * s, y - 60 * s, x + 14 * s, y - 60 * s, x + 10 * s, y, x - 10 * s, y }, K.white, 0.55, K.ink)
  local t = y - 60 * s * level
  P({ x - (10 + 4 * level) * s, t, x + (10 + 4 * level) * s, t, x + 10 * s, y, x - 10 * s, y }, K.wood2, 0.9, K.ink)
  L(x + 4 * s, y - 4 * s, x + 16 * s, y - 78 * s, K.red, 4 * s)
end
local function umbrella(x, y, s, col)
  L(x, y, x, y - 150 * s, K.ink, 5)
  P({ x - 110 * s, y - 140 * s, x, y - 200 * s, x + 110 * s, y - 140 * s }, col, 1, K.ink)
  P({ x - 36 * s, y - 140 * s, x, y - 200 * s, x + 36 * s, y - 140 * s }, K.cream, 1, K.ink)
end
local function palm(x, y, s)
  P({ x - 7 * s, y, x - 3 * s, y - 190 * s, x + 5 * s, y - 190 * s, x + 9 * s, y }, K.wood2, 1, K.ink)
  for _, d in ipairs({ { -80, 10 }, { -60, -40 }, { 0, -62 }, { 60, -40 }, { 80, 10 } }) do
    P({ x, y - 190 * s, x + d[1] * s, y - 190 * s + d[2] * s, x + d[1] * 0.55 * s, y - 190 * s + (d[2] + 26) * s }, "#2f7d4f", 1, K.ink)
  end
end
local function sunset(horizon, sunx)
  R(0, 0, W, horizon * 0.45, K.dusk)
  R(0, horizon * 0.45, W, horizon * 0.3, "#e8805f")
  R(0, horizon * 0.75, W, horizon * 0.25, K.sky)
  C(sunx, horizon, 62, K.cream)
  R(0, horizon, W, 46, K.sea)
  L(sunx - 70, horizon + 14, sunx + 70, horizon + 14, K.cream, 3)
  L(sunx - 40, horizon + 30, sunx + 40, horizon + 30, K.cream, 3)
  R(0, horizon + 46, W, FH - horizon - 46, K.sand)
end
-- Portrait-safe column: the 9:16 phone crop of this frame; the subject of every shot sits inside it.
local function safe()
  local w = FH * 9 / 16
  L((W - w) / 2, 4, (W - w) / 2, FH - 4, K.white, 2, "4 8")
  L((W + w) / 2, 4, (W + w) / 2, FH - 4, K.white, 2, "4 8")
end
local function sfx(x, y, s) TF(x + 1, y + 1, s, 15, K.ink, "start", "bold"); TF(x, y, s, 15, K.gold, "start", "bold") end

local shots = {}
local function shot(t) shots[#shots + 1] = t end

shot { id = "S1", file = "s1-last-piece", title = "The last piece falls", time = "0.0 – 3.5 s", cam = "Locked macro, board level, shallow focus. MATCH CUT on the fall at 2.0 s.",
  lines = { "ADMIRAL (radio, filter fading out): Overwatch to squadron. Carrier is down. All wings… come home.",
            "SFX: wreck rumble thins into one plastic clack on cardboard. Metal track ducks to a tinny phone speaker." },
  draw = function()
    R(0, 0, W, FH, K.navy)
    for i = 1, 26 do C((i * 137) % 460 + 8, (i * 89) % 520 + 8, (i % 3) + 1, K.white, 0.7) end
    -- game space: the pixel carrier wreck, falling nose-down along the cut line
    local cx, cy = 250, 250
    for i = 0, 6 do R(cx - 120 + i * 30, cy - 80 + i * 22, 62, 28, i % 2 == 0 and K.violet or "#6b3fc4", 1, K.ink) end
    R(cx - 30, cy - 30, 40, 22, K.coral, 1, K.ink); R(cx + 40, cy + 30, 30, 18, K.gold, 1, K.ink)
    for i = 1, 5 do R(cx - 150 + i * 14, cy - 150 + i * 6, 10, 10, K.coral, 0.8) end
    TF(24, 34, "GAME SPACE", 18, K.teal, "start", "bold")
    TF(24, 520, "pixel carrier wreck, last frame of the victory fall", 14, K.grey)
    -- table space
    P({ 480, 0, W, 0, W, FH, 420, FH }, K.amber)
    P({ 468, 330, W, 300, W, FH, 420, FH }, "#2a7a70", 1, K.ink)
    P({ 462, 368, W, 344, W, 372, 458, 398 }, K.coral, 0.85, K.ink)
    TF(840, 468, "KRYBOR", 22, K.cream, "middle", "bold")
    -- plastic carrier toy, same angle and screen position as the wreck
    P({ 560, 150, 640, 130, 800, 262, 820, 318, 760, 330, 600, 220 }, K.violet, 1, K.ink)
    P({ 640, 190, 700, 176, 760, 232, 716, 252 }, "#6b3fc4", 1, K.ink)
    L(590, 168, 770, 300, K.white, 3)
    E(770, 336, 70, 12, K.plum, 0.45)
    -- the flick
    L(960, 120, 850, 196, K.ink, 40); L(960, 120, 850, 196, K.skinB, 34); C(846, 199, 17, K.skinB, 1, K.ink)
    sfx(840, 290, "clack!")
    TF(936, 34, "TABLE SPACE", 18, K.ink, "end", "bold")
    L(480, 0, 420, FH, K.white, 6); L(480, 0, 420, FH, K.ink, 2, "10 8")
    TF(404, 470, "MATCH CUT", 16, K.white, "end", "bold")
    arrow(330, 120, 392, 196, K.gold, "fall")
    arrow(640, 60, 700, 132, K.gold, "tip")
  end }

shot { id = "S2", file = "s2-the-board", title = "The board", time = "3.5 – 8.5 s", cam = "One move: crane up and back from board level to a high three-quarter. Focus deepens as we rise.",
  lines = { "KID, BROOD SIDE (a real voice at last): No way. You rolled a six again?",
            "KID, FLEET SIDE: Carrier's down! That's the game!",
            "SFX: gulls, surf, cutlery. The radio hiss is now a soda fizzing." },
  draw = function()
    R(0, 0, W, FH, K.wood)
    for i = 0, 5 do L(0, 40 + i * 100, W, 20 + i * 100, K.wood2, 3) end
    P({ 150, 110, 810, 90, 880, 450, 90, 470 }, "#20605a", 1, K.ink)
    -- the five destinations as a track of regions, outside in
    local reg = { { K.teal, "KRYBOR", 190, 150 }, { K.grey, "RINGFALL", 330, 140 }, { K.coral, "EMBER MOON", 480, 136 },
                  { K.gold, "THE HOLLOW", 630, 132 }, { K.violet, "THE CARRIER", 420, 300 } }
    for i = 1, 4 do
      local r = reg[i]
      P({ r[3] - 50, r[4] - 20, r[3] + 80, r[4] - 24, r[3] + 88, r[4] + 70, r[3] - 56, r[4] + 74 }, r[1], 0.9, K.ink)
      TF(r[3] + 14, r[4] + 6, r[2], 13, K.ink, "middle", "bold")
    end
    E(480, 330, 150, 70, K.violet, 0.9, K.ink); TF(480, 300, "THE CARRIER", 14, K.ink, "middle", "bold")
    for i = 0, 9 do R(170 + i * 62, 396 - i * 1.5, 50, 36, i % 2 == 0 and K.cream or K.amber, 1, K.ink) end
    TF(200, 420, "START", 12, K.ink, "middle", "bold")
    P({ 400, 318, 470, 306, 560, 350, 520, 372 }, "#6b3fc4", 1, K.ink) -- the tipped carrier toy
    gargoyle(250, 210, 1.1, K.teal); gargoyle(300, 222, 1.0, K.teal); gargoyle(520, 214, 1.1, K.coral)
    gargoyle(660, 208, 1.1, K.gold); gargoyle(610, 330, 1.2, K.violet)
    ship(400, 390, 1.1, K.white); ship(350, 372, 0.9, K.white); tank(240, 386, 1.0, "#6f8f4a"); tank(300, 400, 1.0, "#6f8f4a")
    die(690, 380, 1.3, 6); die(730, 404, 1.3, 6)
    for i = 0, 2 do P({ 730 + i * 8, 150 + i * 6, 800 + i * 8, 144 + i * 6, 806 + i * 8, 236 + i * 6, 736 + i * 8, 242 + i * 6 }, K.cream, 1, K.ink) end
    TF(782, 196, "URGENT", 12, K.red, "middle", "bold"); TF(782, 212, "MISSION", 12, K.red, "middle", "bold")
    -- off-board: sugar packets (power-ups), fries, soda ring, heart tokens
    R(40, 96, 46, 26, K.teal, 1, K.ink); R(52, 130, 46, 26, K.gold, 1, K.ink); R(30, 164, 46, 26, K.coral, 1, K.ink)
    TF(64, 210, "sugar packets", 12, K.cream, "middle")
    C(880, 120, 34, K.wood2, 0.5, K.ink); glass(880, 120, 0.9, 0.25)
    P({ 850, 470, 930, 470, 916, 530, 864, 530 }, K.red, 1, K.ink)
    for i = 0, 4 do L(862 + i * 14, 474, 856 + i * 16, 432, K.gold, 7) end
    for i = 0, 2 do C(60 + i * 30, 500, 11, K.coral, 1, K.ink) end
    TF(90, 530, "heart tokens", 12, K.cream, "middle")
    safe()
    arrow(480, 500, 480, 420, K.white, "crane up + back")
  end }

shot { id = "S3", file = "s3-the-players", title = "The players", time = "8.5 – 12.5 s", cam = "Eye-level wide across the table, fleet side left, brood side right. This sets the 180-degree line.",
  lines = { "KID, BROOD SIDE (gold hoodie; growls two words, then his own voice): A rematch. After a short break.",
            "LITTLE SISTER (sun hat too big, a fry held like a trophy): Dibs on the crunchy ones!",
            "Bike helmet on the pilot kid's chair. A cooler under the table. Sand on the board's corner." },
  draw = function()
    sunset(250, 480)
    umbrella(480, 300, 1.2, K.coral); umbrella(120, 280, 0.7, K.teal); umbrella(850, 280, 0.7, K.gold)
    palm(60, 300, 1); palm(910, 300, 0.9)
    -- soft bystanders behind
    person(250, 300, 0.6, { skin = K.skinC, hair = K.wood2, top = K.grey, smile = true })
    person(700, 300, 0.6, { skin = K.skinD, hair = K.ink, top = K.grey, smile = true })
    person(250, 420, 1.2, { skin = K.skinA, hair = K.ink, top = K.teal, back = true, arm = { 60, -70 } })
    person(370, 410, 1.0, { skin = K.skinC, hair = "#b4532a", top = K.white, smile = true, arm = { 40, -50 } })
    person(610, 410, 1.0, { skin = K.skinB, hair = K.ink, top = K.gold, horns = true })
    person(730, 420, 1.2, { skin = K.skinD, hair = K.ink, top = "#8f2030", horns = true, smile = true })
    person(850, 440, 0.6, { skin = K.skinC, hair = "#9bd44a", top = "#9bd44a", smile = true, arm = { -20, -50 } })
    P({ 150, 400, 810, 400, 860, 450, 100, 450 }, K.wood, 1, K.ink)
    R(130, 450, 700, 22, K.wood2, 1, K.ink)
    P({ 330, 404, 630, 404, 660, 440, 300, 440 }, "#20605a", 1, K.ink)
    gargoyle(540, 428, 0.8, "#8f2030"); gargoyle(580, 424, 0.7, K.gold); ship(420, 428, 0.8, K.white); tank(380, 430, 0.7, "#6f8f4a")
    glass(200, 400, 0.8, 0.2); glass(790, 400, 0.8, 0.15)
    C(196, 300, 22, K.teal, 1, K.ink); R(180, 300, 32, 8, K.ink) -- bike helmet on the chair post
    R(430, 478, 90, 50, K.teal, 1, K.ink); R(430, 478, 90, 14, K.white, 1, K.ink)
    TF(475, 516, "cooler", 12, K.ink, "middle", "bold")
    safe()
    TF(250, 466, "PILOT KID = the player (never full face)", 13, K.cream, "middle", "bold")
    TF(700, 466, "BROOD SIDE: hoods with horns", 13, K.cream, "middle", "bold")
  end }

shot { id = "S4", file = "s4-free-refills", title = "Free refills", time = "12.5 – 17.0 s", cam = "Medium, low angle from the kids' eye line. She leans in on the near side, frame left. RACK FOCUS to the counter at 16.2 s.",
  lines = { "WAITRESS (pouring, deadpan): Refills for the fleet. On the house.",
            "WAITRESS (stage whisper, a nod at the counter): Don't tell the General.",
            "SFX: fizz with the exact rise of the in-game shield hum. Ice clink = pickup chime." },
  draw = function()
    R(0, 0, W, FH, K.sky); R(0, 0, W, 150, "#e8805f")
    -- far counter, soft: the owner as a small shape, the pass window
    R(560, 120, 360, 200, K.cream, 0.7, K.ink); R(600, 150, 280, 110, K.plum, 0.7, K.ink)
    person(740, 260, 0.7, { skin = K.skinC, hair = K.grey, top = K.white, smile = true, apron = true })
    R(560, 320, 360, 30, K.wood2, 0.8, K.ink)
    TF(740, 142, "ORDER UP", 14, K.ink, "middle", "bold")
    -- waitress, large, leaning in
    person(300, 560, 2.6, { skin = K.skinB, hair = K.violet, top = K.ink, smile = true, apron = true, arm = { 96, 34 } })
    R(256, 300, 60, 22, K.violet, 1, K.ink); TF(286, 316, "name tag", 11, K.white, "middle", "bold")
    -- pitcher and pour
    P({ 500, 300, 590, 290, 600, 380, 520, 392 }, K.white, 0.6, K.ink)
    P({ 510, 330, 594, 322, 600, 380, 520, 392 }, K.wood2, 0.9, K.ink)
    L(596, 300, 640, 400, K.wood2, 6)
    glass(650, 500, 1.6, 0.7)
    for i = 1, 7 do C(630 + (i * 13) % 40, 410 - i * 9, 3 + i % 3, K.white, 0.9, K.ink) end
    -- kid, back of head, foreground right
    C(860, 520, 80, K.ink, 1, K.ink); P({ 760, 540, 960, 540, 960, 500, 780, 500 }, K.teal, 1, K.ink)
    safe()
    arrow(120, 90, 250, 90, K.white, "leans in")
    arrow(520, 250, 690, 200, K.gold, "rack focus")
    sfx(690, 392, "fssss")
  end }

shot { id = "S5", file = "s5-the-general", title = "The General", time = "17.0 – 20.0 s", cam = "Medium close through the pass window, framed by order tickets. Slow push-in. He never stops smiling.",
  lines = { "OWNER (beaming, spatula salute, hits the bell): Order up, table five! Smile, everybody. It's a beautiful day!",
            "SFX: bell = the weapon-pickup chime, same pitch. Grill flare = the Ember Moon forge roar, one octave up.",
            "His cap wears the teal chevron. Behind him: the HALL OF FAME chalkboard and an old arcade cabinet. The ticket is your score." },
  draw = function()
    R(0, 0, W, FH, K.plum)
    R(80, 60, 800, 400, "#6b3a55", 1, K.ink)
    -- grill flames (Ember)
    for i = 0, 5 do P({ 120 + i * 40, 400, 140 + i * 40, 330 - (i % 2) * 30, 160 + i * 40, 400 }, i % 2 == 0 and K.coral or K.gold, 1, K.ink) end
    R(100, 400, 280, 60, K.ink)
    person(500, 470, 2.4, { skin = K.skinC, hair = K.grey, top = K.white, smile = true, apron = true, arm = { 70, -80 }, tall = 76 })
    -- chef hat that reads as a peaked cap
    R(452, 190, 96, 34, K.white, 1, K.ink); P({ 440, 224, 560, 224, 584, 240, 440, 240 }, K.ink, 1, K.ink)
    P({ 486, 200, 500, 214, 514, 200, 514, 208, 500, 222, 486, 208 }, K.teal, 1, K.ink)
    -- spatula
    L(736, 200, 770, 110, K.ink, 6); R(752, 70, 40, 46, K.grey, 1, K.ink)
    -- menu board
    R(620, 270, 250, 120, K.ink, 1, K.cream)
    TF(745, 300, "KRYBOR", 20, K.gold, "middle", "bold")
    TF(745, 322, "Ringfall Rings", 12, K.cream, "middle"); TF(745, 340, "Ember Moon Burger", 12, K.cream, "middle")
    TF(745, 358, "Hollow Tower", 12, K.cream, "middle"); TF(745, 376, "The Carrier (feeds five)", 12, K.cream, "middle")
    -- counter, bell, tickets
    R(0, 460, W, 80, K.wood, 1, K.ink)
    E(250, 458, 34, 10, K.ink); P({ 222, 456, 250, 420, 278, 456 }, K.gold, 1, K.ink); C(250, 418, 6, K.gold, 1, K.ink)
    for i = 0, 6 do R(110 + i * 110, 0, 60, 76 + (i % 3) * 10, K.cream, 1, K.ink) end
    L(80, 4, 880, 4, K.ink, 5)
    R(100, 96, 190, 150, K.ink, 1, K.wood2); TF(195, 120, "KRYBOR HALL OF FAME", 13, K.cream, "middle", "bold")
    for i = 0, 4 do TF(120, 144 + i * 20, (i + 1) .. ".  " .. ({ "YOU", "PIP", "ROK", "WSP", "SPR" })[i + 1] .. "   " .. (184300 - i * 21000), 13, i == 0 and K.gold or K.cream) end
    R(330, 96, 70, 150, K.navy, 1, K.ink); R(338, 122, 54, 44, K.teal, 0.8, K.ink); TF(365, 114, "KRYBOR", 10, K.gold, "middle", "bold"); TF(365, 264, "cabinet", 11, K.cream, "middle")
    safe()
    sfx(292, 420, "ding!")
    arrow(480, 520, 480, 484, K.white, "push in")
  end }

shot { id = "S6", file = "s6-overwatch", title = "Overwatch", time = "20.0 – 24.5 s", cam = "Over the kids' shoulders, low. Mom stands against the low sun: gold rim light. Kids turn on her first word.",
  lines = { "MOM (the Admiral's voice, no radio at all now): Squadron. Time to go home.",
            "LITTLE BROTHER: One more turn? Please?",
            "MOM (a beat; the smile she never shows on the radio): …One more turn." },
  draw = function()
    sunset(300, 600)
    palm(880, 350, 1.1)
    person(600, 450, 2.3, { skin = K.skinA, hair = K.grey, top = "#1c2a5a", smile = true, arm = { 60, 50 }, tall = 84 })
    -- gold buttons (the braid), teal star keyring (the fleet star), earbud (the headset)
    for i = 0, 2 do C(600, 290 + i * 40, 6, K.gold, 1, K.ink) end
    C(768, 418, 9, K.grey, 1, K.ink); P({ 768, 430, 778, 452, 758, 452 }, K.teal, 1, K.ink)
    C(652, 206, 6, K.white, 1, K.ink)
    -- rim light
    L(668, 150, 690, 250, K.cream, 5); L(706, 300, 716, 440, K.cream, 5)
    -- foreground kids, backs to camera
    C(170, 470, 74, K.ink, 1, K.ink); P({ 60, 540, 290, 540, 280, 500, 70, 500 }, K.teal, 1, K.ink)
    C(360, 500, 56, "#b4532a", 1, K.ink)
    P({ 866, 540, 960, 540, 960, 470, 880, 470 }, "#8f2030", 1, K.ink)
    P({ 880, 470, 870, 420, 910, 452 }, "#8f2030", 1, K.ink)
    safe()
    TF(600, 520, "MOM = FLEET ADMIRAL (OVERWATCH)", 14, K.ink, "middle", "bold")
    arrow(250, 380, 330, 340, K.white, "heads turn")
  end }

shot { id = "S7", file = "s7-krybor", title = "Krybor", time = "24.5 – 29.0 s", cam = "Crane up and back to a wide exterior. The neon sign flickers on as the sun touches the sea. Hold for the captions.",
  lines = { "CAPTION: SAN DIEGO · AFTER THE LAST TURN   then   Same friends. Next round?",
            "SFX: the sign's neon hum is the carrier field hum. The metal theme returns as a ukulele for four bars.",
            "Then the credits. The box lid on the table edge carries the edition for the difficulty just played." },
  draw = function()
    sunset(280, 200)
    palm(80, 340, 1.2); palm(900, 330, 1.0)
    R(520, 150, 340, 190, K.cream, 1, K.ink)
    P({ 500, 150, 880, 150, 850, 110, 530, 110 }, K.coral, 1, K.ink)
    R(560, 60, 260, 56, K.navy, 1, K.ink)
    TF(691, 101, "KRYBOR", 34, K.ink, "middle", "bold"); TF(690, 100, "KRYBOR", 34, K.violet, "middle", "bold")
    L(574, 108, 806, 108, K.teal, 3)
    R(560, 190, 110, 80, K.plum, 1, K.ink); R(720, 190, 60, 150, K.wood2, 1, K.ink)
    TF(690, 140, "burgers · shakes · since 1982", 13, K.cream, "middle", "bold")
    umbrella(300, 430, 1.0, K.coral); umbrella(110, 450, 0.7, K.teal); umbrella(470, 420, 0.6, K.gold)
    P({ 220, 430, 380, 430, 400, 452, 200, 452 }, K.wood, 1, K.ink)
    person(240, 432, 0.55, { skin = K.skinA, hair = K.ink, top = K.teal, back = true })
    person(280, 430, 0.5, { skin = K.skinC, hair = "#b4532a", top = K.white, smile = true })
    person(330, 430, 0.5, { skin = K.skinB, hair = K.ink, top = K.gold, horns = true, smile = true })
    person(366, 432, 0.55, { skin = K.skinD, hair = K.ink, top = "#8f2030", horns = true, smile = true })
    person(440, 440, 0.8, { skin = K.skinA, hair = K.grey, top = "#1c2a5a", smile = true })
    person(600, 340, 0.6, { skin = K.skinB, hair = K.violet, top = K.ink, smile = true, apron = true })
    person(750, 340, 0.6, { skin = K.skinC, hair = K.grey, top = K.white, smile = true, apron = true, arm = { 30, -50 } })
    R(0, 468, W, 72, K.ink, 0.55)
    TF(480, 494, "SAN DIEGO · AFTER THE LAST TURN", 18, K.cream, "middle", "bold")
    TF(480, 522, "Same friends. Next round?", 20, K.gold, "middle", "bold")
    safe()
    arrow(840, 440, 840, 380, K.white, "crane up")
  end }

shot { id = "S8", file = "s8-button", title = "Button (after the credits)", time = "3.0 s, after the credits", cam = "Locked insert on the shelf by the register. Dusk-blue, one warm lamp. One tiny move, then black.",
  lines = { "WAITRESS (off, to nobody): Same time next week, Marshal?",
            "She stands a forgotten gargoyle with the others. For four frames its eyes catch the lamp. Cut to black.",
            "Nothing explains it. The shelf holds one officer per campaign finished on this device (ledger row R7)." },
  draw = function()
    R(0, 0, W, FH, "#27335c")
    P({ 560, 0, 960, 0, 960, 300, 700, 300 }, K.amber, 0.35)
    R(0, 330, W, 26, K.wood2, 1, K.ink); R(0, 356, W, 184, "#1d2748")
    local cols = { K.teal, K.violet, K.coral, K.gold, "#8f2030" }
    for i, c in ipairs(cols) do gargoyle(170 + i * 110, 330, 2.0, c) end
    R(40, 250, 110, 80, K.cream, 1, K.ink); TF(95, 284, "LOST +", 15, K.ink, "middle", "bold"); TF(95, 306, "FOUND", 15, K.ink, "middle", "bold")
    -- the hand placing the last figure
    L(960, 180, 830, 262, K.ink, 44); L(960, 180, 830, 262, K.skinB, 38)
    gargoyle(810, 330, 2.0, K.teal)
    C(802, 264, 4, K.gold); C(818, 264, 4, K.gold)
    L(790, 250, 776, 236, K.gold, 3); L(830, 250, 844, 236, K.gold, 3)
    safe()
    sfx(700, 236, "glint")
  end }

local function board(sh)
  buf = {}
  add(string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">', W, H, W, H))
  add(string.format('<rect x="0" y="0" width="%d" height="%d" fill="%s"/>', W, H, K.paper))
  sh.draw()
  -- mask anything that spilled outside the frame, then the labels
  add(string.format('<rect x="0" y="0" width="%d" height="%d" fill="%s"/>', W, HEAD, K.paper))
  add(string.format('<rect x="0" y="%d" width="%d" height="%d" fill="%s"/>', HEAD + FH, W, FOOT, K.paper))
  add(string.format('<rect x="1" y="%d" width="%d" height="%d" fill="none" stroke="%s" stroke-width="3"/>', HEAD, W - 2, FH, K.ink))
  T(14, 26, sh.id .. "  " .. sh.title, 22, K.ink, "start", "bold")
  T(W - 14, 26, sh.time, 18, K.ink, "end", "bold")
  T(14, 47, "CAMERA: " .. sh.cam, 14, K.note)
  for i, l in ipairs(sh.lines) do T(14, HEAD + FH + 4 + i * 26, l, 15, i == 1 and K.ink or K.note) end
  T(W - 14, H - 8, "white dashes = portrait-safe column (9:16)", 11, K.note, "end")
  add("</svg>")
  local f = assert(io.open(out_dir .. "/" .. sh.file .. ".svg", "w"))
  f:write(table.concat(buf, "\n"), "\n")
  f:close()
end

for _, sh in ipairs(shots) do board(sh) end
io.write(#shots, " boards written to ", out_dir, "\n")
