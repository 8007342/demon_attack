-- The carrier, tour 1 (sector 5): F minor, 190 BPM. Original writing from the carrier's own motifs: the riff and
-- the hook of tools/music_motifs.py MOTIFS[5] (the F | F-Gb-E crawl, the B tritone stab, the Db-D-Eb-E climb) and
-- the campaign theme (degrees 1-3-5-4). One arrangement for the whole fight graph of design §4: arrival, approach,
-- the hatch tiers H1 and H2, the transformation bridge, the core, the collapse and the F major victory. The riff is
-- chromatic by design (song-map `chromatic`), so the out-of-scale gate only reports it.
--
-- Tours 2-5 (spec.tour > 1) are songs/carrier_tours.lua: the same band and motifs, escalating.
return function(A, spec, seed)
  if (spec.tour or 1) > 1 then return require('songs.carrier_tours')(A, spec, seed) end
  local key = A.key(spec.key)
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
  -- The hook sits high; the hatch tiers play it an octave down, the core in its own register.
  local S = {}
  local function new(id) local s = A.section(id, spec.sections[id].bars, seed + #id * 131 + id:byte(1)); S[id] = s; return s end

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
  local function doubleKick(s, bars, v)
    for b = 1, bars do for i = 0, 15 do s:hit('drums2', (b - 1) * 4 + i * 0.25, 'kick', (v or 80) + (i % 4 == 0 and 8 or 0)) end end
  end
  -- Blast: kick on the eighths, snare on the sixteenth after each, ride on the eighths.
  local function blast(s, b, fill)
    local t = (b - 1) * 4
    for e = 0, 7 do
      if not (fill and e >= 6) then
        s:hit('drums', t + e * 0.5, 'kick', e % 2 == 0 and 110 or 100)
        s:hit('drums', t + e * 0.5 + 0.25, 'snare', e % 2 == 0 and 104 or 96)
      end
    end
    hats(s, b, 0.5, 80)
    if fill then s:fill('drums', b, 3, 98) end
  end
  -- Tremolo picking: sixteenths on each eighth's root.
  local function tremolo(s, rows, vL, octaveBass)
    for b, row in ipairs(rows) do
      for e, root in ipairs(row) do
        local change = e == 1 or row[e - 1] ~= root
        for k = 0, 1 do
          local t = (b - 1) * 4 + (e - 1) * 0.5 + k * 0.25
          local v = (change and k == 0) and vL + 14 or vL
          s:power('gtrL', t, 0.22, root, v)
          s:power('gtrR', t, 0.22, root, v - 4, true)
        end
        s:note('bass', (b - 1) * 4 + (e - 1) * 0.5, 0.45, root - (octaveBass and 12 or 12), change and 112 or 100)
      end
    end
  end

  -- arrival (4 bars): the fog and the overflight --------------------------------------------------------------
  do
    local s = new('arrival')
    s:chord('organ', 0, 15.9, { P('F2'), P('C3') }, 70)
    s:pads('organ', { 'Fm', 'Fm', 'Db', 'C' }, P('F3'), 3, 58)
    for b = 1, 4 do s:note('bells', (b - 1) * 4, 3.5, 'F4', 96); s:note('bells', (b - 1) * 4, 3.5, 'F5', 70) end
    s:roll('timpani', 0, 12, P('F2'), 34, 80, 0.5)
    s:power('gtrL', 4, 7.8, P('F2'), 72); s:power('gtrR', 4, 7.8, P('F2'), 68, true)
    s:chord('brass', 8, 3.9, A.voicing('Db', P('F3'), 3), 78)
    s:chord('brass', 12, 3.9, A.voicing('C', P('E3'), 3), 92)
    s:note('bass', 4, 3.9, 'F1', 90); s:note('bass', 8, 3.9, 'Db1', 96); s:note('bass', 12, 3.9, 'C1', 104)
    s:pads('choir', { 'Db', 'C' }, P('F4'), 3, 60, 8)
    s:hit('drums', 8, 'kick', 104); s:hit('drums', 10, 'snare', 96)
    s:hit('drums', 12, 'kick', 112); s:hit('cymbals', 12, 'crash', 100, 2)
    s:roll('drums', 13, 3, 'snare', 46, 118)
    s:roll('timpani', 12, 4, P('C2'), 70, 112)
  end

  -- approach (8 bars loop): slow crushing half-time doom -------------------------------------------------------
  do
    local s = new('approach')
    for b, row in ipairs(riff) do
      for i, run in ipairs(A.runs(row)) do
        local t = (b - 1) * 4 + run.t
        local v = i == 1 and 114 or 104
        s:power('gtrL', t, run.len - 0.06, run.p, v)
        s:power('gtrR', t, run.len - 0.06, run.p, v - 4, true)
        s:note('bass', t, run.len - 0.06, run.p - 12, v)
      end
      local t = (b - 1) * 4
      s:hit('drums', t, 'kick', 116); s:hit('drums', t + 2, 'snare', 116)
      if b % 2 == 0 then s:hit('drums', t + 2.5, 'kick', 98) end
      if b % 4 ~= 0 then hats(s, b, 1, 80) else s:fill('drums', b, 3, 90) end
      s:note('bells', t, 3.5, 'F4', 98); s:note('bells', t, 3.5, 'C5', 66)
    end
    crashes(s, 8, 2, 1)
    for b = 4, 8, 4 do for i = 8, 15 do s:hit('drums2', (b - 1) * 4 + i * 0.25, 'kick', 84) end end
    local line = A.seq('F4:4 Ab4:2 G4:2 C5:4 Bb4:2 Ab4:2 F4:4 G4:2 Ab4:2 Db5:2 Eb5:2 C5:4')
    s:melody('lead', line, 98, 0.98)
    s:harmony('lead2', line, 86, -2, key, 0.98)
    s:pads('organ', harmony, P('F3'), 3, 64)
    for b = 1, 8 do s:chord('brass', (b - 1) * 4, 3.9, { P('F2'), P('C3') }, 72) end
    s:pads('choir', harmony, P('F4'), 3, 60)
    s:pads('strings', harmony, P('C4'), 3, 50)
    for _, b in ipairs({ 1, 5 }) do s:note('timpani', (b - 1) * 4, 1.5, 'F2', 106) end
    s:roll('timpani', 30, 2, P('C2'), 60, 100)
  end

  -- H1 (8 bars loop): galloping battle metal -----------------------------------------------------------------
  do
    local s = new('H1')
    for b, row in ipairs(riff) do
      for beat = 0, 3 do
        local root = row[beat * 2 + 1]
        local t = (b - 1) * 4 + beat
        local first = beat == 0 or row[beat * 2 - 1] ~= root
        for i, off in ipairs({ 0, 0.5, 0.75 }) do
          local v = i == 1 and (first and 114 or 96) or 86
          s:power('gtrL', t + off, i == 1 and 0.45 or 0.22, root, v)
          s:power('gtrR', t + off, i == 1 and 0.45 or 0.22, root, v - 4, true)
          s:note('bass', t + off, i == 1 and 0.45 or 0.22, root - 12, i == 1 and 110 or 98)
          if not (b == 8 and beat == 3) then s:hit('drums', t + off, 'kick', i == 1 and 110 or 94) end
        end
      end
      local t = (b - 1) * 4
      s:hit('drums', t + 1, 'snare', 114)
      if b ~= 8 then s:hit('drums', t + 3, 'snare', 116) else s:fill('drums', 8, 3, 96) end
      hats(s, b, 0.5, 82)
    end
    crashes(s, 8, 4, 1, true)
    doubleKick(s, 8, 76)
    s:melody('lead', hook, 104, 0.95, -12)
    s:harmony('lead2', hook, 94, -2, key)
    s:pads('organ', harmony, P('F3'), 3, 62)
    s:pads('choir', { 'Fm', 'Fm', 'Db|Eb', 'Fm' }, P('F4'), 3, 62, 16)
    s:pads('strings', harmony, P('Ab3'), 3, 52)
    for _, b in ipairs({ 1, 3, 5, 7 }) do s:chord('brass', (b - 1) * 4, 1, A.voicing(harmony[b]:match('^[^|]+'), P('F3'), 3), 100) end
    s:note('timpani', 0, 1.5, 'F2', 106); s:note('timpani', 16, 1.5, 'F2', 102)
    s:note('bells', 0, 3, 'F5', 78); s:note('bells', 16, 3, 'C6', 72)
  end

  -- H2 (8 bars loop): tremolo rising into blast beats, twin leads --------------------------------------------
  do
    local s = new('H2')
    tremolo(s, riff, 94)
    for b = 1, 8 do
      local t = (b - 1) * 4
      if b <= 4 then
        -- Skank: kick on the beat, snare on the offbeat eighths.
        for e = 0, 7 do
          if e % 2 == 0 then s:hit('drums', t + e * 0.5, 'kick', 110) else s:hit('drums', t + e * 0.5, 'snare', 108) end
        end
        hats(s, b, 0.5, 80)
      else
        blast(s, b, b == 8)
      end
    end
    crashes(s, 8, 2, 0.5, true)
    doubleKick(s, 8, 80)
    s:melody('lead', hook, 108)
    s:harmony('lead2', hook, 98, -2, key)
    s:pads('organ', harmony, P('F3'), 3, 66)
    s:pads('choir', harmony, P('F4'), 3, 66)
    s:pads('strings', harmony, P('C4'), 3, 54)
    for b = 5, 8 do s:chord('brass', (b - 1) * 4, 3.8, A.voicing(harmony[b]:match('^[^|]+'), P('F3'), 3), 88) end
    for _, b in ipairs({ 1, 3, 5, 7 }) do s:note('timpani', (b - 1) * 4, 1, 'F2', 108) end
    s:note('bells', 16, 3, 'F5', 80)
  end

  -- transform (3 bars, a bridge into the core's downbeat) -----------------------------------------------------
  do
    local s = new('transform')
    s:chord('organ', 0, 3.95, A.voicing('Db', P('Db3'), 4), 72); s:chord('organ', 0, 3.95, { P('Db2') }, 76)
    s:chord('choir', 0, 3.95, A.voicing('Db', P('F4'), 3), 64)
    s:chord('organ', 4, 3.95, A.voicing('Eb', P('Eb3'), 4), 84); s:chord('organ', 4, 3.95, { P('Eb2') }, 86)
    s:chord('choir', 4, 3.95, A.voicing('Eb', P('G4'), 3), 78)
    s:chord('organ', 8, 3.95, A.voicing('C7', P('C3'), 4), 98); s:chord('organ', 8, 3.95, { P('C2') }, 98)
    s:chord('choir', 8, 3.95, A.voicing('C', P('E4'), 3), 92)
    s:chord('strings', 0, 7.9, A.voicing('Db', P('Ab3'), 3), 58); s:chord('strings', 8, 3.95, A.voicing('C', P('G3'), 4), 86)
    for k = 0, 15 do
      s:power('gtrL', k * 0.25, 0.22, P('Db2'), 70 + k); s:power('gtrR', k * 0.25, 0.22, P('Db2'), 66 + k, true)
      s:power('gtrL', 4 + k * 0.25, 0.22, P('Eb2'), 86 + k); s:power('gtrR', 4 + k * 0.25, 0.22, P('Eb2'), 82 + k, true)
    end
    s:note('bass', 0, 3.95, 'Db1', 96); s:note('bass', 4, 3.95, 'Eb1', 104)
    local climb = { 'Db2', 'D2', 'Eb2', 'E2' }
    for i, n in ipairs(climb) do
      local t = 8 + (i - 1)
      s:power('gtrL', t, 0.9, P(n), 118); s:power('gtrR', t, 0.9, P(n), 114, true)
      s:note('bass', t, 0.9, P(n) - 12, 116)
      s:chord('brass', t, 0.9, { P(n) + 12, P(n) + 19 }, 104 + i * 3)
      s:note('lead', t, 0.95, P(n) + 36, 104 + i * 3)
      s:hit('drums', t, 'kick', 118); s:hit('cymbals', t, i == 1 and 'crash' or 'crash2', 96 + i * 6, 1)
    end
    s:hit('drums', 0, 'kick', 108); s:hit('cymbals', 0, 'crash', 100, 3)
    s:roll('timpani', 0, 8, P('F2'), 44, 96)
    s:roll('timpani', 8, 4, P('C2'), 98, 124)
    s:roll('drums', 5, 3, 'snare', 54, 104)
    s:roll('drums', 8, 3, 'snare', 104, 122)
    s:fill('drums', 3, 3, 104)
  end

  -- core (8 bars loop): the climax ------------------------------------------------------------------------
  do
    local s = new('core')
    tremolo(s, riff, 98)
    for b = 1, 8 do blast(s, b, b % 4 == 0) end
    crashes(s, 8, 1, nil, true)
    for b = 1, 8 do for i = 1, 7 do s:hit('cymbals', (b - 1) * 4 + i * 0.5, 'ride', i % 2 == 0 and 84 or 70, 0.5) end end
    doubleKick(s, 8, 84)
    s:melody('lead', hook, 110)
    s:harmony('lead2', hook, 100, -2, key)
    s:pads('organ', harmony, P('F3'), 4, 76)
    for b = 1, 8 do s:note('organ', (b - 1) * 4, 3.95, A.root(harmony[b]:match('^[^|]+'), P('F1')), 80) end
    s:pads('choir', harmony, P('C4'), 3, 74)
    s:pads('strings', harmony, P('F4'), 3, 60)
    for b = 1, 8 do s:chord('brass', (b - 1) * 4, b > 4 and 3.8 or 1, A.voicing(harmony[b]:match('^[^|]+'), P('F3'), 3), b > 4 and 90 or 104) end
    for b = 1, 8 do s:note('timpani', (b - 1) * 4, 1, b % 2 == 1 and 'F2' or 'C2', 108) end
    for b = 1, 8, 2 do s:note('bells', (b - 1) * 4, 3, 'F5', 82) end
    -- --- demon-choir: the brood choir (sampled only: silent while the bank is off). Root drones from F2 on the
    -- harmony, "oh" (velocity <= 84) for four bars, then "ah". Root only and no grunts: each zone is already an
    -- ensemble, and the core already peaks at 29 voices, so the 1UP stinger (+3) still fits under 32. The core's
    -- shouts are the dive war cries (the `warcry` stinger). Written last, so the other humanised velocities stay put.
    A.drones(s, 'brood', harmony, P('F2'), 72, 1, 4, true)
    A.drones(s, 'brood', harmony, P('F2'), 102, 5, 8, true)
  end

  -- collapse (8 bars, then the victory): monumental half-time doom finale --------------------------------------
  do
    local s = new('collapse')
    local ch = { 'Fm', 'Db', 'Gb', 'C', 'Fm', 'Db', 'Bbm|C', 'Fm' }
    for b, sym in ipairs(ch) do
      local t = (b - 1) * 4
      for _, part in ipairs(A.split(sym)) do
        local r = A.root(part.sym, P('B1'))
        s:power('gtrL', t + part.t, part.len - 0.08, r, 122); s:power('gtrR', t + part.t, part.len - 0.08, r, 118, true)
        s:note('bass', t + part.t, part.len - 0.08, r - 12, 120)
      end
      s:hit('drums', t, 'kick', 124); s:hit('drums', t + 1.5, 'kick', 100); s:hit('drums', t + 2, 'snare', 124)
      s:hit('cymbals', t, b % 2 == 1 and 'crash' or 'crash2', 118, 3)
      for i = 1, 3 do s:hit('cymbals', t + i, 'ride', 76) end
      if b % 4 == 0 then s:fill('drums', b, 2.5, 100) end
      s:note('timpani', t, 1.5, A.root(sym:match('^[^|]+'), P('C2')), 118)
      s:note('timpani', t + 2, 1.5, A.root(sym:match('^[^|]+'), P('C2')), 104)
      s:note('bells', t, 3.5, A.root(sym:match('^[^|]+'), P('C5')), 92)
    end
    local line = A.seq('F5:4 Ab5:4 Db6:4 Bb5:2 C6:2 F5:4 Ab5:2 Db6:2 Db6:2 E5:2 F5:4')
    s:melody('lead', line, 108, 0.98)
    s:harmony('lead2', line, 96, -2, key, 0.98)
    s:pads('organ', ch, P('F3'), 4, 84)
    s:pads('choir', ch, P('C4'), 3, 84)
    s:pads('strings', ch, P('F3'), 4, 66)
    s:pads('brass', ch, P('F3'), 3, 88)
  end

  -- victory (4 bars + 1 hold bar): the F major fanfare on the campaign theme -----------------------------------
  do
    local s = new('victory')
    local major = A.key('F major')
    local tune = A.seq('F5:1.5 A5:.5 C6:1 Bb5:1 A5:2 G5:1 F5:1 Bb5:1.5 A5:.5 G5:1 E5:1 F5:4')
    s:melody('lead', tune, 112, 0.96)
    s:harmony('lead2', tune, 98, -2, major, 0.96)
    s:harmony('fanfare', tune, 102, -2, major, 0.94)
    s:melody('fanfare', tune, 98, 0.94, -12)
    local ch = { 'F', 'F|C', 'Bb|C', 'F' }
    for b, sym in ipairs(ch) do
      local t = (b - 1) * 4
      for _, part in ipairs(A.split(sym)) do
        local r = A.root(part.sym, P('B1'))
        if b < 4 then
          for e = 0, part.len * 2 - 1 do
            s:power('gtrL', t + part.t + e * 0.5, 0.42, r, e == 0 and 116 or 92)
            s:power('gtrR', t + part.t + e * 0.5, 0.42, r, e == 0 and 112 or 88, true)
            s:note('bass', t + part.t + e * 0.5, 0.45, r - 12, 106)
          end
        else
          s:power('gtrL', t, 3.9, r, 118); s:power('gtrR', t, 3.9, r, 114, true); s:note('bass', t, 3.9, r - 12, 114)
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
    s:pads('strings', ch, P('A3'), 4, 66)
    s:pads('fanfare', ch, P('A3'), 3, 94)
    s:note('bells', 12, 4, 'F5', 88); s:note('bells', 12, 4, 'C6', 76)
    -- hold (bar 5): F major, soft, repeatable through the travel.
    s:chord('organ', 16, 4, A.voicing('F', P('F3'), 3), 52)
    s:chord('strings', 16, 4, A.voicing('F', P('A3'), 4), 46)
    s:chord('choir', 16, 4, A.voicing('F', P('C4'), 3), 46)
    s:note('bass', 16, 4, 'F1', 72)
  end

  return S
end
