-- Krybor (sector 1): E minor, 170 BPM. Original writing from the game's own motifs: the riff and the hook of
-- tools/music_motifs.py MOTIFS[1], the campaign theme (degrees 1-3-5-4, rhythm 1.5/.5/1/1) and Krybor's harmony
-- from art/music/campaign.json. Every section shares the key, the tempo, the band and the mix, so any move between
-- them is a move inside one arrangement.
--
-- Parts per section (tracks, the tier masks of song-map.json choose which play):
--   drums (kick, snare, hats), cymbals (crash, ride), drums2 (double kick), bass, gtrL/gtrR (power chords; a
--   velocity <= 92 means palm-muted to the guitar voice), clean, lead, lead2 (diatonic thirds below), organ,
--   strings, brass, choir, timpani, bells, fanfare (the fleet layer).
return function(A, spec, seed)
  local key = A.key(spec.key)
  local P = A.pitch

  local riff = A.riff({
    'E2 E2 E2 E2 E2 E2 G2 A2', 'E2 E2 E2 E2 D2 D2 B1 B1',
    'C3 C3 C3 C3 C3 C3 D3 D3', 'D3 D3 D3 D3 D3 D3 A2 G2',
    'E2 E2 E2 E2 E2 E2 G2 A2', 'E2 E2 E2 E2 D2 D2 B1 B1',
    'A2 A2 A2 A2 G2 G2 G2 G2', 'B1 B1 B1 B1 B1 B1 D2 D#2',
  })
  local harmony = { 'Em', 'Em', 'C', 'D', 'Em', 'Em', 'Am|G', 'B' }
  local hook = A.seq('B4:1 B4:.5 A4:.5 G4:1 E4:1 G4:.5 A4:.5 B4:1 D5:1 B4:1 C5:1.5 B4:.5 A4:1 G4:1 '
    .. 'A4:1 F#4:1 D4:2 B4:1 B4:.5 A4:.5 G4:1 E4:1 G4:.5 A4:.5 B4:1 D5:1 E5:1 E5:1 D5:1 B4:1 G4:1 F#4:2 B4:1.5 D#5:.5')

  local S = {}
  local function new(id) local s = A.section(id, spec.sections[id].bars, seed + #id * 97 + id:byte(1)); S[id] = s; return s end

  -- Shared drum figures --------------------------------------------------------------------------------------
  local function hats(s, b, v)
    for e = 0, 7 do s:hit('drums', (b - 1) * 4 + e * 0.5, e % 2 == 0 and 'hat' or 'pedal', e % 2 == 0 and v or v - 18) end
  end
  local function punk(s, b, fill)
    local t = (b - 1) * 4
    s:hit('drums', t, 'kick', 112); s:hit('drums', t + 2, 'kick', 106)
    if b % 2 == 0 then s:hit('drums', t + 2.5, 'kick', 96) end
    s:hit('drums', t + 1, 'snare', 112)
    if not fill then s:hit('drums', t + 3, 'snare', 114) end
    hats(s, b, 86)
    if fill then s:fill('drums', b, 3, 92) end
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

  -- Guitars and bass on the riff ----------------------------------------------------------------------------
  -- Eighth-note downstrokes: palm-muted, opened (accented) where the root changes.
  local function chug8(s, rows, accentChanges)
    for b, row in ipairs(rows) do
      for e, root in ipairs(row) do
        local t = (b - 1) * 4 + (e - 1) * 0.5
        local change = e == 1 or row[e - 1] ~= root
        local open = change and accentChanges
        s:power('gtrL', t, open and 0.48 or 0.42, root, open and 112 or 88)
        s:power('gtrR', t, open and 0.48 or 0.4, root, open and 108 or 84, true)
        s:note('bass', t, 0.45, root - 12, change and 110 or 98)
      end
    end
  end
  -- Gallop: an eighth and two sixteenths on each beat's root.
  local function gallop(s, rows)
    for b, row in ipairs(rows) do
      for beat = 0, 3 do
        local root = row[beat * 2 + 1]
        local t = (b - 1) * 4 + beat
        local first = beat == 0 or row[beat * 2 - 1] ~= root
        for i, off in ipairs({ 0, 0.5, 0.75 }) do
          local v = i == 1 and (first and 112 or 92) or 84
          s:power('gtrL', t + off, i == 1 and 0.45 or 0.22, root, v)
          s:power('gtrR', t + off, i == 1 and 0.45 or 0.22, root, v - 4, true)
          s:note('bass', t + off, i == 1 and 0.45 or 0.22, root - 12, i == 1 and 108 or 96)
        end
      end
    end
  end

  -- arrival: quiet clean arrival (4 bars) -------------------------------------------------------------------
  do
    local s = new('arrival')
    local arp = { 'E3', 'B3', 'E4', 'G4', 'B4', 'G4', 'E4', 'B3' }
    for b = 1, 2 do for e, n in ipairs(arp) do s:note('clean', (b - 1) * 4 + (e - 1) * 0.5, 0.9, n, 58 + b * 4) end end
    for e, n in ipairs({ 'C3', 'G3', 'C4', 'E4', 'D3', 'A3', 'D4', 'F#4' }) do s:note('clean', 8 + (e - 1) * 0.5, 0.9, n, 70) end
    s:pads('organ', { 'Em', 'Em', 'C|D', 'B' }, P('E3'), 3, 54)
    s:melody('bells', A.seq('E5:1.5 G5:.5 B5:1 A5:1', 4), 64, 1.4)
    s:pads('choir', { 'C|D', 'B' }, P('E4'), 3, 50, 8)
    for i = 0, 3 do s:hit('drums', 4 + i, 'floorLo', 62 + i * 6, 1) end
    s:hit('drums', 8, 'kick', 100); s:hit('drums', 10, 'kick', 96); s:hit('drums', 11, 'snare', 96)
    hats(s, 3, 70)
    s:note('bass', 8, 1.9, 'C2', 96); s:note('bass', 10, 1.9, 'D2', 100); s:note('bass', 12, 3.9, 'B1', 108)
    s:hit('drums', 12, 'kick', 112); s:hit('cymbals', 12, 'crash', 104, 2)
    s:power('gtrL', 12, 1.9, P('B1'), 110); s:power('gtrR', 12, 1.9, P('B1'), 106, true)
    for i = 0, 3 do
      s:power('gtrL', 14 + i * 0.5, 0.4, P('B1'), 76 + i * 8); s:power('gtrR', 14 + i * 0.5, 0.4, P('B1'), 72 + i * 8, true)
    end
    s:roll('drums', 13, 3, 'snare', 48, 112)
    s:roll('timpani', 13, 3, P('B1'), 46, 100)
  end

  -- A: the riff and the hook ----------------------------------------------------------------------------------
  do
    local s = new('A')
    chug8(s, riff, true)
    for b = 1, 8 do punk(s, b, b == 8) end
    cymbals(s, 8, 4, 1)
    doubleKick(s, 8, 0, 4, 74)
    s:melody('lead', hook, 104)
    s:harmony('lead2', hook, 92, -2, key)
    s:pads('organ', harmony, P('E3'), 3, 64)
    s:pads('strings', harmony, P('B3'), 4, 56)
    for _, b in ipairs({ 1, 5 }) do s:chord('brass', (b - 1) * 4, 1.5, A.voicing('Em', P('E3'), 3), 98) end
    s:chord('brass', 28, 1.5, A.voicing('B', P('D#3'), 3), 100)
    s:pads('choir', { 'Em', 'Em', 'Am|G', 'B' }, P('E4'), 3, 62, 16)
    s:note('timpani', 0, 1.5, 'E2', 104); s:note('timpani', 16, 1.5, 'E2', 100)
    s:note('timpani', 30, 0.9, 'B1', 96); s:note('timpani', 31, 0.9, 'B1', 108)
    s:note('bells', 0, 3, 'E5', 76); s:note('bells', 16, 3, 'E5', 76)
  end

  -- B: the answer: gallop, the campaign theme called and answered ---------------------------------------------
  do
    local s = new('B')
    local roots = A.riff({
      'E2 E2 E2 E2 E2 E2 E2 E2', 'E2 E2 E2 E2 G2 G2 A2 A2', 'C3 C3 C3 C3 C3 C3 C3 C3', 'D3 D3 D3 D3 D3 D3 D3 D3',
      'E2 E2 E2 E2 E2 E2 E2 E2', 'E2 E2 E2 E2 G2 G2 A2 A2', 'A2 A2 A2 A2 G2 G2 G2 G2', 'B1 B1 B1 B1 B1 B1 B1 B1',
    })
    gallop(s, roots)
    for b = 1, 8 do
      local t = (b - 1) * 4
      for beat = 0, 3, 2 do for _, off in ipairs({ 0, 0.5, 0.75 }) do s:hit('drums', t + beat + off, 'kick', off == 0 and 110 or 94) end end
      s:hit('drums', t + 1, 'snare', 112)
      if b ~= 8 then s:hit('drums', t + 3, 'snare', 114) else s:fill('drums', 8, 3, 94) end
      hats(s, b, 82)
    end
    cymbals(s, 8, 4, 0.5)
    doubleKick(s, 8, 2, 4, 76)
    local theme = A.seq('E4:1.5 G4:.5 B4:1 A4:1 G4:2 F#4:1 E4:1 E5:1.5 D5:.5 C5:1 B4:1 A4:2 F#4:2 '
      .. 'E4:1.5 G4:.5 B4:1 A4:1 B4:1 D5:1 E5:2 E5:1 D5:1 C5:1 B4:1 B4:2 D#5:2')
    s:melody('lead', theme, 106, 0.97, 12)
    s:harmony('lead2', theme, 94, -2, key, 0.97)
    for i = 0, 7, 2 do s:chord('brass', (i + 1) * 4, 0.9, A.voicing(harmony[i + 2]:match('^[^|]+'), P('G3'), 3), 96) end
    s:pads('organ', harmony, P('E3'), 3, 62)
    s:pads('strings', harmony, P('E4'), 3, 54)
    s:pads('choir', harmony, P('E4'), 3, 58)
    s:note('timpani', 0, 1, 'E2', 102); s:note('timpani', 16, 1, 'E2', 98)
    s:note('bells', 0, 3, 'B5', 70); s:note('bells', 16, 3, 'B5', 70)
    -- --- demon-choir: the brood choir under the answer (sampled only), "oh" drones from E2 and downbeat grunts.
    A.drones(s, 'brood', harmony, P('E2'), 66, 1, 8)
    A.grunts(s, 'grunts', harmony, P('E2'), 4)
  end

  -- C: the reduced contrast: half-time, ringing chords, the theme augmented ----------------------------------
  do
    local s = new('C')
    local ch = { 'C', 'D', 'Em', 'Em', 'Am', 'G', 'B', 'B' }
    local roots = { 'C3', 'D3', 'E2', 'E2', 'A2', 'G2', 'B1', 'B1' }
    for b = 1, 8 do
      local t, r = (b - 1) * 4, P(roots[b])
      s:power('gtrL', t, 3.9, r, 104)
      for e = 0, 7 do s:power('gtrR', t + e * 0.5, 0.38, r, e == 0 and 96 or 80, true) end
      s:note('bass', t, 1.9, r - 12, 104); s:note('bass', t + 2, 1.9, r - 12, 96)
      s:hit('drums', t, 'kick', 110); s:hit('drums', t + 1.5, 'kick', 92); s:hit('drums', t + 2, 'snare', 112)
      for e = 0, 3 do s:hit('drums', t + e, 'hat', e % 2 == 0 and 78 or 64) end
      local arp = A.voicing(ch[b], P('E4'), 3)
      for e = 0, 7 do s:note('clean', t + e * 0.5, 0.9, arp[e % 3 + 1] + (e >= 4 and 12 or 0), 62) end
    end
    s:fill('drums', 8, 2, 84)
    for b = 1, 8, 2 do s:hit('cymbals', (b - 1) * 4, 'crash2', 92, 3) end
    for b = 1, 8 do for e = 1, 3 do s:hit('cymbals', (b - 1) * 4 + e, 'ride', 66) end end
    doubleKick(s, 1, 2, 4, 72); for i = 0, 7 do s:hit('drums2', 28 + 2 + i * 0.25, 'kick', 78) end
    local theme = A.seq('E5:3 G5:1 B5:2 A5:2 G5:3 F#5:1 E5:4 E5:3 G5:1 B5:2 A5:2 B5:4 D#5:4')
    s:melody('lead', theme, 100, 0.98)
    s:harmony('lead2', theme, 88, -2, key, 0.98)
    s:pads('organ', ch, P('E3'), 3, 60)
    s:pads('strings', ch, P('G3'), 4, 52)
    s:pads('choir', ch, P('E4'), 3, 60)
    for b = 1, 8, 2 do s:note('bells', (b - 1) * 4, 3, theme[(b + 1) // 2 * 2 - 1].p, 68) end
    s:note('timpani', 0, 1, 'C2', 96); s:note('timpani', 16, 1, 'A1', 96)
    s:chord('brass', 24, 3.8, A.voicing('B', P('D#3'), 3), 84)
  end

  -- D: the developed recap: double-time drive, the hook in thirds and up an octave ---------------------------
  do
    local s = new('D')
    chug8(s, riff, true)
    for b = 1, 8 do
      local t = (b - 1) * 4
      for e = 0, 7 do s:hit('drums', t + e * 0.5, 'kick', e % 2 == 0 and 108 or 92) end
      for beat = 1, 3, 2 do if not (b % 4 == 0 and beat == 3) then s:hit('drums', t + beat, 'snare', 114) end end
      hats(s, b, 88)
      if b % 4 == 0 then s:fill('drums', b, 3, 96) end
    end
    cymbals(s, 8, 2, 0.5)
    doubleKick(s, 8, 0, 4, 80)
    local first = {}
    local second = {}
    for _, n in ipairs(hook) do if n.t < 16 then first[#first + 1] = n else second[#second + 1] = n end end
    s:melody('lead', first, 106); s:melody('lead', second, 110, 0.95, 12)
    s:harmony('lead2', first, 96, -2, key); s:harmony('lead2', second, 98, 5, key)
    s:melody('brass', second, 92, 0.9, -12)
    s:pads('organ', harmony, P('E3'), 3, 66)
    s:pads('strings', harmony, P('B3'), 4, 58)
    s:pads('choir', harmony, P('E4'), 3, 66)
    for _, b in ipairs({ 1, 3, 5, 7 }) do s:note('timpani', (b - 1) * 4, 1, b == 7 and 'A1' or 'E2', 104) end
    s:note('bells', 0, 3, 'E5', 78); s:note('bells', 16, 3, 'E6', 74)
  end

  -- clear: the march flourish into E major, then a held pad (hold bar 5) --------------------------------------
  do
    local s = new('clear')
    local tune = A.seq('E5:1.5 G5:.5 B5:1 A5:1 G5:1 A5:1 B5:1 D6:1 C6:2 B5:1 A5:1 B5:1 G#5:1 E6:2')
    s:melody('lead', tune, 110, 0.96)
    for _, n in ipairs(tune) do
      s:note('fanfare', n.t, n.len * 0.94, A.diatonic(n.p, -2, A.key(n.t >= 12 and 'E major' or 'E minor')), 100)
    end
    s:melody('fanfare', tune, 96, 0.94, -12)
    local ch = { 'Em', 'C|D', 'Am|B', 'E' }
    for b, sym in ipairs(ch) do
      for _, part in ipairs(A.split(sym)) do
        local t, r = (b - 1) * 4 + part.t, A.root(part.sym, P('B1'))
        if b < 4 then
          for e = 0, part.len * 2 - 1 do
            s:power('gtrL', t + e * 0.5, 0.42, r, e == 0 and 112 or 90)
            s:power('gtrR', t + e * 0.5, 0.42, r, e == 0 and 108 or 86, true)
            s:note('bass', t + e * 0.5, 0.45, r - 12, 104)
          end
        else
          s:power('gtrL', t, 3.9, r, 116); s:power('gtrR', t, 3.9, r, 112, true); s:note('bass', t, 3.9, r - 12, 112)
        end
      end
    end
    s:pads('organ', ch, P('E3'), 3, 74)
    s:pads('strings', ch, P('G#3'), 4, 66)
    s:pads('choir', ch, P('E4'), 3, 70)
    s:pads('fanfare', ch, P('G3'), 3, 92)
    for b = 1, 3 do
      local t = (b - 1) * 4
      s:hit('drums', t, 'kick', 112); s:hit('drums', t + 2, 'kick', 104)
      for e = 0, 7 do s:hit('drums', t + e * 0.5, 'snare', e % 4 == 0 and 112 or e % 2 == 0 and 96 or 78) end
      s:hit('cymbals', t, 'crash', 108, 2)
    end
    s:hit('drums', 12, 'kick', 118); s:hit('cymbals', 12, 'crash', 116, 4); s:hit('cymbals', 12, 'china', 100, 2)
    s:roll('timpani', 13, 3, P('E2'), 60, 104)
    s:note('timpani', 12, 1, 'E2', 116)
    s:note('bells', 12, 4, 'E5', 84); s:note('bells', 12, 4, 'B5', 74)
    -- hold (bar 5): a soft E major pad that can repeat through the travel.
    s:chord('organ', 16, 4, A.voicing('E', P('E3'), 3), 50)
    s:chord('strings', 16, 4, A.voicing('E', P('G#3'), 4), 44)
    s:chord('choir', 16, 4, A.voicing('E', P('B3'), 3), 44)
    s:note('bass', 16, 4, 'E1', 70)
  end

  -- storm (8 bars loop, Stormfront): the sector band's half-time storm in Krybor's key (songs/sector.lua).
  local sector = require 'songs.sector'
  sector.storm(A, new('storm'), sector.worlds.k, key)

  return S
end
