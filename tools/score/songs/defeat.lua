-- The defeat (game over): 120 BPM. The aliens' twisted triumphant march in E Phrygian dominant
-- (tools/music_motifs.py ALIEN and ALIEN_ROOTS) after the cackle, a falling chromatic laugh over the gloat's
-- tritone (the accent's organ cluster and choir slide). Chromatic by design.
return function(A, spec, seed)
  local P = A.pitch
  local S = {}
  do
    local s = A.section('cackle', spec.sections.cackle.bars, seed + 661)
    -- The laugh: short falling notes in two bursts, the choir an octave below.
    local laugh = A.seq('E5:.25 D#5:.25 D5:.25 C#5:.5 R:.25 C5:.25 B4:.25 Bb4:.25 A4:.75 R:1 '
      .. 'G#5:.25 G5:.25 F#5:.25 F5:.5 R:.25 E5:.25 D#5:.25 D5:.25 C#5:.25 C5:.25 B4:.25 Bb4:.25 A4:.25 G#4:.5')
    s:melody('lead', laugh, 104, 0.9)
    s:melody('choir', laugh, 80, 0.9, -12)
    s:chord('organ', 0, 7.9, { P('E3'), P('F3'), P('Bb3') }, 78)
    s:chord('brass', 0, 3.9, { P('E3'), P('Bb3') }, 84)
    s:chord('brass', 4, 3.9, { P('E3'), P('G#3'), P('B3') }, 92)
    s:note('bass', 0, 3.9, 'E1', 100); s:note('bass', 4, 3.9, 'E1', 106)
    s:note('timpani', 0, 1.5, 'E2', 112); s:roll('timpani', 5, 3, P('B1'), 50, 110)
    s:hit('cymbals', 0, 'china', 104, 2)
    s:power('gtrL', 0, 1.9, P('E2'), 112); s:power('gtrR', 0, 1.9, P('E2'), 108)
    s:power('gtrL', 2, 1.9, P('F2'), 104); s:power('gtrR', 2, 1.9, P('F2'), 100)
    S.cackle = s
  end
  do
    local s = A.section('alienwin', spec.sections.alienwin.bars, seed + 663)
    local tune = A.seq('E5:1 F5:1 G#5:2 B5:1 C6:1 B5:1 G#5:1 A5:1.5 G#5:.5 F5:1 E5:1 F5:4 '
      .. 'E5:1 F5:1 G#5:2 D6:1 C6:1 B5:1 C6:1 B5:1 A5:1 G#5:1 F5:1 E5:4')
    s:melody('lead', tune, 104, 0.95)
    s:melody('choir', tune, 84, 0.95, -12)
    local roots = { 'E', 'E', 'A', 'F', 'E', 'D', 'F', 'E' }
    for b, root in ipairs(roots) do
      local t = (b - 1) * 4
      local r = P(root .. '2')
      for e = 0, 7 do s:power('gtrL', t + e * 0.5, 0.45, r, e == 0 and 110 or 92); s:power('gtrR', t + e * 0.5, 0.45, r, e == 0 and 106 or 88) end
      s:note('bass', t, 3.9, r >= 40 and r - 12 or r, 100)
      s:chord('organ', t, 3.9, A.voicing(root .. (root == 'E' and '' or 'm'), P('E4'), 3), 62)
      s:note('timpani', t, 0.9, r, 100); s:note('timpani', t + 2, 0.9, r + 7, 90)
      -- The march: kick on one and three, snare on two and four with a drag, a crash every second bar.
      s:hit('drums', t, 'kick', 108); s:hit('drums', t + 2, 'kick', 102)
      s:hit('drums', t + 1, 'snare', 104); s:hit('drums', t + 3, 'snare', 108); s:hit('drums', t + 3.75, 'snare', 82)
      for e = 0, 7 do s:hit('drums', t + e * 0.5, 'hat', e % 2 == 0 and 76 or 60) end
      if b % 2 == 1 then s:hit('cymbals', t, 'crash', 104, 2) end
    end
    s:fill('drums', 8, 3, 90)
    S.alienwin = s
  end
  return S
end
