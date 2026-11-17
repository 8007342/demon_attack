-- The overture (the title page): E minor, 120 BPM. Original writing from the campaign theme (art/music/campaign.json:
-- degrees 1-3-5-4, rhythm 1.5/.5/1/1) over Krybor's harmony, so START leads straight into the first sector's key
-- (bridge menu-k). An 8-bar loop: clean arpeggios and a pad, the theme on bells, then on lead with the band in
-- half-time; it ends on the dominant so the loop and the bridge both resolve.
return function(A, spec, seed)
  local key = A.key(spec.key)
  local P = A.pitch
  local s = A.section('overture', spec.sections.overture.bars, seed + 777)
  local ch = { 'Em', 'Em', 'C', 'D', 'Em', 'C', 'Am|D', 'B' }
  -- Clean arpeggios in eighths (root, fifth, octave, tenth), the whole loop.
  for b, sym in ipairs(ch) do
    for _, part in ipairs(A.split(sym)) do
      local r = A.root(part.sym, P('E3'))
      local _, iv = A.chord(part.sym)
      local shape = { 0, 7, 12, 12 + iv[2], 19, 12 + iv[2], 12, 7 }
      for e = 0, part.len * 2 - 1 do s:note('clean', (b - 1) * 4 + part.t + e * 0.5, 0.9, r + shape[e % 8 + 1], 60 + (b > 4 and 6 or 0)) end
    end
  end
  s:pads('organ', ch, P('E3'), 3, 56)
  s:pads('strings', ch, P('B3'), 3, 50)
  -- The theme: bells call it (bars 1-4), the lead answers with the band (bars 5-8).
  s:melody('bells', A.line(key, 5, '1:1.5 3:.5 5:1 4:1 3:2 2:1 1:1 8:1.5 7:.5 6:1 5:1 4:2 2:2'), 66, 1.3)
  local answer = A.line(key, 4, '1:1.5 3:.5 5:1 4:1 5:1 7:1 8:2 8:1 7:1 6:1 5:1 5:2 7#:2', 16)
  s:melody('lead', answer, 92, 0.97, 12)
  s:harmony('lead2', answer, 80, -2, key, 0.97)
  s:pads('choir', { 'Em', 'C', 'Am|D', 'B' }, P('E4'), 3, 54, 16)
  -- The band: a soft bass from bar 3, half-time drums and ringing guitars from bar 5.
  for b, sym in ipairs(ch) do
    local t = (b - 1) * 4
    for _, part in ipairs(A.split(sym)) do
      local r = A.root(part.sym, P('B1'))
      if b >= 3 then s:note('bass', t + part.t, part.len - 0.1, r - 12, 84 + (b > 4 and 10 or 0)) end
      if b >= 5 then
        s:power('gtrL', t + part.t, part.len - 0.1, r, 98)
        s:power('gtrR', t + part.t, part.len - 0.1, r, 94)
      end
    end
    if b >= 5 then
      s:hit('drums', t, 'kick', 100); s:hit('drums', t + 1.5, 'kick', 84); s:hit('drums', t + 2, 'snare', 98)
      for e = 0, 3 do s:hit('cymbals', t + e, 'ride', e % 2 == 0 and 72 or 60) end
    elseif b >= 3 then
      s:hit('drums', t, 'kick', 80); s:hit('drums', t + 2, 'rim', 70)
    end
  end
  s:hit('cymbals', 16, 'crash', 96, 2)
  s:fill('drums', 8, 3, 80)
  s:note('timpani', 16, 1.5, 'E2', 90); s:roll('timpani', 30, 2, P('B1'), 50, 92)
  s:chord('brass', 28, 3.8, A.voicing('B', P('D#3'), 3), 76)
  return { overture = s }
end
