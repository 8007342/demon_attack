-- The carrier, tours 2-5 (sector 5 of routes 2-5): F minor, 190 BPM, the same band and the same motifs as tour 1
-- (songs/carrier.lua: the riff and the hook of tools/music_motifs.py MOTIFS[5], the campaign theme of
-- art/music/campaign.json), escalating tour by tour, because the fights are the choruses (design §3.1). Each tour
-- has one hatch section per upper tier (U = 2, 3, 3, 4: lib/game/carrier_hatches.dart `_rows`), climbing a ladder
-- of figures (gallop, thrash skank, tremolo into blasts, full blast, doom march) with its own lead writing (the hook
-- answered by the theme, in sixths, in octaves, augmented, in canon, the choir chanting the theme). The fifth tour's
-- victory opens into the F major finale and the worldized bridge into the coda (design §4.4).
return function(A, spec, seed)
  local tour = spec.tour
  local key = A.key(spec.key)
  local major = A.key('F major')
  local P = A.pitch

  local riff = A.riff({
    'F2 F2 F2 F2 Gb2 Gb2 E2 E2', 'F2 F2 F2 F2 F2 F2 B1 B1',
    'Db2 Db2 Db2 Db2 C2 C2 C2 C2', 'Gb2 Gb2 Gb2 Gb2 F2 F2 F2 F2',
    'F2 F2 F2 F2 Gb2 Gb2 E2 E2', 'F2 F2 F2 F2 F2 F2 B1 B1',
    'Db2 Db2 D2 D2 Eb2 Eb2 E2 E2', 'F2 F2 F2 F2 B1 B1 B1 B1',
  })
  local harmony = { 'Fm', 'Fm', 'Db|C', 'Gb|Fm', 'Fm', 'Fm', 'Db|Eb', 'Fm' }
  local hook = A.seq('F5:2 Gb5:1 E5:1 F5:3 B4:1 Db5:2 C5:2 Gb5:2 F5:2 Ab5:2 G5:1 Gb5:1 F5:3 B5:1 '
    .. 'Db6:1 D6:1 Eb6:1 E6:1 F6:2 B5:2')
  -- The campaign theme in F minor (Krybor's B-section shape in degrees), 8 bars.
  local theme = A.line(key, 4, '1:1.5 3:.5 5:1 4:1 3:2 2:1 1:1 8:1.5 7:.5 6:1 5:1 4:2 2:2 '
    .. '1:1.5 3:.5 5:1 4:1 5:1 7:1 8:2 8:1 7:1 6:1 5:1 5:2 7#:2')

  local S = {}
  local function new(id)
    local s = A.section(id, spec.sections[id].bars, seed + tour * 1009 + #id * 131 + id:byte(1))
    S[id] = s
    return s
  end
  local function first(sym) return sym:match('^[^|]+') end
  local function shift(notes, by) local out = {} for i, n in ipairs(notes) do out[i] = { t = n.t, len = n.len, p = n.p + by } end return out end
  local function stretch(notes, factor, upto)
    local out = {}
    for _, n in ipairs(notes) do if n.t * factor < upto then out[#out + 1] = { t = n.t * factor, len = n.len * factor, p = n.p } end end
    return out
  end
  -- A canon voice: the line delayed by `beats`, wrapped inside the loop.
  local function canon(notes, beats, total)
    local out = {}
    for _, n in ipairs(notes) do out[#out + 1] = { t = (n.t + beats) % total, len = math.min(n.len, total - (n.t + beats) % total), p = n.p } end
    return out
  end

  -- Drums ---------------------------------------------------------------------------------------------------
  local function hats(s, b, step, v, drum)
    for i = 0, 4 / step - 1 do s:hit('drums', (b - 1) * 4 + i * step, drum or 'hat', i % 2 == 0 and v or v - 16, step) end
  end
  local function crashes(s, bars, every, rideStep, china)
    for b = 1, bars do
      local t = (b - 1) * 4
      if (b - 1) % every == 0 then s:hit('cymbals', t, b % 2 == 1 and 'crash' or 'crash2', 110, 2) end
      if rideStep then
        for i = 0, 4 / rideStep - 1 do
          if not ((b - 1) % every == 0 and i == 0) then s:hit('cymbals', t + i * rideStep, 'ride', i % 2 == 0 and 82 or 68, rideStep) end
        end
      end
      if china and b % 4 == 0 then s:hit('cymbals', t + 2, 'china', 100, 1) end
    end
  end
  local function doubleKick(s, from, to, v)
    for b = from, to do for i = 0, 15 do s:hit('drums2', (b - 1) * 4 + i * 0.25, 'kick', (v or 80) + (i % 4 == 0 and 8 or 0)) end end
  end
  local function blast(s, b, fill, half)
    local t = (b - 1) * 4
    for e = 0, 7 do
      if not (fill and e >= 6) and not (half and e >= 4) then
        s:hit('drums', t + e * 0.5, 'kick', e % 2 == 0 and 110 or 100)
        s:hit('drums', t + e * 0.5 + 0.25, 'snare', e % 2 == 0 and 104 or 96)
      end
    end
    if half then s:hit('drums', t + 2, 'kick', 114); s:hit('drums', t + 3, 'snare', 118) end
    hats(s, b, 0.5, 80)
    if fill then s:fill('drums', b, 3, 98) end
  end
  local function skankDrums(s, b, fill)
    local t = (b - 1) * 4
    for e = 0, 7 do
      if not (fill and e >= 6) then
        if e % 2 == 0 then s:hit('drums', t + e * 0.5, 'kick', 110) else s:hit('drums', t + e * 0.5, 'snare', 108) end
      end
    end
    hats(s, b, 0.5, 80)
    if fill then s:fill('drums', b, 3, 96) end
  end
  local function gallopDrums(s, b, fill)
    local t = (b - 1) * 4
    for beat = 0, 3 do
      if not (fill and beat == 3) then for i, off in ipairs({ 0, 0.5, 0.75 }) do s:hit('drums', t + beat + off, 'kick', i == 1 and 110 or 94) end end
    end
    s:hit('drums', t + 1, 'snare', 114)
    if not fill then s:hit('drums', t + 3, 'snare', 116) else s:fill('drums', b, 3, 96) end
    hats(s, b, 0.5, 82)
  end
  local function doomDrums(s, b, fill)
    local t = (b - 1) * 4
    s:hit('drums', t, 'kick', 116); s:hit('drums', t + 2, 'snare', 116)
    if b % 2 == 0 then s:hit('drums', t + 2.5, 'kick', 98) end
    if fill then s:fill('drums', b, 3, 92) else hats(s, b, 1, 80) end
  end

  -- Guitars and bass ----------------------------------------------------------------------------------------
  local function gallop(s)
    for b, row in ipairs(riff) do
      for beat = 0, 3 do
        local root = row[beat * 2 + 1]
        local t = (b - 1) * 4 + beat
        local new1 = beat == 0 or row[beat * 2 - 1] ~= root
        for i, off in ipairs({ 0, 0.5, 0.75 }) do
          local v = i == 1 and (new1 and 114 or 96) or 86
          s:power('gtrL', t + off, i == 1 and 0.45 or 0.22, root, v)
          s:power('gtrR', t + off, i == 1 and 0.45 or 0.22, root, v - 4)
          s:note('bass', t + off, i == 1 and 0.45 or 0.22, root - 12, i == 1 and 110 or 98)
        end
      end
    end
  end
  local function chug(s)
    for b, row in ipairs(riff) do
      for e, root in ipairs(row) do
        local t = (b - 1) * 4 + (e - 1) * 0.5
        local change = e == 1 or row[e - 1] ~= root
        s:power('gtrL', t, change and 0.48 or 0.4, root, change and 116 or 90)
        s:power('gtrR', t, change and 0.48 or 0.4, root, change and 112 or 86)
        s:note('bass', t, 0.45, root - 12, change and 112 or 100)
      end
    end
  end
  local function tremolo(s, vL, bars)
    for b, row in ipairs(riff) do
      if not bars or bars[b] then
        for e, root in ipairs(row) do
          local change = e == 1 or row[e - 1] ~= root
          for k = 0, 1 do
            local t = (b - 1) * 4 + (e - 1) * 0.5 + k * 0.25
            local v = (change and k == 0) and vL + 14 or vL
            s:power('gtrL', t, 0.22, root, v)
            s:power('gtrR', t, 0.22, root, v - 4)
          end
          s:note('bass', (b - 1) * 4 + (e - 1) * 0.5, 0.45, root - 12, change and 112 or 100)
        end
      end
    end
  end
  local function doomRuns(s, v)
    for b, row in ipairs(riff) do
      for i, run in ipairs(A.runs(row)) do
        local t = (b - 1) * 4 + run.t
        s:power('gtrL', t, run.len - 0.06, run.p, i == 1 and v or v - 10)
        s:power('gtrR', t, run.len - 0.06, run.p, i == 1 and v - 4 or v - 14)
        s:note('bass', t, run.len - 0.06, run.p - 12, i == 1 and v or v - 10)
      end
    end
  end

  -- Hatch figures, a ladder from the first tier to the last -----------------------------------------------------
  local figures = {
    gallop = function(s) gallop(s); for b = 1, 8 do gallopDrums(s, b, b == 8) end; crashes(s, 8, 4, 1, true); doubleKick(s, 1, 8, 76) end,
    skank = function(s) chug(s); for b = 1, 8 do skankDrums(s, b, b % 4 == 0) end; crashes(s, 8, 2, 0.5, true); doubleKick(s, 1, 8, 78) end,
    tremolo = function(s)
      tremolo(s, 94)
      for b = 1, 8 do if b <= 4 then skankDrums(s, b, false) else blast(s, b, b == 8) end end
      crashes(s, 8, 2, 0.5, true); doubleKick(s, 1, 8, 80)
    end,
    blast = function(s) tremolo(s, 98); for b = 1, 8 do blast(s, b, b % 4 == 0) end; crashes(s, 8, 1, nil, true); doubleKick(s, 1, 8, 84) end,
    march = function(s) doomRuns(s, 118); for b = 1, 8 do doomDrums(s, b, b % 4 == 0) end; crashes(s, 8, 2, 1); doubleKick(s, 1, 8, 82) end,
    gallopBlast = function(s)
      local odd, even = {}, {}
      for b = 1, 8 do if b % 2 == 1 then odd[b] = true else even[b] = true end end
      local g = A.section('g', 8, 1)
      gallop(g)
      for name, list in pairs(g.tracks) do
        for _, n in ipairs(list) do if odd[n.t // 4 + 1] then s:note(name, n.t, n.len, n.p, n.v, false) end end
      end
      tremolo(s, 96, even)
      for b = 1, 8 do if b % 2 == 1 then gallopDrums(s, b, false) else blast(s, b, b == 8) end end
      crashes(s, 8, 2, 0.5, true); doubleKick(s, 1, 8, 82)
    end,
  }
  local ladder = ({
    [2] = { 'skank', 'blast' },
    [3] = { 'gallop', 'skank', 'blast' },
    [4] = { 'march', 'gallopBlast', 'blast' },
    [5] = { 'gallop', 'skank', 'tremolo', 'blast' },
  })[tour]
  local leads = ({
    [2] = { 'hookTheme', 'hookSixths' },
    [3] = { 'hookOctaves', 'themeHookBrass', 'hookUp' },
    [4] = { 'hookAugmented', 'hookVsTheme', 'canon' },
    [5] = { 'hook', 'hookTheme', 'hookThirds', 'choirTheme' },
  })[tour]
  local low = shift(hook, -12)
  local function leadParts(s, kind)
    if kind == 'hook' then s:melody('lead', low, 104); s:harmony('lead2', low, 94, -2, key)
    elseif kind == 'hookTheme' then
      local a = {}
      for _, n in ipairs(low) do if n.t < 16 then a[#a + 1] = n end end
      local b = {}
      for _, n in ipairs(theme) do if n.t >= 16 then b[#b + 1] = { t = n.t, len = n.len, p = n.p + 12 } end end
      s:melody('lead', a, 106); s:melody('lead', b, 104, 0.97)
      s:harmony('lead2', a, 94, -2, key); s:harmony('lead2', b, 92, -2, key, 0.97)
    elseif kind == 'hookSixths' then s:melody('lead', hook, 108); s:harmony('lead2', hook, 96, -5, key)
    elseif kind == 'hookOctaves' then s:melody('lead', low, 106); s:melody('lead2', hook, 96)
    elseif kind == 'themeHookBrass' then
      local th = shift(theme, 12)
      s:melody('lead', th, 106, 0.97); s:harmony('lead2', th, 94, -2, key, 0.97); s:melody('brass', shift(hook, -24), 90, 0.9)
    elseif kind == 'hookUp' then s:melody('lead', hook, 110); s:harmony('lead2', hook, 100, -2, key)
    elseif kind == 'hookAugmented' then
      local aug = stretch(low, 2, 32)
      s:melody('lead', aug, 104, 0.98); s:harmony('lead2', aug, 92, -2, key, 0.98)
    elseif kind == 'hookVsTheme' then s:melody('lead', low, 106); s:melody('lead2', theme, 92, 0.97)
    elseif kind == 'canon' then s:melody('lead', hook, 110); s:melody('lead2', canon(low, 4, 32), 98)
    elseif kind == 'hookThirds' then s:melody('lead', hook, 108); s:harmony('lead2', hook, 98, -2, key)
    elseif kind == 'choirTheme' then
      s:melody('lead', hook, 110); s:harmony('lead2', hook, 100, -2, key)
      s:melody('brass', shift(hook, -24), 92, 0.9)
    end
  end
  local function pads(s, k, kind, n)
    s:pads('organ', harmony, P('F3'), 3, 62 + k * 2)
    if kind == 'choirTheme' then s:melody('choir', theme, 78, 0.98)
    else s:pads('choir', k == 1 and { 'Fm', 'Fm', 'Db|Eb', 'Fm' } or harmony, P('F4'), 3, 62 + k * 2, k == 1 and 16 or 0) end
    s:pads('strings', harmony, P(k % 2 == 1 and 'Ab3' or 'C4'), 3, 52 + k)
    if kind ~= 'themeHookBrass' and kind ~= 'choirTheme' then
      for b = 1, 8, (k == n and 1 or 2) do s:chord('brass', (b - 1) * 4, k == n and 1.8 or 1, A.voicing(first(harmony[b]), P('F3'), 3), 96 + k * 2) end
    end
    for b = 1, 8, 2 do s:note('timpani', (b - 1) * 4, 1.2, b % 4 == 1 and 'F2' or 'C2', 104 + k) end
    s:note('bells', 0, 3, 'F5', 78); s:note('bells', 16, 3, k % 2 == 0 and 'C6' or 'Ab5', 74)
  end

  -- arrival (4 bars): the fog, closer each tour -----------------------------------------------------------------
  do
    local s = new('arrival')
    s:chord('organ', 0, 15.9, { P('F2'), P('C3') }, 70)
    s:pads('organ', { 'Fm', 'Fm', 'Db', 'C' }, P('F3'), 3, 58)
    for b = 1, 4 do
      s:note('bells', (b - 1) * 4, 3.5, 'F4', 96); s:note('bells', (b - 1) * 4, 3.5, tour >= 2 and 'C5' or 'F5', 72)
      if tour >= 4 then s:note('bells', (b - 1) * 4 + 2, 1.5, 'F4', 84) end
    end
    s:roll('timpani', 0, 12, P('F2'), 34 + tour * 2, 80, 0.5)
    s:power('gtrL', 4, 7.8, P('F2'), 72); s:power('gtrR', 4, 7.8, P('F2'), 68)
    s:chord('brass', 8, 3.9, A.voicing('Db', P('F3'), 3), 78)
    s:chord('brass', 12, 3.9, A.voicing('C', P('E3'), 3), 92)
    s:note('bass', 4, 3.9, 'F1', 90); s:note('bass', 8, 3.9, 'Db1', 96); s:note('bass', 12, 3.9, 'C1', 104)
    if tour == 2 then s:melody('lead', A.seq('F3:2 Gb3:1 E3:1', 4), 86, 0.98) end
    if tour == 3 or tour == 5 then s:melody('choir', A.line(key, 4, '1:1.5 3:.5 5:1 4:1 3:2 2:1 1:1', 0), 70, 0.98)
    else s:pads('choir', { 'Db', 'C' }, P('F4'), 3, 60, 8) end
    if tour >= 4 then s:chord('organ', 0, 7.9, { P('Gb3') }, 52) end
    if tour == 5 then s:pads('strings', { 'Fm', 'Fm', 'Db', 'C' }, P('Ab3'), 3, 54) end
    s:hit('drums', 8, 'kick', 104); s:hit('drums', 10, 'snare', 96)
    s:hit('drums', 12, 'kick', 112); s:hit('cymbals', 12, 'crash', 100, 2)
    if tour >= 4 then for i = 0, 15 do s:hit('drums2', 12 + i * 0.25, 'kick', 60 + i * 3) end end
    s:roll('drums', 13, 3, 'snare', 46, 118)
    s:roll('timpani', 12, 4, P('C2'), 70, 112)
  end

  -- approach (8 bars loop) ----------------------------------------------------------------------------------
  do
    local s = new('approach')
    for b, row in ipairs(riff) do
      for i, run in ipairs(A.runs(row)) do
        local t = (b - 1) * 4 + run.t
        local v = i == 1 and 114 or 104
        s:power('gtrL', t, run.len - 0.06, run.p, v)
        s:power('gtrR', t, run.len - 0.06, run.p, v - 4)
        s:note('bass', t, run.len - 0.06, run.p - 12, v)
      end
      local t = (b - 1) * 4
      if tour == 5 and b >= 7 then blast(s, b, b == 8)
      else
        s:hit('drums', t, 'kick', 116); s:hit('drums', t + 2, 'snare', 116)
        if tour == 3 then for _, off in ipairs({ 0.5, 0.75, 2.5, 2.75 }) do s:hit('drums', t + off, 'kick', 94) end
        elseif b % 2 == 0 then s:hit('drums', t + 2.5, 'kick', 98) end
        if b % 4 ~= 0 then hats(s, b, tour == 2 and 0.5 or 1, 80) else s:fill('drums', b, 3, 90) end
      end
      s:note('bells', t, 3.5, 'F4', 98); s:note('bells', t, 3.5, 'C5', 66)
    end
    crashes(s, 8, 2, tour == 2 and 0.5 or 1)
    if tour == 4 then for b = 2, 8, 2 do doubleKick(s, b, b, 82) end
    else for b = 4, 8, 4 do for i = 8, 15 do s:hit('drums2', (b - 1) * 4 + i * 0.25, 'kick', 84) end end end
    local line = A.seq('F4:4 Ab4:2 G4:2 C5:4 Bb4:2 Ab4:2 F4:4 G4:2 Ab4:2 Db5:2 Eb5:2 C5:4')
    if tour == 3 then line = A.seq('C5:4 Bb4:2 Ab4:2 G4:4 Ab4:2 Bb4:2 C5:4 Db5:2 C5:2 Bb4:2 G4:2 E4:4') end
    s:melody('lead', line, 98, 0.98)
    s:harmony('lead2', line, 86, -2, key, 0.98)
    s:pads('organ', harmony, P('F3'), 3, 64)
    if tour == 2 then s:melody('brass', theme, 84, 0.96)
    else for b = 1, 8 do s:chord('brass', (b - 1) * 4, 3.9, { P('F2'), P('C3') }, 72 + tour) end end
    s:pads('choir', harmony, P('F4'), 3, tour >= 4 and 68 or 60)
    s:pads('strings', harmony, P('C4'), 3, 50)
    for _, b in ipairs({ 1, 5 }) do s:note('timpani', (b - 1) * 4, 1.5, 'F2', 106) end
    s:roll('timpani', 30, 2, P('C2'), 60, 100)
  end

  -- The hatch sections ----------------------------------------------------------------------------------------
  local n = #ladder
  for k = 1, n do
    local s = new('H' .. k)
    figures[ladder[k]](s)
    leadParts(s, leads[k])
    pads(s, k, leads[k], n)
  end

  -- transform (3 bars, into the core's downbeat) ----------------------------------------------------------------
  do
    local s = new('transform')
    s:chord('organ', 0, 3.95, A.voicing('Db', P('Db3'), 4), 72); s:chord('organ', 0, 3.95, { P('Db2') }, 76)
    s:chord('choir', 0, 3.95, A.voicing('Db', P(tour >= 2 and 'Ab4' or 'F4'), 3), 64 + tour)
    s:chord('organ', 4, 3.95, A.voicing('Eb', P('Eb3'), 4), 84); s:chord('organ', 4, 3.95, { P('Eb2') }, 86)
    s:chord('choir', 4, 3.95, A.voicing('Eb', P(tour >= 2 and 'Bb4' or 'G4'), 3), 78 + tour)
    s:chord('organ', 8, 3.95, A.voicing('C7', P('C3'), 4), 98); s:chord('organ', 8, 3.95, { P('C2') }, 98)
    s:chord('choir', 8, 3.95, A.voicing('C', P(tour >= 3 and 'G4' or 'E4'), 3), 92 + tour)
    s:chord('strings', 0, 7.9, A.voicing('Db', P('Ab3'), 3), 58); s:chord('strings', 8, 3.95, A.voicing('C', P('G3'), 4), 86)
    for k = 0, 15 do
      s:power('gtrL', k * 0.25, 0.22, P('Db2'), 70 + k); s:power('gtrR', k * 0.25, 0.22, P('Db2'), 66 + k)
      s:power('gtrL', 4 + k * 0.25, 0.22, P('Eb2'), 86 + k); s:power('gtrR', 4 + k * 0.25, 0.22, P('Eb2'), 82 + k)
    end
    s:note('bass', 0, 3.95, 'Db1', 96); s:note('bass', 4, 3.95, 'Eb1', 104)
    local climb = { 'Db2', 'D2', 'Eb2', 'E2' }
    for i, note in ipairs(climb) do
      local t = 8 + (i - 1)
      s:power('gtrL', t, 0.9, P(note), 118); s:power('gtrR', t, 0.9, P(note), 114)
      s:note('bass', t, 0.9, P(note) - 12, 116)
      s:chord('brass', t, 0.9, { P(note) + 12, P(note) + 19 }, 104 + i * 3)
      s:note('lead', t, 0.95, P(note) + 36, 104 + i * 3)
      if tour >= 4 then s:note('lead2', t, 0.95, P(note) + 24, 98 + i * 3) end
      if tour >= 3 then s:note('bells', t, 0.95, P(note) + 48, 80 + i * 4) end
      s:hit('drums', t, 'kick', 118); s:hit('cymbals', t, i == 1 and 'crash' or 'crash2', 96 + i * 6, 1)
    end
    s:hit('drums', 0, 'kick', 108); s:hit('cymbals', 0, 'crash', 100, 3)
    s:roll('timpani', 0, 8, P('F2'), 44, 96)
    s:roll('timpani', 8, 4, P('C2'), 98, 124)
    s:roll('drums', 5, 3, 'snare', 54, 104)
    s:roll('drums', 8, 3, 'snare', 104, 122)
    s:fill('drums', 3, 3, 104)
    if tour == 5 then for i = 0, 15 do s:hit('drums2', 8 + i * 0.25, 'kick', 70 + i * 3) end end
  end

  -- core (8 bars loop): the climax ----------------------------------------------------------------------------
  do
    local s = new('core')
    tremolo(s, 98)
    for b = 1, 8 do blast(s, b, b % 4 == 0, tour == 4 and b % 2 == 0) end
    crashes(s, 8, 1, nil, true)
    for b = 1, 8 do for i = 1, 7 do s:hit('cymbals', (b - 1) * 4 + i * 0.5, 'ride', i % 2 == 0 and 84 or 70, 0.5) end end
    doubleKick(s, 1, 8, 84)
    s:melody('lead', hook, 110)
    if tour == 2 then s:harmony('lead2', hook, 100, -5, key)
    elseif tour == 3 or tour == 5 then s:melody('lead2', low, 100)
    else s:melody('lead2', canon(low, 4, 32), 100) end
    s:pads('organ', harmony, P('F3'), 4, 76)
    for b = 1, 8 do s:note('organ', (b - 1) * 4, 3.95, tour == 4 and P('F1') or A.root(first(harmony[b]), P('F1')), 80) end
    if tour == 5 then s:melody('choir', theme, 84, 0.98) else s:pads('choir', harmony, P('C4'), 3, 74) end
    s:pads('strings', harmony, P('F4'), 3, 60)
    if tour == 3 or tour == 5 then s:melody('brass', theme, 94, 0.95)
    else for b = 1, 8 do s:chord('brass', (b - 1) * 4, b > 4 and 3.8 or 1, A.voicing(first(harmony[b]), P('F3'), 3), b > 4 and 90 or 104) end end
    for b = 1, 8 do s:note('timpani', (b - 1) * 4, 1, b % 2 == 1 and 'F2' or 'C2', 108) end
    for b = 1, 8, tour == 2 and 1 or 2 do s:note('bells', (b - 1) * 4, 3, 'F5', 82) end
  end

  -- collapse (8 bars, then the victory) ---------------------------------------------------------------------
  do
    local s = new('collapse')
    local ch = ({
      [2] = { 'Fm', 'Db', 'Gb', 'C', 'Fm', 'Db', 'Bbm|C', 'Fm' },
      [3] = { 'Fm', 'Db', 'Gb', 'C', 'Fm', 'Db', 'Bbm|C', 'Fm' },
      [4] = { 'Fm', 'Gb', 'Db', 'C', 'Fm', 'Gb', 'Db|C', 'Fm' },
      [5] = { 'Fm', 'Db', 'Gb', 'C', 'Fm', 'Db', 'Bbm', 'C' },
    })[tour]
    for b, sym in ipairs(ch) do
      local t = (b - 1) * 4
      for _, part in ipairs(A.split(sym)) do
        local r = A.root(part.sym, P('B1'))
        s:power('gtrL', t + part.t, part.len - 0.08, r, 122); s:power('gtrR', t + part.t, part.len - 0.08, r, 118)
        s:note('bass', t + part.t, part.len - 0.08, r - 12, 120)
      end
      s:hit('drums', t, 'kick', 124); s:hit('drums', t + 1.5, 'kick', 100); s:hit('drums', t + 2, 'snare', 124)
      s:hit('cymbals', t, b % 2 == 1 and 'crash' or 'crash2', 118, 3)
      for i = 1, 3 do s:hit('cymbals', t + i, 'ride', 76) end
      if b % (tour == 2 and 2 or 4) == 0 then s:fill('drums', b, 2.5, 100) end
      s:note('timpani', t, 1.5, A.root(first(sym), P('C2')), 118)
      s:note('timpani', t + 2, 1.5, A.root(first(sym), P('C2')), 104)
      s:note('bells', t, 3.5, A.root(first(sym), P('C5')), 92)
    end
    local line = A.seq('F5:4 Ab5:4 Db6:4 Bb5:2 C6:2 F5:4 Ab5:2 Db6:2 Db6:2 E5:2 F5:4')
    if tour == 4 then line = stretch(shift(hook, 0), 2, 32) end
    if tour == 5 then line = A.seq('F5:4 Ab5:4 Db6:4 Bb5:2 C6:2 F5:4 Ab5:2 Db6:2 Bb5:4 C6:2 E5:2') end
    s:melody('lead', line, 108, 0.98)
    s:harmony('lead2', line, 96, -2, key, 0.98)
    s:pads('organ', ch, P('F3'), 4, 84)
    if tour == 3 then s:melody('choir', theme, 88, 0.98) else s:pads('choir', ch, P('C4'), 3, 84) end
    s:pads('strings', ch, P('F3'), 4, 66)
    if tour == 4 then s:melody('brass', stretch(low, 2, 32), 96, 0.96) else s:pads('brass', ch, P('F3'), 3, 88) end
  end

  -- victory (4 bars): the F major fanfare on the campaign theme -------------------------------------------------
  do
    local s = new('victory')
    local hold = (spec.sections.victory.hold or 0) > 0
    local tune = A.seq('F5:1.5 A5:.5 C6:1 Bb5:1 A5:2 G5:1 F5:1 Bb5:1.5 A5:.5 G5:1 E5:1 F5:4')
    local ch = { 'F', 'F|C', 'Bb|C', 'F' }
    if tour == 5 then
      -- The resolution: the minor cadence opens into F major under the theme.
      ch = { 'Fm|Db', 'Bb|C', 'Db|C', 'F' }
      tune = A.seq('F5:1.5 Ab5:.5 C6:1 Bb5:1 A5:2 G5:1 F5:1 Ab5:1.5 G5:.5 F5:1 E5:1 F5:4')
    end
    s:melody('lead', tune, 112, 0.96)
    if tour == 3 then s:melody('lead2', canon(tune, 2, 16), 96, 0.94)
    else s:harmony('lead2', tune, 98, -2, major, 0.96) end
    if tour == 4 then s:harmony('fanfare', tune, 100, 2, major, 0.94) else s:harmony('fanfare', tune, 102, -2, major, 0.94) end
    s:melody('fanfare', tune, 98, 0.94, -12)
    if tour == 2 then s:harmony('strings', shift(tune, -12), 70, 5, major, 0.98) end
    for b, sym in ipairs(ch) do
      local t = (b - 1) * 4
      for _, part in ipairs(A.split(sym)) do
        local r = A.root(part.sym, P('B1'))
        if b < 4 then
          for e = 0, part.len * 2 - 1 do
            s:power('gtrL', t + part.t + e * 0.5, 0.42, r, e == 0 and 116 or 92)
            s:power('gtrR', t + part.t + e * 0.5, 0.42, r, e == 0 and 112 or 88)
            s:note('bass', t + part.t + e * 0.5, 0.45, r - 12, 106)
          end
        else
          s:power('gtrL', t, 3.9, r, 118); s:power('gtrR', t, 3.9, r, 114); s:note('bass', t, 3.9, r - 12, 114)
        end
      end
      if b < 4 then
        s:hit('drums', t, 'kick', 114); s:hit('drums', t + 2, 'kick', 106)
        for e = 0, 7 do s:hit('drums', t + e * 0.5, 'snare', e % 4 == 0 and 114 or e % 2 == 0 and 98 or 80) end
        s:hit('cymbals', t, 'crash', 110, 2)
      end
    end
    s:hit('drums', 12, 'kick', 120); s:hit('cymbals', 12, 'crash', 118, 4); s:hit('cymbals', 12, 'china', 102, 2)
    s:note('timpani', 12, 1, 'F2', 118); s:roll('timpani', 13, 3, P('C2'), 60, 108)
    s:pads('organ', ch, P('F3'), 4, 78)
    s:pads('choir', ch, P('C4'), 3, 74)
    if tour ~= 2 then s:pads('strings', ch, P('A3'), 4, 66) end
    s:pads('fanfare', ch, P('A3'), 3, 94)
    s:note('bells', 12, 4, 'F5', 88); s:note('bells', 12, 4, 'C6', 76)
    if hold then
      -- hold (bar 5): F major, soft, repeatable through the travel.
      s:chord('organ', 16, 4, A.voicing('F', P('F3'), 3), 52)
      s:chord('strings', 16, 4, A.voicing('F', P('A3'), 4), 46)
      s:chord('choir', 16, 4, A.voicing('F', P('C4'), 3), 46)
      s:note('bass', 16, 4, 'F1', 72)
    end
  end

  if spec.sections.finale then
    -- finale (8 bars, F major): the campaign theme with the whole band.
    local s = new('finale')
    local ch = { 'F', 'Dm', 'Bb', 'C', 'F', 'Dm', 'Bb|C', 'F' }
    local tune = A.line(major, 5, '1:1.5 3:.5 5:1 4:1 3:2 2:1 1:1 8:1.5 7:.5 6:1 5:1 4:2 2:2 '
      .. '1:1.5 3:.5 5:1 4:1 5:1 7:1 8:2 8:1 7:1 6:1 5:1 8:4')
    s:melody('lead', tune, 112, 0.97)
    s:harmony('lead2', tune, 98, -2, major, 0.97)
    s:harmony('fanfare', tune, 100, -2, major, 0.94)
    s:melody('fanfare', tune, 96, 0.94, -12)
    for b, sym in ipairs(ch) do
      local t = (b - 1) * 4
      for _, part in ipairs(A.split(sym)) do
        local r = A.root(part.sym, P('B1'))
        for e = 0, part.len * 2 - 1 do
          local open = e == 0
          s:power('gtrL', t + part.t + e * 0.5, open and 0.48 or 0.42, r, open and 116 or 92)
          s:power('gtrR', t + part.t + e * 0.5, open and 0.48 or 0.42, r, open and 112 or 88)
          s:note('bass', t + part.t + e * 0.5, 0.45, r - 12, open and 110 or 100)
        end
      end
      s:hit('drums', t, 'kick', 114); s:hit('drums', t + 2, 'kick', 108); s:hit('drums', t + 2.5, 'kick', 96)
      s:hit('drums', t + 1, 'snare', 112); s:hit('drums', t + 3, 'snare', 116)
      hats(s, b, 0.5, 84, 'ride')
      if b % 4 == 1 then s:hit('cymbals', t, 'crash', 114, 2) end
      if b == 4 or b == 8 then s:roll('drums', t + 2, 2, 'snare', 70, 118) end
      s:note('timpani', t, 1, A.root(first(sym), P('C2')), 108)
    end
    s:pads('organ', ch, P('F3'), 3, 76)
    s:pads('choir', ch, P('C4'), 3, 78)
    s:pads('strings', ch, P('A3'), 4, 68)
    s:pads('fanfare', ch, P('A3'), 3, 90)
    for b = 1, 8, 2 do s:note('bells', (b - 1) * 4, 3, 'F5', 84) end
  end

  if spec.sections.worldized then
    -- worldized (6 bars, a bridge into the coda): the finale thinning while the cinematic opens; the player passes
    -- it through the band-pass small room (fx). Clean strums, the theme softly, a ride and a soft kick, a held C.
    local s = new('worldized')
    local ch = { 'F', 'Bb', 'F|C', 'Dm', 'Bb', 'C' }
    for b, sym in ipairs(ch) do
      local t = (b - 1) * 4
      local fade = (b - 1) * 6
      for _, part in ipairs(A.split(sym)) do
        local voicing = A.voicing(part.sym, P('F3'), 4)
        for e = 0, part.len * 2 - 1 do
          for i, p in ipairs(voicing) do s:note('clean', t + part.t + e * 0.5 + (i - 1) * 0, 0.45, p, (e % 2 == 0 and 84 or 66) - fade) end
        end
        s:note('bass', t + part.t, part.len - 0.1, A.root(part.sym, P('F1')), 92 - fade)
      end
      if b < 6 then
        s:hit('drums', t, 'kick', 96 - fade); s:hit('drums', t + 2, 'rim', 84 - fade)
        for e = 0, 3 do s:hit('cymbals', t + e, 'ride', 70 - fade) end
      end
    end
    local tune = A.line(major, 5, '1:1.5 3:.5 5:1 4:1 3:2 2:1 1:1 5:1.5 4:.5 3:1 2:1 1:4 2:4 7:4')
    s:melody('lead', tune, 84, 0.97)
    s:pads('organ', ch, P('F3'), 3, 58)
    s:pads('strings', ch, P('A3'), 3, 52)
    s:note('bells', 0, 4, 'F5', 70); s:note('bells', 16, 4, 'C6', 60)
  end

  return S
end
