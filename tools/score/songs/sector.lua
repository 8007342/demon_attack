-- The sector band (sectors 2-4: Ringfall, Ember Moon, The Hollow; and the Stormfront section of every world).
-- Original writing from the game's own motifs: each world's riff and hook (tools/music_motifs.py MOTIFS[2..4]),
-- its harmony (art/music/campaign.json `levels`), and the campaign theme (degrees 1-3-5-4, rhythm 1.5/.5/1/1)
-- sung in the world's key. The form is Krybor's (songs/krybor.lua): a clean arrival, the riff and the hook (A),
-- the answer with the theme called and answered (B), the reduced half-time contrast (C), the developed recap (D),
-- the clear's march flourish with a held pad, and the bonus level's half-time storm. One band plays every world:
-- the same kit, the same doubled guitars on power-chord roots, the same lead pair, pads, timpani and bells; only
-- the world's picking and drum style change (rock, metal gallop, doom), so a run sounds like one record.
--
-- Parts per section (tracks; the tier masks of song-map.json choose which play): drums (kick, snare, hats),
-- cymbals, drums2 (double kick), bass, gtrL/gtrR (power-chord roots; velocity <= 92 is palm-muted), clean, lead,
-- lead2 (diatonic thirds), organ, strings, brass, choir, timpani, bells, fanfare (the fleet layer).
local M = {}
local A  -- the arrange vocabulary, set by the composer call

