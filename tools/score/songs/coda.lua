-- The coda (the ending's beach and the credits): F major at 95 BPM, half the carrier tempo on the carrier grid's
-- doubled bar (design §4.4: bar 121 264 samples, 2.526 s). The campaign theme (art/music/campaign.json; its
-- `ending` asks for a slow original theme reprise for beach and credits) on the ukulele, then the warm reprise.
-- The ukulele is its own track (`uke`, role uke): an oscillator pluck today, the sampled ukulele's zone when the
-- bank has one (a gap: design §12.7).
return function(A, spec, seed)
  local key = A.key(spec.key)
  local P = A.pitch
  -- Re-entrant ukulele shapes (G4 C4 E4 A4 tuning), three strings sounding per strum.
  local shapes = { F = { 'C4', 'F4', 'A4' }, C = { 'C4', 'E4', 'G4' }, Bb = { 'D4', 'F4', 'Bb4' }, Dm = { 'D4', 'F4', 'A4' },
    Gm = { 'D4', 'G4', 'Bb4' }, A = { 'C#4', 'E4', 'A4' } }
  -- The island strum: down, down-up, up-down-up (onsets in beats).
  local strum = { { 0, 104 }, { 1, 92 }, { 1.5, 78 }, { 2.5, 80 }, { 3, 90 }, { 3.5, 76 } }
  local function strums(s, ch, v)
    for b, sym in ipairs(ch) do
      local parts = A.split(sym)
      for _, hit in ipairs(strum) do
        local chord
        for _, part in ipairs(parts) do if hit[1] >= part.t - 1e-9 then chord = part.sym end end
        for i, p in ipairs(shapes[chord]) do s:note('uke', (b - 1) * 4 + hit[1], 0.45, p, hit[2] + v - (i - 1) * 3) end
      end
    end
  end
  local ch = { 'F', 'F', 'Bb', 'C', 'F', 'Dm', 'Bb|C', 'F' }
  local theme = '1:1.5 3:.5 5:1 4:1 3:2 2:1 1:1 5:1.5 4:.5 3:1 2:1 1:4 '
    .. '1:1.5 3:.5 5:1 4:1 5:1 6:1 5:2 4:1 3:1 2:1 7:1 1:4'

  local S = {}
  do
    -- ukulele (8 bars, then the reprise): the theme on the ukulele's top string over its own strum.
    local s = A.section('ukulele', spec.sections.ukulele.bars, seed + 951)
    strums(s, ch, -8)
    s:melody('uke', A.line(key, 5, theme), 100, 0.9)
    s:pads('organ', ch, P('F3'), 3, 40)
    for b, sym in ipairs(ch) do
      s:note('bass', (b - 1) * 4, 1.9, A.root(sym:match('^[^|]+'), P('F1')), 70)
      s:note('bass', (b - 1) * 4 + 2, 1.9, A.root(sym:match('[^|]+$'), P('C2')), 64)
    end
    for b = 1, 8, 2 do s:note('bells', (b - 1) * 4, 3, 'A5', 56) end
    S.ukulele = s
  end
  do
    -- reprise (8 bars loop): the credits, warm: the theme on clean guitar and bells, strings, a soft band.
    local s = A.section('reprise', spec.sections.reprise.bars, seed + 953)
    local ch2 = { 'F', 'Dm', 'Bb', 'C', 'F', 'Gm|A', 'Bb|C', 'F' }
    strums(s, ch2, -16)
    local tune = A.line(key, 5, theme)
    s:melody('clean', tune, 82, 0.95)
    s:harmony('bells', tune, 56, -2, key, 1)
    s:pads('strings', ch2, P('A3'), 3, 54)
    s:pads('organ', ch2, P('F3'), 3, 44)
    s:pads('choir', { 'Bb|C', 'F' }, P('C4'), 3, 46, 24)
    for b, sym in ipairs(ch2) do
      local t = (b - 1) * 4
      s:note('bass', t, 1.9, A.root(sym:match('^[^|]+'), P('F1')), 76)
      s:note('bass', t + 2, 1.9, A.root(sym:match('[^|]+$'), P('C2')), 70)
      s:hit('drums', t, 'kick', 74); s:hit('drums', t + 2, 'rim', 66); s:hit('drums', t + 2.5, 'kick', 62)
      for e = 0, 7 do s:hit('drums', t + e * 0.5, 'pedal', e % 2 == 0 and 54 or 44) end
    end
    S.reprise = s
  end
  return S
end
