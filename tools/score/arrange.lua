-- arrange.lua: the score generator's vocabulary (adaptive-soundtrack design §11.3).
--
-- A section is a table of tracks, each a list of notes {t, len, p, v} in beats (4/4, quarter = 1 beat). The
-- helpers here turn the motifs (eighth-note riff roots, hook strings, chord symbols) into parts: power chords,
-- gallops, tremolo, drum patterns, pads and harmony lines. Everything is deterministic: velocity variation comes
-- from a seeded generator, timing is exactly on the 1/16 grid.
local A = {}

-- Pitches ------------------------------------------------------------------------------------------------------
local letters = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
function A.pitch(name)
  if type(name) == 'number' then return name end
  local l, acc, oct = name:match('^([A-G])([#b]?)(%-?%d)$')
  assert(l, 'bad pitch ' .. tostring(name))
  return 12 * (tonumber(oct) + 1) + letters[l] + (acc == '#' and 1 or acc == 'b' and -1 or 0)
end

A.scales = { minor = { 0, 2, 3, 5, 7, 8, 10 }, major = { 0, 2, 4, 5, 7, 9, 11 } }

-- A key: tonic pitch class and mode ('E minor', 'F major').
function A.key(text)
  local l, acc, mode = text:match('^([A-G])([#b]?) (%a+)$')
  return { tonic = (letters[l] + (acc == '#' and 1 or acc == 'b' and -1 or 0)) % 12, mode = mode }
end

