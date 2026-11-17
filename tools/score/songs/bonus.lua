-- The bonus songs (form `bonus`): a bonus level's own small song, which SongDirector plays for the whole level in
-- place of the sector's waves (song-map.json `bonusSongs`: the bonus level's id -> its song). The level clear hands
-- back to the sector song's own `clear`, so the travel and its bridge play as before.
--
-- `bonus-wind` ("Crosswind", the wind bonus level): E minor, 160 BPM on Ringfall's grid (72 000 samples a bar), in
-- a shuffle: every eighth is swung onto the triplet grid (on the beat and on its last third), so the band drives
-- like Krybor's punk but rolls. Original writing from the game's own motifs: the campaign theme (degrees 1-3-5-4,
-- rhythm 1.5/.5/1/1, art/music/campaign.json) swung into 5/3 + 1/3 + 1 + 1 and sung over Krybor's harmony; the
-- second section lifts into the relative major (G-D-Em-C) and calls the theme's head from the third degree, the
-- bells answering. Airy parts: clean guitar in swung arpeggios, high strings, glockenspiel-range bells; the battle
-- metal stays in the shuffled power chords, the gallop of the double kick in triplets and the brass stabs.
--
--   A  "Tailwind"  (loop, 8 bars): the shuffle riff, the theme swung on lead (thirds below on lead2), clean
--                  arpeggios, high strings; triplet tom fill into the loop.
--   B  "Crosswind" (loop, 8 bars): the lift: triplet chug, ride on the swung eighths, the theme's head called from
--                  the third degree and climbing to the ninth, bells answering, brass stabs pushing each bar,
--                  choir on top at tier 4.
--
-- Clean guitar stays at or under E5 and the bells under F5 so the round-1 bank plays them (design §12.10).
local T = 1 / 3

