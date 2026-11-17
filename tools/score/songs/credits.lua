-- The credits (the title page's CREDITS): G major at 72 BPM (bar 160 000 samples, 3.333 s), the relative major of the
-- overture's E minor, so the move from the title music shares its notes. Original writing from the campaign theme
-- (art/music/campaign.json; degrees 1-3-5-4, rhythm 1.5/.5/1/1, the same line the coda sings) as a slow, warm
-- reprise for reading: no ukulele (that is the beach's voice), no power chords, no crash.
--   dawn  (4 bars, tail into drift): the arpeggios and pads, the theme's first notes on bells, the bass from bar 3;
--                                     ends on D.
-- Levels: written mezzo-forte (velocities 52-100). The game's mix keeps every section within 2 LU after its trim
-- (tools/mix_meter/trim.mjs), so calm comes from the sparse texture and the slow grid, not from a low level.
--   drift (16-bar loop): clean-guitar arpeggios throughout; bars 1-8 the theme on bells over strings, bars 9-16 the
--                        theme an octave lower on strings with a soft choir and brushed time; ends on D so the loop
--                        turns back to G.
return function(A, spec, seed)
  local key = A.key(spec.key)
  local P = A.pitch
  local theme = '1:1.5 3:.5 5:1 4:1 3:2 2:1 1:1 5:1.5 4:.5 3:1 2:1 1:4 '
    .. '1:1.5 3:.5 5:1 4:1 5:1 6:1 5:2 4:1 3:1 2:1 7:1 1:4'
  -- Slow clean arpeggio in eighths: root, fifth, octave, tenth and back (velocities stay low: a reading bed).
  local function arpeggio(s, ch, v, t0)
    for b, sym in ipairs(ch) do
      for _, part in ipairs(A.split(sym)) do
        local r = A.root(part.sym, P('G2'))
        local _, iv = A.chord(part.sym)
        local shape = { 0, 7, 12, 12 + iv[2], 19, 12 + iv[2], 12, 7 }
        for e = 0, part.len * 2 - 1 do
          s:note('clean', (t0 or 0) + (b - 1) * 4 + part.t + e * 0.5, 0.9, r + shape[e % 8 + 1], v + (e % 2 == 0 and 4 or 0))
        end
      end
    end
  end
  local function bassline(s, ch, v, from)
    for b, sym in ipairs(ch) do
      if b >= (from or 1) then
        for _, part in ipairs(A.split(sym)) do s:note('bass', (b - 1) * 4 + part.t, part.len - 0.1, A.root(part.sym, P('G1')), v) end
      end
    end
  end

  local S = {}
  do
    local s = A.section('dawn', spec.sections.dawn.bars, seed + 971)
    local ch = { 'G', 'C', 'Em', 'D' }
    arpeggio(s, ch, 76)
    s:pads('strings', ch, P('B3'), 3, 90)
    s:pads('organ', ch, P('G3'), 3, 76)
    s:pads('choir', ch, P('D4'), 3, 66)
    s:melody('bells', A.line(key, 5, '1:1.5 3:.5 5:2 R:4 5:1.5 4:.5 3:2 R:2 2:4'), 86, 1.2)
    bassline(s, ch, 90, 3)
    S.dawn = s
  end
  do
    local s = A.section('drift', spec.sections.drift.bars, seed + 973)
    local first = { 'G', 'G', 'C', 'D', 'G', 'Em', 'C|D', 'G' }
    local second = { 'Em', 'Em', 'C', 'D', 'G', 'Em', 'Am|D', 'D' }
    local ch = {}
    for _, c in ipairs(first) do ch[#ch + 1] = c end
    for _, c in ipairs(second) do ch[#ch + 1] = c end
    arpeggio(s, ch, 80)
    s:pads('strings', first, P('B3'), 3, 80)
    s:pads('organ', ch, P('G3'), 3, 66)
    -- The theme: bells call it (bars 1-8), strings sing it an octave lower (bars 9-16) with bells answering on the
    -- chord's third once a bar.
    s:melody('bells', A.line(key, 5, theme), 90, 1.1)
    s:melody('strings', A.line(key, 4, theme, 32), 86, 0.98)
    for b, sym in ipairs(second) do
      s:note('bells', 32 + (b - 1) * 4 + 2, 1.5, A.voicing(A.split(sym)[1].sym, P('G5'), 2)[2], 64)
    end
    -- A soft choir under the strings' theme: one chord held over each pair of bars.
    for i, sym in ipairs({ 'Em', 'C', 'G', 'D' }) do s:chord('choir', 32 + (i - 1) * 8, 7.9, A.voicing(sym, P('E4'), 3), 60) end
    bassline(s, ch, 100)
    -- Brushed time from bar 9: a soft kick on 1, rim on 3, pedal hats on 2 and 4.
    for b = 9, 16 do
      local t = (b - 1) * 4
      s:hit('drums', t, 'kick', 76); s:hit('drums', t + 2, 'rim', 66)
      s:hit('drums', t + 1, 'pedal', 56); s:hit('drums', t + 3, 'pedal', 52)
    end
    S.drift = s
  end
  return S
end