-- The worlds: motifs from tools/music_motifs.py MOTIFS[n] (riff, hook) and art/music/campaign.json (harmony).
-- `pads` is the harmony as pad chords (campaign.json's Cm-B half bar is voiced over its dominant G); `contrast`
-- the C section's ringing chords; `cadence` the clear's four bars; `five` the dominant chord of the arrival's
-- last bar and the D section's turnaround.
M.worlds = {
  r = {
    style = 'rock', floor = 'D3',
    riff = { 'D2 D2 D2 D2 D2 D2 D2 E2', 'F#2 F#2 F#2 F#2 F#2 F#2 F#2 F#2', 'G2 G2 G2 G2 G2 G2 G2 G2',
      'A2 A2 A2 A2 A2 A2 A2 A2', 'B1 B1 B1 B1 B1 B1 B1 B1', 'G2 G2 G2 G2 G2 G2 G2 G2', 'E2 E2 E2 E2 E2 E2 E2 E2',
      'A2 A2 A2 A2 A2 A2 C#3 C#3' },
    pads = { 'D', 'F#m', 'G', 'A', 'Bm', 'G', 'Em', 'A' },
    hook = 'A4:2 F#4:1 A4:1 C#5:3 B4:1 B4:1 D5:1 B4:1 G4:1 A4:4 F#5:2 E5:1 D5:1 D5:2 B4:1 D5:1 E5:1 G5:1 F#5:1 E5:1 C#5:2 E5:2',
    contrast = { 'G', 'A', 'D', 'D', 'Bm', 'G', 'A', 'A' },
    cadence = { 'D', 'G|A', 'Em|A', 'D' },
    five = 'A', arpFloor = 'D3',
  },
  e = {
    style = 'metal', floor = 'E3',
    riff = { 'E2 E2 E2 E2 E2 E2 E2 E2', 'E2 E2 E2 E2 F2 F2 G2 G2', 'C3 C3 C3 C3 D3 D3 D3 D3',
      'E2 E2 E2 E2 E2 E2 F2 E2', 'E2 E2 E2 E2 E2 E2 E2 E2', 'E2 E2 E2 E2 F2 F2 G2 G2', 'F2 F2 F2 F2 G2 G2 G2 G2',
      'A2 A2 A2 A2 B2 B2 B2 B2' },
    pads = { 'Em', 'Em', 'C|D', 'Em', 'Em', 'Em', 'F|G', 'Am|B' },
    hook = 'E5:1 F#5:.5 G5:.5 B5:1 G5:1 A5:.5 G5:.5 F#5:1 E5:2 G5:1 E5:1 A5:1 F#5:1 E5:4 '
      .. 'E5:1 F#5:.5 G5:.5 B5:1 G5:1 A5:.5 G5:.5 F#5:1 G5:1 B5:1 C6:1 A5:1 D6:1 B5:1 C6:1 B5:1 A5:1 F#5:1',
    contrast = { 'C', 'D', 'Em', 'Em', 'F', 'G', 'B', 'B' },
    cadence = { 'Em', 'Am|D', 'C|B', 'E' },
    five = 'B', arpFloor = 'E3',
  },
  h = {
    style = 'doom', floor = 'C3',
    riff = { 'C2 C2 C2 C2 C2 C2 Eb2 Eb2', 'Gb2 Gb2 F2 F2 C2 C2 C2 C2', 'Eb2 Eb2 Eb2 Eb2 Db2 Db2 Db2 Db2',
      'C2 C2 C2 C2 C2 C2 B1 B1', 'C2 C2 C2 C2 C2 C2 Eb2 Eb2', 'Gb2 Gb2 F2 F2 Eb2 Eb2 Db2 Db2',
      'Ab1 Ab1 Ab1 Ab1 Ab1 Ab1 Ab1 Ab1', 'G1 G1 G1 G1 G1 G1 Gb1 Gb1' },
    pads = { 'Cm', 'Gb|Fm', 'Eb|Db', 'Cm|G', 'Cm', 'Gb|Fm', 'Ab', 'G' },
    hook = 'C5:2 G4:1 Ab4:1 G4:4 Eb5:2 D5:2 C5:4 C5:2 G4:1 Ab4:1 B4:2 C5:2 Ab4:2 Eb5:2 D5:2 B4:2',
    contrast = { 'Ab', 'Fm', 'Cm', 'Cm', 'Eb', 'Ab', 'G', 'G' },
    cadence = { 'Cm', 'Ab|Bb', 'Fm|G', 'C' },
    five = 'G', arpFloor = 'C3',
  },
  -- Krybor's storm (songs/krybor.lua writes the rest of its song).
  k = {
    style = 'punk', floor = 'E3',
    riff = { 'E2 E2 E2 E2 E2 E2 G2 A2', 'E2 E2 E2 E2 D2 D2 B1 B1', 'C3 C3 C3 C3 C3 C3 D3 D3',
      'D3 D3 D3 D3 D3 D3 A2 G2', 'E2 E2 E2 E2 E2 E2 G2 A2', 'E2 E2 E2 E2 D2 D2 B1 B1', 'A2 A2 A2 A2 G2 G2 G2 G2',
      'B1 B1 B1 B1 B1 B1 D2 D#2' },
    pads = { 'Em', 'Em', 'C', 'D', 'Em', 'Em', 'Am|G', 'B' },
    five = 'B', arpFloor = 'E3',
  },
}

-- The campaign theme and its developments, in degrees of the world's key (the shapes Krybor sings in E minor).
local THEME_B = '1:1.5 3:.5 5:1 4:1 3:2 2:1 1:1 8:1.5 7:.5 6:1 5:1 4:2 2:2 '
  .. '1:1.5 3:.5 5:1 4:1 5:1 7:1 8:2 8:1 7:1 6:1 5:1 5:2 7#:2'
local THEME_C = '1:3 3:1 5:2 4:2 3:3 2:1 1:4 1:3 3:1 5:2 4:2 5:4 7#:4'
local THEME_ARRIVAL = '1:1.5 3:.5 5:1 4:1'
local CLEAR_TUNE = '1:1.5 3:.5 5:1 4:1 3:1 4:1 5:1 7#:1 6:2 5:1 4:1 5:1 3:1 8:2'
local STORM_LINE = '1:4 3:2 2:2 1:4 7#:4 1:4 3:2 4:2 5:6 R:2'

-- Shared parts --------------------------------------------------------------------------------------------------
local function hats(s, b, v, step)
  step = step or 0.5
  for e = 0, 4 / step - 1 do s:hit('drums', (b - 1) * 4 + e * step, e % 2 == 0 and 'hat' or 'pedal', e % 2 == 0 and v or v - 18, step) end
end
local function cymbals(s, bars, every, rideStep)
  for b = 1, bars do
    local t = (b - 1) * 4
    if (b - 1) % every == 0 then s:hit('cymbals', t, b == 1 and 'crash' or 'crash2', b == 1 and 112 or 98, 2) end
    for e = 0, 4 / rideStep - 1 do
      if not ((b - 1) % every == 0 and e == 0) then s:hit('cymbals', t + e * rideStep, 'ride', e % 2 == 0 and 84 or 70, rideStep) end
    end
  end
end
local function doubleKick(s, bars, from, to, v)
  for b = 1, bars do
    for i = from * 4, to * 4 - 1 do s:hit('drums2', (b - 1) * 4 + i * 0.25, 'kick', (v or 78) + (i % 4 == 0 and 8 or 0)) end
  end
end
local function first(sym) return sym:match('^[^|]+') end

-- Guitar figures on the riff's eighth-note roots ----------------------------------------------------------------
-- Eighth-note downstrokes, palm-muted, opened where the root changes (Krybor's drive).
local function chug8(s, rows)
  for b, row in ipairs(rows) do
    for e, root in ipairs(row) do
      local t = (b - 1) * 4 + (e - 1) * 0.5
      local change = e == 1 or row[e - 1] ~= root
      s:power('gtrL', t, change and 0.48 or 0.42, root, change and 112 or 88)
      s:power('gtrR', t, change and 0.48 or 0.4, root, change and 108 or 84)
      s:note('bass', t, 0.45, root - 12, change and 110 or 98)
    end
  end
end
-- Gallop: an eighth and two sixteenths on each beat's root.
local function gallop(s, rows, v0)
  v0 = v0 or 112
  for b, row in ipairs(rows) do
    for beat = 0, 3 do
      local root = row[beat * 2 + 1]
      local t = (b - 1) * 4 + beat
      local new = beat == 0 or row[beat * 2 - 1] ~= root
      for i, off in ipairs({ 0, 0.5, 0.75 }) do
        local v = i == 1 and (new and v0 or v0 - 20) or v0 - 28
        s:power('gtrL', t + off, i == 1 and 0.45 or 0.22, root, v)
        s:power('gtrR', t + off, i == 1 and 0.45 or 0.22, root, v - 4)
        s:note('bass', t + off, i == 1 and 0.45 or 0.22, root - 12, i == 1 and 108 or 96)
      end
    end
  end
end
-- Melodic rock, 3+3+2: open chords ring on 1, the and of 2, and 4 (the root of that eighth); the right double
-- keeps muted eighths underneath, the bass drives eighths.
local function rock332(s, rows)
  for b, row in ipairs(rows) do
    local t = (b - 1) * 4
    for _, hit in ipairs({ { 0, 1.45 }, { 3, 1.45 }, { 6, 0.95 } }) do
      s:power('gtrL', t + hit[1] * 0.5, hit[2], row[hit[1] + 1], 114)
    end
    for e, root in ipairs(row) do
      local accent = e == 1 or e == 4 or e == 7
      s:power('gtrR', t + (e - 1) * 0.5, 0.42, root, accent and 104 or 82)
      s:note('bass', t + (e - 1) * 0.5, 0.45, root - 12, accent and 110 or 96)
    end
  end
end
-- Doom: each run of equal roots held, both doubles open, the bass doubling; a muted pickup into a new root.
local function doomRuns(s, rows, v)
  v = v or 116
  for b, row in ipairs(rows) do
    for i, run in ipairs(A.runs(row)) do
      local t = (b - 1) * 4 + run.t
      s:power('gtrL', t, run.len - 0.06, run.p, i == 1 and v or v - 8)
      s:power('gtrR', t, run.len - 0.06, run.p, i == 1 and v - 4 or v - 12)
      s:note('bass', t, run.len - 0.06, run.p - 12, i == 1 and v - 2 or v - 10)
    end
  end
end

-- Drum styles ---------------------------------------------------------------------------------------------------
local function drumBar(s, style, b, fill, v)
  local t = (b - 1) * 4
  v = v or 0
  if style == 'rock' then
    s:hit('drums', t, 'kick', 112 + v); s:hit('drums', t + 1.5, 'kick', 98 + v); s:hit('drums', t + 2.5, 'kick', 104 + v)
    s:hit('drums', t + 1, 'snare', 112 + v)
    if not fill then s:hit('drums', t + 3, 'snare', 114 + v) end
    hats(s, b, 84 + v)
  elseif style == 'metal' then
    for beat = 0, 3 do
      if not (fill and beat == 3) then
        for _, off in ipairs({ 0, 0.5, 0.75 }) do s:hit('drums', t + beat + off, 'kick', (off == 0 and 110 or 94) + v) end
      end
    end
    s:hit('drums', t + 1, 'snare', 114 + v)
    if not fill then s:hit('drums', t + 3, 'snare', 116 + v) end
    hats(s, b, 82 + v)
  elseif style == 'doom' then
    s:hit('drums', t, 'kick', 116 + v); s:hit('drums', t + 1.5, 'kick', 96 + v)
    if b % 2 == 0 then s:hit('drums', t + 2.5, 'kick', 100 + v) end
    s:hit('drums', t + 2, 'snare', 118 + v)
    if not fill then hats(s, b, 78 + v, 1) end
  else -- punk
    s:hit('drums', t, 'kick', 112 + v); s:hit('drums', t + 2, 'kick', 106 + v)
    s:hit('drums', t + 1, 'snare', 112 + v)
    if not fill then s:hit('drums', t + 3, 'snare', 114 + v) end
    hats(s, b, 86 + v)
  end
  if fill then s:fill('drums', b, style == 'doom' and 2 or 3, 92 + v) end
end
local function riffFor(s, style, rows)
  if style == 'rock' then rock332(s, rows)
  elseif style == 'metal' then gallop(s, rows)
  elseif style == 'doom' then doomRuns(s, rows)
  else chug8(s, rows) end
end

-- The sections --------------------------------------------------------------------------------------------------
local function arrival(A, s, W, key)
  local P = A.pitch
  local pads = W.pads
  -- Bars 1-2: clean arpeggios over the first two chords (root, fifth, octave, tenth, twelfth and back).
  for b = 1, 2 do
    local sym = first(pads[b])
    local r = A.root(sym, P(W.arpFloor))
    local _, iv = A.chord(sym)
    local third = iv[2]
    for e, off in ipairs({ 0, 7, 12, 12 + third, 19, 12 + third, 12, 7 }) do s:note('clean', (b - 1) * 4 + (e - 1) * 0.5, 0.9, r + off, 58 + b * 4) end
  end
  for e, sym in ipairs({ first(pads[3]), first(pads[4]) }) do
    local r = A.root(sym, P(W.arpFloor))
    for k, off in ipairs({ 0, 7, 12, 16 }) do s:note('clean', 8 + (e - 1) * 2 + (k - 1) * 0.5, 0.9, r + off, 70) end
  end
  s:pads('organ', { first(pads[1]), first(pads[2]), first(pads[3]) .. '|' .. first(pads[4]), W.five }, P(W.floor), 3, 54)
  s:melody('bells', A.line(key, 5, THEME_ARRIVAL, 4), 64, 1.4)
  s:pads('choir', { first(pads[3]) .. '|' .. first(pads[4]), W.five }, P(W.floor) + 12, 3, 50, 8)
  for i = 0, 3 do s:hit('drums', 4 + i, 'floorLo', 62 + i * 6, 1) end
  s:hit('drums', 8, 'kick', 100); s:hit('drums', 10, 'kick', 96); s:hit('drums', 11, 'snare', 96)
  hats(s, 3, 70)
  local r3, r4, r5 = A.root(first(pads[3]), P('B1')), A.root(first(pads[4]), P('B1')), A.root(W.five, P('B1'))
  s:note('bass', 8, 1.9, r3 - 12, 96); s:note('bass', 10, 1.9, r4 - 12, 100); s:note('bass', 12, 3.9, r5 - 12, 108)
  s:hit('drums', 12, 'kick', 112); s:hit('cymbals', 12, 'crash', 104, 2)
  s:power('gtrL', 12, 1.9, r5, 110); s:power('gtrR', 12, 1.9, r5, 106)
  for i = 0, 3 do s:power('gtrL', 14 + i * 0.5, 0.4, r5, 76 + i * 8); s:power('gtrR', 14 + i * 0.5, 0.4, r5, 72 + i * 8) end
  s:roll('drums', 13, 3, 'snare', 48, 112)
  s:roll('timpani', 13, 3, r5, 46, 100)
end

local function sectionA(A, s, W, key, riff, hook)
  local P = A.pitch
  riffFor(s, W.style, riff)
  for b = 1, 8 do drumBar(s, W.style, b, b == 8) end
  cymbals(s, 8, 4, W.style == 'doom' and 1 or 1)
  doubleKick(s, 8, W.style == 'doom' and 2 or 0, 4, 74)
  s:melody('lead', hook, 104, W.style == 'doom' and 0.98 or 0.95)
  s:harmony('lead2', hook, 92, -2, key)
  s:pads('organ', W.pads, P(W.floor), 3, 64)
  s:pads('strings', W.pads, P(W.floor) + 7, 4, 56)
  for _, b in ipairs({ 1, 5 }) do s:chord('brass', (b - 1) * 4, 1.5, A.voicing(first(W.pads[b]), P(W.floor), 3), 98) end
  s:chord('brass', 28, 1.5, A.voicing(first(W.pads[8]), P(W.floor), 3), 100)
  s:pads('choir', { W.pads[5], W.pads[6], W.pads[7], W.pads[8] }, P(W.floor) + 12, 3, 62, 16)
  local tonic = A.root(first(W.pads[1]), P('B1'))
  s:note('timpani', 0, 1.5, tonic, 104); s:note('timpani', 16, 1.5, tonic, 100)
  local five = A.root(W.five, P('B1'))
  s:note('timpani', 30, 0.9, five, 96); s:note('timpani', 31, 0.9, five, 108)
  s:note('bells', 0, 3, tonic + 36, 76); s:note('bells', 16, 3, tonic + 36, 76)
end

local function sectionB(A, s, W, key, riff)
  local P = A.pitch
  if W.style == 'metal' or W.style == 'rock' then chug8(s, riff) else gallop(s, riff, 114) end
  for b = 1, 8 do
    local t = (b - 1) * 4
    if W.style == 'doom' then
      drumBar(s, 'doom', b, b == 8, 2)
      for _, off in ipairs({ 0.5, 0.75 }) do s:hit('drums', t + off, 'kick', 92) end
    else
      for beat = 0, 3, 2 do for _, off in ipairs({ 0, 0.5, 0.75 }) do s:hit('drums', t + beat + off, 'kick', off == 0 and 110 or 94) end end
      s:hit('drums', t + 1, 'snare', 112)
      if b ~= 8 then s:hit('drums', t + 3, 'snare', 114) else s:fill('drums', 8, 3, 94) end
      hats(s, b, 82)
    end
  end
  cymbals(s, 8, 4, W.style == 'doom' and 1 or 0.5)
  doubleKick(s, 8, 2, 4, 76)
  local theme = A.line(key, 4, THEME_B)
  s:melody('lead', theme, 106, 0.97, 12)
  s:harmony('lead2', theme, 94, -2, key, 0.97)
  for i = 0, 7, 2 do s:chord('brass', (i + 1) * 4, 0.9, A.voicing(first(W.pads[i + 2]), P(W.floor) + 3, 3), 96) end
  s:pads('organ', W.pads, P(W.floor), 3, 62)
  s:pads('strings', W.pads, P(W.floor) + 12, 3, 54)
  s:pads('choir', W.pads, P(W.floor) + 12, 3, 58)
  local tonic = A.root(first(W.pads[1]), P('B1'))
  s:note('timpani', 0, 1, tonic, 102); s:note('timpani', 16, 1, tonic, 98)
  s:note('bells', 0, 3, A.degree(key, 5, 5), 70); s:note('bells', 16, 3, A.degree(key, 5, 5), 70)
end

local function sectionC(A, s, W, key)
  local P = A.pitch
  local ch = W.contrast
  for b = 1, 8 do
    local t, r = (b - 1) * 4, A.root(ch[b], P('B1'))
    s:power('gtrL', t, 3.9, r, 104)
    for e = 0, 7 do s:power('gtrR', t + e * 0.5, 0.38, r, e == 0 and 96 or 80) end
    s:note('bass', t, 1.9, r - 12, 104); s:note('bass', t + 2, 1.9, r - 12, 96)
    s:hit('drums', t, 'kick', 110); s:hit('drums', t + 1.5, 'kick', 92); s:hit('drums', t + 2, 'snare', 112)
    for e = 0, 3 do s:hit('drums', t + e, 'hat', e % 2 == 0 and 78 or 64) end
    local arp = A.voicing(ch[b], P(W.floor) + 12, 3)
    for e = 0, 7 do s:note('clean', t + e * 0.5, 0.9, arp[e % 3 + 1] + (e >= 4 and 12 or 0), 62) end
  end
  s:fill('drums', 8, 2, 84)
  for b = 1, 8, 2 do s:hit('cymbals', (b - 1) * 4, 'crash2', 92, 3) end
  for b = 1, 8 do for e = 1, 3 do s:hit('cymbals', (b - 1) * 4 + e, 'ride', 66) end end
  doubleKick(s, 1, 2, 4, 72); for i = 0, 7 do s:hit('drums2', 28 + 2 + i * 0.25, 'kick', 78) end
  local theme = A.line(key, 5, THEME_C)
  s:melody('lead', theme, 100, 0.98)
  s:harmony('lead2', theme, 88, -2, key, 0.98)
  s:pads('organ', ch, P(W.floor), 3, 60)
  s:pads('strings', ch, P(W.floor) + 3, 4, 52)
  s:pads('choir', ch, P(W.floor) + 12, 3, 60)
  for b = 1, 8, 2 do s:note('bells', (b - 1) * 4, 3, theme[(b + 1) // 2 * 2 - 1].p, 68) end
  s:note('timpani', 0, 1, A.root(ch[1], P('A1')), 96); s:note('timpani', 16, 1, A.root(ch[5], P('A1')), 96)
  s:chord('brass', 24, 3.8, A.voicing(ch[7], P(W.floor), 3), 84)
end

local function sectionD(A, s, W, key, riff, hook)
  local P = A.pitch
  if W.style == 'doom' then gallop(s, riff, 116) else chug8(s, riff) end
  for b = 1, 8 do
    local t = (b - 1) * 4
    if W.style == 'doom' then
      for e = 0, 3 do s:hit('drums', t + e, 'kick', e % 2 == 0 and 112 or 96) end
      s:hit('drums', t + 1, 'snare', 114)
      if b % 4 ~= 0 then s:hit('drums', t + 3, 'snare', 116) end
    else
      for e = 0, 7 do s:hit('drums', t + e * 0.5, 'kick', e % 2 == 0 and 108 or 92) end
      for beat = 1, 3, 2 do if not (b % 4 == 0 and beat == 3) then s:hit('drums', t + beat, 'snare', 114) end end
    end
    hats(s, b, 88)
    if b % 4 == 0 then s:fill('drums', b, 3, 96) end
  end
  cymbals(s, 8, 2, 0.5)
  doubleKick(s, 8, 0, 4, 80)
  local a, z = {}, {}
  for _, n in ipairs(hook) do if n.t < 16 then a[#a + 1] = n else z[#z + 1] = n end end
  local up = W.style == 'metal' and 0 or 12  -- Ember Moon's hook already sits high
  s:melody('lead', a, 106); s:melody('lead', z, 110, 0.95, up)
  s:harmony('lead2', a, 96, -2, key); s:harmony('lead2', z, 98, up > 0 and 5 or -2, key)
  s:melody('brass', z, 92, 0.9, up - 12)
  s:pads('organ', W.pads, P(W.floor), 3, 66)
  s:pads('strings', W.pads, P(W.floor) + 7, 4, 58)
  s:pads('choir', W.pads, P(W.floor) + 12, 3, 66)
  for _, b in ipairs({ 1, 3, 5, 7 }) do s:note('timpani', (b - 1) * 4, 1, A.root(first(W.pads[b]), P('A1')), 104) end
  s:note('bells', 0, 3, A.degree(key, 1, 5), 78); s:note('bells', 16, 3, A.degree(key, 1, 6), 74)
end

-- Stormfront: the riff's bar roots held half-time as ringing chords, the right double in muted sixteenths,
-- floor toms rolling like thunder into bars 4 and 8, the strings bowing eighths, the theme low and slow.
function M.storm(arrange, s, W, key)
  A = arrange
  local P = A.pitch
  local rows = A.riff(W.riff)
  for b, row in ipairs(rows) do
    local t = (b - 1) * 4
    local r1, r2 = row[1], row[5]
    s:power('gtrL', t, r1 == r2 and 3.9 or 1.9, r1, 112)
    if r1 ~= r2 then s:power('gtrL', t + 2, 1.9, r2, 106) end
    for k = 0, 15 do s:power('gtrR', t + k * 0.25, 0.22, k < 8 and r1 or r2, k % 4 == 0 and 92 or 76) end
    s:note('bass', t, r1 == r2 and 3.9 or 1.9, r1 - 12, 108)
    if r1 ~= r2 then s:note('bass', t + 2, 1.9, r2 - 12, 102) end
    s:hit('drums', t, 'kick', 116); s:hit('drums', t + 2.5, 'kick', 100); s:hit('drums', t + 2, 'snare', 118)
    hats(s, b, 72, 1)
    if b % 4 == 0 then
      for k = 0, 7 do s:hit('drums', t + 2 + k * 0.25, k < 4 and 'floorHi' or 'floorLo', 84 + k * 5) end
      s:roll('timpani', t + 1, 3, A.root(first(W.pads[1]), P('B1')), 56, 112)
    end
    s:hit('cymbals', t, b % 4 == 1 and 'crash' or 'ride', b % 4 == 1 and 110 or 78, 2)
    s:hit('cymbals', t + 2, 'ride', 72)
    local parts = A.split(W.pads[b])
    for e = 0, 7 do
      local sym
      for _, part in ipairs(parts) do if e * 0.5 >= part.t - 1e-9 then sym = part.sym end end
      s:chord('strings', t + e * 0.5, 0.45, A.voicing(sym, P(W.floor) + 7, 3), e % 2 == 0 and 66 or 54)
    end
  end
  doubleKick(s, 8, 3, 4, 82)
  local line = A.line(key, 4, STORM_LINE)
  s:melody('lead', line, 98, 0.98)
  s:harmony('lead2', line, 86, -2, key, 0.98)
  s:pads('organ', W.pads, P(W.floor), 3, 60)
  s:pads('choir', W.pads, P(W.floor) + 12, 3, 62)
  s:note('bells', 0, 3, A.degree(key, 5, 5), 86); s:note('bells', 16, 3, A.degree(key, 5, 5), 86)
  s:note('bells', 0, 3, A.degree(key, 1, 5, 1), 60)
  s:chord('brass', 28, 3.8, A.voicing(W.five, P(W.floor), 3), 88)
  s:note('clean', 12, 3.8, A.degree(key, 5, 4), 66); s:note('clean', 28, 3.8, A.degree(key, 7, 4, key.mode == 'minor' and 1 or 0), 66)
end

local function clear(A, s, W, key, spec)
  local P = A.pitch
  local major = A.key(spec.key or spec.songKey)
  local songKey = A.key(spec.songKey)
  local tune = A.line(songKey, 5, CLEAR_TUNE)
  -- The tune's last bar sits in the clear's (major) key: its third is the Picardy third.
  for _, n in ipairs(tune) do if n.t >= 12 and songKey.mode == 'minor' and (n.p - songKey.tonic) % 12 == 3 then n.p = n.p + 1 end end
  s:melody('lead', tune, 110, 0.96)
  for _, n in ipairs(tune) do s:note('fanfare', n.t, n.len * 0.94, A.diatonic(n.p, -2, n.t >= 12 and major or songKey), 100) end
  s:melody('fanfare', tune, 96, 0.94, -12)
  local ch = W.cadence
  for b, sym in ipairs(ch) do
    for _, part in ipairs(A.split(sym)) do
      local t, r = (b - 1) * 4 + part.t, A.root(part.sym, P('B1'))
      if b < 4 then
        for e = 0, part.len * 2 - 1 do
          s:power('gtrL', t + e * 0.5, 0.42, r, e == 0 and 112 or 90)
          s:power('gtrR', t + e * 0.5, 0.42, r, e == 0 and 108 or 86)
          s:note('bass', t + e * 0.5, 0.45, r - 12, 104)
        end
      else
        s:power('gtrL', t, 3.9, r, 116); s:power('gtrR', t, 3.9, r, 112); s:note('bass', t, 3.9, r - 12, 112)
      end
    end
  end
  local floor = P(W.floor)
  s:pads('organ', ch, floor, 3, 74)
  s:pads('strings', ch, floor + 4, 4, 66)
  s:pads('choir', ch, floor + 12, 3, 70)
  s:pads('fanfare', ch, floor + 3, 3, 92)
  for b = 1, 3 do
    local t = (b - 1) * 4
    s:hit('drums', t, 'kick', 112); s:hit('drums', t + 2, 'kick', 104)
    for e = 0, 7 do s:hit('drums', t + e * 0.5, 'snare', e % 4 == 0 and 112 or e % 2 == 0 and 96 or 78) end
    s:hit('cymbals', t, 'crash', 108, 2)
  end
  local tonic = A.root(first(ch[4]), P('B1'))
  s:hit('drums', 12, 'kick', 118); s:hit('cymbals', 12, 'crash', 116, 4); s:hit('cymbals', 12, 'china', 100, 2)
  s:roll('timpani', 13, 3, tonic, 60, 104)
  s:note('timpani', 12, 1, tonic, 116)
  s:note('bells', 12, 4, tonic + 36, 84); s:note('bells', 12, 4, tonic + 43, 74)
  -- hold (bar 5): a soft major pad that can repeat through the travel.
  s:chord('organ', 16, 4, A.voicing(ch[4], floor, 3), 50)
  s:chord('strings', 16, 4, A.voicing(ch[4], floor + 4, 4), 44)
  s:chord('choir', 16, 4, A.voicing(ch[4], floor + 7, 3), 44)
  s:note('bass', 16, 4, tonic - 12, 70)
end

-- The composer (score_gen.lua calls it per song) ----------------------------------------------------------------
setmetatable(M, { __call = function(_, arrange, spec, seed, songId)
  A = arrange
  local W = assert(M.worlds[songId], 'no world for sector song ' .. tostring(songId))
  local key = A.key(spec.key)
  local riff = A.riff(W.riff)
  local hook = A.seq(W.hook)
  local S = {}
  local function new(id) local s = A.section(id, spec.sections[id].bars, seed + #id * 89 + id:byte(1) + songId:byte(1) * 7); S[id] = s; return s end
  arrival(A, new('arrival'), W, key)
  sectionA(A, new('A'), W, key, riff, hook)
  sectionB(A, new('B'), W, key, riff)
  sectionC(A, new('C'), W, key)
  sectionD(A, new('D'), W, key, riff, hook)
  M.storm(A, new('storm'), W, key)
  clear(A, new('clear'), W, key, { key = spec.sections.clear.key, songKey = spec.key })
  return S
end })

return M