-- A swung line in degrees: 'deg:thirds' tokens (3 = one beat; R rests; a trailing # or b alters the degree).
local function swing(A, key, oct, text, t0)
  local out, k = {}, 0
  for tok in text:gmatch('%S+') do
    local d, acc, n = tok:match('^(%d*R?)([#b]?):(%d+)$')
    assert(d and d ~= '', 'bad swing token ' .. tok)
    n = tonumber(n)
    if d ~= 'R' then
      local alter = acc == '#' and 1 or acc == 'b' and -1 or 0
      if acc == '#' and key.mode == 'major' and tonumber(d) % 7 == 0 then alter = 0 end
      out[#out + 1] = { t = (t0 or 0) + k * T, len = n * T, p = A.degree(key, tonumber(d), oct, alter) }
    end
    k = k + n
  end
  assert(k % 12 == 0, 'a swung line fills whole bars')
  return out
end

-- The campaign theme, swung (bars 1-4 the call, 5-8 the answer).
local THEME_CALL = '1:5 3:1 5:3 4:3 3:6 2:3 1:3 8:5 7:1 6:3 5:3 4:6 2:6'
local THEME_ANSWER = '1:5 3:1 5:3 4:3 5:3 7:3 8:6 8:3 7:3 6:3 5:3 5:6 7#:6'
-- B: the theme's head from the third degree (the relative major), climbing.
local LIFT = '3:5 5:1 7:3 6:3 5:9 R:3 1:5 3:1 5:3 4:3 3:9 R:3 3:5 5:1 7:3 6:3 9:6 11:6 10:5 9:1 8:3 7:3 7#:12'

local CH_A = { 'Em', 'C', 'G', 'D', 'Em', 'C', 'Am', 'B' }
local CH_B = { 'G', 'D', 'Em', 'C', 'G', 'D', 'C', 'B' }

-- Shared parts --------------------------------------------------------------------------------------------------
-- The shuffle: a power chord on each beat and a palm-muted one on its last third; the bass walks root, root,
-- fifth, octave on the same swing.
local function shuffle(A, s, ch, gallop)
  local P = A.pitch
  for b, sym in ipairs(ch) do
    local t, r = (b - 1) * 4, A.root(sym, P('E2'))
    if r > P('B2') then r = r - 12 end
    for beat = 0, 3 do
      local on = t + beat
      local new = beat == 0 or beat == 2
      s:power('gtrL', on, 0.6, r, new and 112 or 98)
      s:power('gtrR', on, 0.6, r, new and 108 or 94)
      if gallop then
        s:power('gtrL', on + T, 0.26, r, 82); s:power('gtrR', on + T, 0.26, r, 78)
      end
      s:power('gtrL', on + 2 * T, 0.28, r, gallop and 90 or 84)
      s:power('gtrR', on + 2 * T, 0.28, r, gallop and 86 or 80)
      local walk = ({ 0, 0, 7, 12 })[beat + 1]
      s:note('bass', on, 0.6, r - 12 + walk, new and 108 or 100)
      s:note('bass', on + 2 * T, 0.28, r - 12 + walk, 90)
    end
  end
end

-- The swung kit: kick, snare on 2 and 4 with a ghost before 4, hats on the swung eighths; a triplet tom fill over
-- the last two beats of bar 8.
local function kit(s, bars, drive)
  for b = 1, bars do
    local t = (b - 1) * 4
    local fill = b == bars
    s:hit('drums', t, 'kick', 112)
    s:hit('drums', t + 1 + 2 * T, 'kick', 90)
    s:hit('drums', t + 2, 'kick', 106)
    if drive then s:hit('drums', t + 1, 'kick', 96); s:hit('drums', t + 3, 'kick', 98) end
    if not fill or drive then s:hit('drums', t + 3 + 2 * T, 'kick', 86) end
    s:hit('drums', t + 1, 'snare', 112)
    if not fill then
      s:hit('drums', t + 2 + 2 * T, 'snare', 52)
      s:hit('drums', t + 3, 'snare', 114)
    end
    for beat = 0, fill and 1 or 3 do
      s:hit('drums', t + beat, 'hat', drive and 76 or 84, T)
      s:hit('drums', t + beat + 2 * T, 'hat', drive and 58 or 64, T)
    end
    if fill then
      local toms = { 'tomHi', 'tomHi', 'tomHM', 'tomLM', 'floorHi', 'floorLo' }
      for i, drum in ipairs(toms) do s:hit('drums', t + 2 + (i - 1) * T, drum, 90 + i * 4, T) end
    end
  end
end

-- Clean guitar: swung arpeggios of the chord, close above B3 (never above E5).
local function breeze(A, s, ch, v)
  local P = A.pitch
  for b, sym in ipairs(ch) do
    local t, tones = (b - 1) * 4, A.voicing(sym, P('B3'), 3)
    local order = { 1, 2, 3, 2, 1, 2, 3, 2 }
    for e = 0, 7 do
      local on = t + (e // 2) + (e % 2 == 1 and 2 * T or 0)
      s:note('clean', on, e % 2 == 0 and 0.5 or 0.3, tones[order[e + 1]], (e % 2 == 0 and v or v - 10))
    end
  end
end

local function sectionA(A, s, key)
  local P = A.pitch
  shuffle(A, s, CH_A, false)
  kit(s, 8, false)
  for b = 1, 8 do
    local t = (b - 1) * 4
    if b == 1 or b == 5 then s:hit('cymbals', t, b == 1 and 'crash' or 'crash2', b == 1 and 110 or 98, 2) end
    for beat = 0, 3 do
      if not ((b == 1 or b == 5) and beat == 0) then s:hit('cymbals', t + beat, 'ride', 80, T) end
      s:hit('cymbals', t + beat + 2 * T, 'ride', 64, T)
    end
  end
  -- The double kick gallops in triplets under the last half of every second bar.
  for b = 2, 8, 2 do for k = 0, 5 do s:hit('drums2', (b - 1) * 4 + 2 + k * T, 'kick', k % 3 == 0 and 84 or 74, T) end end
  local theme = swing(A, key, 4, THEME_CALL .. ' ' .. THEME_ANSWER)
  s:melody('lead', theme, 104, 0.95)
  s:harmony('lead2', theme, 90, -2, key, 0.95)
  breeze(A, s, CH_A, 64)
  s:pads('strings', CH_A, P('G4'), 3, 52)
  s:note('bells', 0, 3, A.degree(key, 1, 5), 74); s:note('bells', 16, 3, A.degree(key, 1, 5), 70)
  s:note('bells', 12, 2, A.degree(key, 5, 4), 64); s:note('bells', 28, 2, A.degree(key, 7, 4, 1), 66)
  s:note('timpani', 0, 1.5, P('E2'), 102); s:note('timpani', 16, 1.5, P('E2'), 96)
  s:roll('timpani', 30, 2, P('B1'), 52, 96)
end

local function sectionB(A, s, key)
  local P = A.pitch
  shuffle(A, s, CH_B, true)
  kit(s, 8, true)
  for b = 1, 8 do
    local t = (b - 1) * 4
    if b % 2 == 1 then s:hit('cymbals', t, b == 1 and 'crash' or 'crash2', b == 1 and 112 or 100, 2) end
    for beat = 0, 3 do
      if not (b % 2 == 1 and beat == 0) then s:hit('cymbals', t + beat, 'ride', 84, T) end
      s:hit('cymbals', t + beat + 2 * T, 'ride', 68, T)
    end
  end
  for b = 1, 8 do for k = 0, 5 do s:hit('drums2', (b - 1) * 4 + 2 + k * T, 'kick', k % 3 == 0 and 86 or 76, T) end end
  local lift = swing(A, key, 4, LIFT)
  s:melody('lead', lift, 108, 0.95)
  s:harmony('lead2', lift, 94, -2, key, 0.95)
  breeze(A, s, CH_B, 60)
  s:pads('strings', CH_B, P('A4'), 3, 54)
  s:pads('choir', CH_B, P('E4'), 3, 50)
  -- Brass stabs push each bar: the next chord on the swung "and" of 4.
  for b = 1, 8 do
    local nxt = CH_B[b % 8 + 1]
    s:chord('brass', (b - 1) * 4 + 3 + 2 * T, 0.3, A.voicing(nxt, P('D3'), 3), 94)
  end
  -- Bells answer each call (bars 2, 4, 6) and ring the dominant's leading tone into the loop.
  s:note('bells', 4, 2, A.degree(key, 5, 4), 70); s:note('bells', 6, 2, A.degree(key, 3, 4), 64)
  s:note('bells', 12, 2, A.degree(key, 5, 4), 70); s:note('bells', 14, 2, A.degree(key, 1, 5), 66)
  s:note('bells', 20, 2, A.degree(key, 7, 4), 70); s:note('bells', 22, 2, A.degree(key, 2, 5), 66)
  s:note('bells', 28, 3, A.degree(key, 7, 4, 1), 72)
  s:note('timpani', 0, 1, P('G2'), 100); s:note('timpani', 16, 1, P('G2'), 96)
  s:roll('timpani', 29, 3, P('B1'), 50, 100)
end

local songs = {
  ['bonus-wind'] = function(A, spec, seed)
    local key = A.key(spec.key)
    local S = {}
    S.A = A.section('A', spec.sections.A.bars, seed + 4111)
    sectionA(A, S.A, key)
    S.B = A.section('B', spec.sections.B.bars, seed + 4127)
    sectionB(A, S.B, key)
    return S
  end,
}

return function(A, spec, seed, songId)
  return assert(songs[songId], 'no bonus song ' .. tostring(songId))(A, spec, seed)
end