-- In-scale pitch classes of a key (minor also allows the raised 7th: the dominant's leading tone).
function A.scaleSet(key)
  local set = {}
  for _, s in ipairs(A.scales[key.mode]) do set[(key.tonic + s) % 12] = true end
  if key.mode == 'minor' then set[(key.tonic + 11) % 12] = true end
  return set
end

-- The diatonic note `steps` scale steps from pitch p (negative: down). A pitch outside the scale moves by a
-- minor third per two steps instead.
function A.diatonic(p, steps, key)
  local scale = A.scales[key.mode]
  local rel = (p - key.tonic) % 12
  local idx
  for i, s in ipairs(scale) do if s == rel then idx = i end end
  if rel == 11 and key.mode == 'minor' then idx = 7; rel = 10; p = p - 1 end  -- leading tone: harmonise from b7
  if not idx then return p + (steps // 2) * 3 end
  local base = p - rel
  local i = idx - 1 + steps
  local oct = i // 7
  return base + oct * 12 + scale[i % 7 + 1]
end

-- Chords: 'Em', 'C', 'B7', 'Db', 'Bbm', 'C7', 'F'. Returns root pitch class and intervals.
function A.chord(sym)
  local l, acc, q = sym:match('^([A-G])([#b]?)(.*)$')
  local root = (letters[l] + (acc == '#' and 1 or acc == 'b' and -1 or 0)) % 12
  local iv = ({ [''] = { 0, 4, 7 }, m = { 0, 3, 7 }, ['7'] = { 0, 4, 7, 10 }, dim = { 0, 3, 6 }, sus = { 0, 5, 7 } })[q]
  assert(iv, 'bad chord ' .. sym)
  return root, iv
end

-- Chord tones voiced upward from the lowest pitch >= floor (close position, root first).
function A.voicing(sym, floor, count)
  local root, iv = A.chord(sym)
  local base = floor + ((root - floor) % 12)
  local out = {}
  for i = 1, count or #iv do
    local k = (i - 1) % #iv
    out[i] = base + iv[k + 1] + 12 * ((i - 1) // #iv)
  end
  return out
end

-- Root pitch of a chord at or above floor.
function A.root(sym, floor)
  local root = A.chord(sym)
  return floor + ((root - floor) % 12)
end

-- 'Am|G' -> per half bar; 'Db|D|Eb|E' -> per beat. Returns list of {t, len, sym} within one bar.
function A.split(sym)
  local parts = {}
  for s in sym:gmatch('[^|]+') do parts[#parts + 1] = s end
  local len = 4 / #parts
  local out = {}
  for i, s in ipairs(parts) do out[i] = { t = (i - 1) * len, len = len, sym = s } end
  return out
end

-- Melodies: 'B4:1 B4:.5 R:1' (R is a rest) from t0. Returns {t, len, p}.
function A.seq(text, t0)
  local out, t = {}, t0 or 0
  for tok in text:gmatch('%S+') do
    if tok ~= '|' then
      local name, dur = tok:match('^([^:]+):([%d%.]+)$')
      assert(name, 'bad token ' .. tok)
      dur = tonumber(dur)
      if name ~= 'R' then out[#out + 1] = { t = t, len = dur, p = A.pitch(name) } end
      t = t + dur
    end
  end
  return out, t - (t0 or 0)
end

-- Scale degree `deg` (1-based, may exceed 7) of a key in MIDI octave `oct` (the tonic's octave): the
-- campaign theme and its developments are written in degrees so every world sings them in its own key.
function A.degree(key, deg, oct, alter)
  local scale = A.scales[key.mode]
  local i = deg - 1
  return 12 * (oct + 1) + key.tonic + scale[i % 7 + 1] + 12 * (i // 7) + (alter or 0)
end

-- Melodies in degrees: '1:1.5 3:.5 5:1 4:1 7#:2 R:1' (a trailing # or b alters the degree; R is a rest).
function A.line(key, oct, text, t0)
  local out, t = {}, t0 or 0
  for tok in text:gmatch('%S+') do
    local d, acc, dur = tok:match('^(%d*R?)([#b]?):([%d%.]+)$')
    assert(d and d ~= '', 'bad degree token ' .. tok)
    dur = tonumber(dur)
    local alter = acc == '#' and 1 or acc == 'b' and -1 or 0
    -- '7#' is the leading tone: raised in a minor key, already there in a major one.
    if d ~= 'R' and acc == '#' and key.mode == 'major' and tonumber(d) % 7 == 0 then alter = 0 end
    if d ~= 'R' then out[#out + 1] = { t = t, len = dur, p = A.degree(key, tonumber(d), oct, alter) } end
    t = t + dur
  end
  return out, t - (t0 or 0)
end

-- Riff: eighth-note roots, one string per bar ('E2 E2 G2 A2 ...'). Returns rows of 8 pitches.
function A.riff(rows)
  local out = {}
  for b, row in ipairs(rows) do
    out[b] = {}
    for name in row:gmatch('%S+') do out[b][#out[b] + 1] = A.pitch(name) end
    assert(#out[b] == 8, 'riff bar ' .. b .. ' needs 8 eighths')
  end
  return out
end

-- Runs of equal roots in a riff bar: {t, len, p} in beats.
function A.runs(row)
  local out = {}
  for e, p in ipairs(row) do
    local last = out[#out]
    if last and last.p == p then last.len = last.len + 0.5
    else out[#out + 1] = { t = (e - 1) * 0.5, len = 0.5, p = p } end
  end
  return out
end

-- Deterministic variation ---------------------------------------------------------------------------------------
function A.rng(seed)
  local s = seed % 2147483647
  if s <= 0 then s = s + 2147483646 end
  return function(lo, hi)
    s = (s * 16807) % 2147483647
    return lo + (s % (hi - lo + 1))
  end
end

-- Sections ------------------------------------------------------------------------------------------------------
local Section = {}
Section.__index = Section

function A.section(id, bars, seed)
  return setmetatable({ id = id, bars = bars, beats = bars * 4, tracks = {}, jitter = A.rng(seed or 1) }, Section)
end

function Section:note(track, t, len, p, v, humanise)
  local list = self.tracks[track]
  if not list then list = {}; self.tracks[track] = list end
  v = math.floor(v + 0.5)
  if humanise ~= false then v = v + self.jitter(-4, 4) end
  list[#list + 1] = { t = t, len = len, p = A.pitch(p), v = math.max(1, math.min(127, v)) }
end

function Section:chord(track, t, len, pitches, v)
  for i, p in ipairs(pitches) do self:note(track, t, len, p, v - (i - 1) * 3) end
end

-- Power chord on a guitar track: the score carries its root only. The guitar voice (and a power-chord sample in
-- the bank, design §11.10) sounds the fifth, and gtrR also the octave, so a chord costs one voice, not three.
function Section:power(track, t, len, root, v)
  self:note(track, t, len, root, v)
end

function Section:melody(track, notes, v, legato, shift)
  for _, n in ipairs(notes) do self:note(track, n.t, n.len * (legato or 0.95), n.p + (shift or 0), v) end
end

-- A diatonic harmony line `steps` below (or above) a melody.
function Section:harmony(track, notes, v, steps, key, legato)
  for _, n in ipairs(notes) do self:note(track, n.t, n.len * (legato or 0.95), A.diatonic(n.p, steps, key), v) end
end

-- One pad chord per harmony symbol (bar-wise list, symbols may split with |).
function Section:pads(track, harmony, floor, count, v, t0, bars)
  for b = 1, bars or #harmony do
    for _, part in ipairs(A.split(harmony[b])) do
      self:chord(track, (t0 or 0) + (b - 1) * 4 + part.t, part.len - 0.05, A.voicing(part.sym, floor, count), v)
    end
  end
end

-- --- demon-choir: the brood choir's parts (sampled-only tracks, design §3). Drones: the root and fifth of each
-- harmony part (the root alone with `rootOnly`, where the voice budget is tight) from `floor`, bars b0..b1, at velocity v (the bank's vowel axis: <= 84 "oh", above "ah"). Grunts: a
-- shout on every downbeat on the bar's first chord root from `floor` (velocity 120: the hardest syllable), and on
-- beat 3 of every `every`-th bar a softer one (104).
function A.drones(s, track, harmony, floor, v, b0, b1, rootOnly)
  for b = b0, b1 do
    for _, part in ipairs(A.split(harmony[b])) do
      local r = A.root(part.sym, floor)
      s:chord(track, (b - 1) * 4 + part.t, part.len - 0.05, rootOnly and { r } or { r, r + 7 }, v)
    end
  end
end
function A.grunts(s, track, harmony, floor, every)
  for b = 1, #harmony do
    local r = A.root(harmony[b]:match('^[^|]+'), floor)
    s:note(track, (b - 1) * 4, 0.5, r, 120)
    if b % every == 0 then s:note(track, (b - 1) * 4 + 2, 0.5, r, 104) end
  end
end

-- Drums (GM) ----------------------------------------------------------------------------------------------------
A.kit = { kick = 36, snare = 38, rim = 37, hat = 42, pedal = 44, open = 46, crash = 49, crash2 = 57, ride = 51,
  bell = 53, china = 52, splash = 55, tomHi = 50, tomHM = 48, tomLM = 47, tomLo = 45, floorHi = 43, floorLo = 41 }
local kit = A.kit

function Section:hit(track, t, drum, v, len) self:note(track, t, len or 0.25, kit[drum] or drum, v) end

-- A fill over beats [from, 4) of bar b: toms descending in 16ths, the last one a snare.
function Section:fill(track, b, from, v0)
  local toms = { kit.tomHi, kit.tomHi, kit.tomHM, kit.tomHM, kit.tomLM, kit.tomLM, kit.tomLo, kit.floorHi,
    kit.floorHi, kit.floorLo, kit.floorLo, kit.snare }
  local n = math.floor((4 - from) * 4)
  for i = 0, n - 1 do
    local drum = toms[#toms - n + i + 1] or kit.snare
    self:hit(track, (b - 1) * 4 + from + i * 0.25, drum, (v0 or 90) + i * 2)
  end
end

-- A snare roll in 16ths with a velocity ramp.
function Section:roll(track, t0, beats, drum, v0, v1, step)
  step = step or 0.25
  local n = math.floor(beats / step + 0.5)
  for i = 0, n - 1 do
    self:hit(track, t0 + i * step, drum, v0 + (v1 - v0) * i / math.max(1, n - 1), step)
  end
end

-- Per-note tidy-up: sort, clip into the section, and trim overlapping notes of one pitch (an SMF note-off would
-- otherwise cut the next note of the same key).
function Section:tidy(total)
  total = total or self.beats
  for _, list in pairs(self.tracks) do
    table.sort(list, function(a, b) if a.t ~= b.t then return a.t < b.t end; return a.p < b.p end)
    local last = {}
    local keep = {}
    for _, n in ipairs(list) do
      if n.t >= 0 and n.t < total - 1e-9 then
        n.len = math.min(n.len, total - n.t)
        local prev = last[n.p]
        if prev and prev.t + prev.len > n.t then prev.len = n.t - prev.t end
        if prev and prev.t == n.t then prev.dup = true end
        last[n.p] = n
        keep[#keep + 1] = n
      end
    end
    local out = {}
    for _, n in ipairs(keep) do if not n.dup and n.len > 1e-6 then out[#out + 1] = n end end
    for i = #list, 1, -1 do list[i] = nil end
    for i, n in ipairs(out) do list[i] = n end
  end
end

-- Voice rules shared with the web player (demon-score.js): a key struck again on its track chokes the previous
-- note of that key; `mono` roles (lead, bass) sound one note at a time; `pad` roles articulate, ending each chord
-- half a beat before the next one so its release fits (the voice's release tail carries the legato).
A.monoRoles = { lead = true, bass = true }
A.padRoles = { organ = true, strings = true, choir = true, brass = true, brood = true }
A.release = 0.5

function Section:articulate(tracks)
  for name, list in pairs(self.tracks) do
    if A.padRoles[tracks[name].role] then
      for i, n in ipairs(list) do
        for j = i + 1, #list do
          local m = list[j]
          if m.t > n.t + 1e-9 then
            if m.t < n.t + n.len + A.release then n.len = math.max(0.25, m.t - n.t - A.release) end
            break
          end
        end
      end
    end
  end
end

-- When each note stops sounding under the voice rules (its release included): for the gate's voice count.
function A.soundingEnds(list, role)
  local ends = {}
  for i, n in ipairs(list) do
    local e = n.t + n.len + A.release
    for j = i + 1, #list do
      local m = list[j]
      if m.t >= e then break end
      if m.t > n.t + 1e-9 and (m.p == n.p or A.monoRoles[role]) then e = m.t; break end
    end
    ends[i] = e
  end
  return ends
end

-- Standard MIDI File (type 1) -----------------------------------------------------------------------------------
local function vlq(n)
  local bytes = { n & 0x7f }
  n = n >> 7
  while n > 0 do table.insert(bytes, 1, (n & 0x7f) | 0x80); n = n >> 7 end
  return string.char(table.unpack(bytes))
end
local function u32(n) return string.char((n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255) end
local function u16(n) return string.char((n >> 8) & 255, n & 255) end
local function meta(kind, data) return '\255' .. string.char(kind) .. vlq(#data) .. data end
local function chunk(events, endTick)
  table.sort(events, function(a, b)
    if a.tick ~= b.tick then return a.tick < b.tick end
    return a.order < b.order
  end)
  local out, tick = {}, 0
  for _, e in ipairs(events) do
    out[#out + 1] = vlq(e.tick - tick) .. e.data
    tick = e.tick
  end
  out[#out + 1] = vlq(math.max(0, endTick - tick)) .. meta(0x2f, '')
  local body = table.concat(out)
  return 'MTrk' .. u32(#body) .. body
end

-- Key signature: sharps (+) or flats (-) of a key.
local majorSharps = { [0] = 0, [7] = 1, [2] = 2, [9] = 3, [4] = 4, [11] = 5, [6] = 6, [5] = -1, [10] = -2, [3] = -3,
  [8] = -4, [1] = -5 }
function A.keySignature(key)
  local major = key.mode == 'minor' and (key.tonic + 3) % 12 or key.tonic
  return majorSharps[major], key.mode == 'minor' and 1 or 0
end

-- GM programs, for auditions in any MIDI player (the game's voices are chosen by track role).
A.programs = { bass = 34, gtrL = 30, gtrR = 30, clean = 27, lead = 29, lead2 = 29, organ = 19, strings = 48,
  brass = 61, choir = 52, timpani = 47, bells = 14, fanfare = 56, uke = 24, brood = 53 }

-- Writes the section as SMF type 1: a conductor track (tempo, 4/4, key, section marker), then one track per
-- part in `order`, named by role. `total` beats is the file length (bars plus any hold bars).
function A.smf(section, opts)
  local ppq = opts.ppq
  local tick = function(beats) return math.floor(beats * ppq + 0.5) end
  local endTick = tick(opts.total)
  local tempo = math.floor(opts.barSamples / 48000 / 4 * 1e6 + 0.5)
  local sf, mi = A.keySignature(opts.key)
  local cond = {
    { tick = 0, order = 0, data = meta(0x03, opts.title) },
    { tick = 0, order = 1, data = meta(0x51, string.char((tempo >> 16) & 255, (tempo >> 8) & 255, tempo & 255)) },
    { tick = 0, order = 2, data = meta(0x58, string.char(4, 2, 24, 8)) },
    { tick = 0, order = 3, data = meta(0x59, string.char(sf & 255, mi)) },
    { tick = 0, order = 4, data = meta(0x06, section.id) },
  }
  if opts.hold and opts.hold > 0 then
    cond[#cond + 1] = { tick = tick(section.beats), order = 5, data = meta(0x06, 'hold') }
  end
  local chunks = { chunk(cond, endTick) }
  local names = {}
  for _, name in ipairs(opts.order) do if section.tracks[name] and #section.tracks[name] > 0 then names[#names + 1] = name end end
  for _, name in ipairs(names) do
    local ch = opts.tracks[name].channel
    local events = { { tick = 0, order = 0, data = meta(0x03, name) } }
    if ch ~= 9 and A.programs[name] then
      events[#events + 1] = { tick = 0, order = 1, data = string.char(0xC0 | ch, A.programs[name]) }
    end
    for _, n in ipairs(section.tracks[name]) do
      local on, off = tick(n.t), tick(n.t + n.len)
      if off <= on then off = on + 1 end
      events[#events + 1] = { tick = on, order = 3, data = string.char(0x90 | ch, n.p, n.v) }
      events[#events + 1] = { tick = off, order = 2, data = string.char(0x80 | ch, n.p, 0) }
    end
    chunks[#chunks + 1] = chunk(events, endTick)
  end
  return 'MThd' .. u32(6) .. u16(1) .. u16(#chunks) .. u16(ppq) .. table.concat(chunks), names
end

return A
