-- Bridges between songs (design §3.1, art/music/campaign.json `bridges`): a sparse sustained pivot, no drums while
-- the tempo changes, the next song's grid starting on the bridge's last bar line. Each bridge holds one common
-- tone (the pedal) through the campaign's pivot chords and ends on the destination's dominant, so the next song's
-- arrival lands as a resolution. Written at the source song's tempo (its grid is the song's barSamples).
local pivots = {
  -- id = { pedal, chords as { beat, beats, symbol }, the theme's fragment in degrees of the destination key }
  ['menu-k'] = { pedal = 'E3', chords = { { 0, 2, 'Em' }, { 2, 2, 'B7' } }, line = '5:1 3:1 4:1 7#:1' },
  ['k-r'] = { pedal = 'E4', chords = { { 0, 2, 'Em' }, { 2, 2, 'G' }, { 4, 4, 'A7' } }, line = '2:1.5 4:.5 6:1 5:1 5:4' },
  ['r-e'] = { pedal = 'B3', chords = { { 0, 2, 'Bm' }, { 2, 2, 'C' }, { 4, 4, 'B7' } }, line = '5:1.5 7:.5 9:1 8:1 7#:4' },
  ['e-h'] = { pedal = 'G3', chords = { { 0, 2, 'Em' }, { 2, 2, 'G' }, { 4, 4, 'G7' } }, line = '5:2 5:2 5:1 4:1 2:1 7#:1' },
  ['h-c'] = { pedal = 'C4', chords = { { 0, 2, 'Cm' }, { 2, 2, 'Db' }, { 4, 4, 'C7' } }, line = '5:1.5 6:.5 5:1 4:1 5:4' },
  ['c-k'] = { pedal = 'C4', pedalBeats = 4, chords = { { 0, 2, 'F' }, { 2, 2, 'C' }, { 4, 4, 'B7' } }, line = '6:2 5:2 7#:4' },
}

return function(A, spec, seed, songId)
  local P = A.pitch
  local key = A.key(spec.key)
  local pivot = assert(pivots[songId], 'no pivot for bridge ' .. tostring(songId))
  local bars = spec.sections.pivot.bars
  local s = A.section('pivot', bars, seed + songId:byte(1) * 17 + #songId)
  local total = bars * 4
  -- The pedal: organ and the low strings hold the common tone through every chord.
  local held = (pivot.pedalBeats or total) - 0.05
  s:note('organ', 0, held, pivot.pedal, 70)
  s:note('strings', 0, held, P(pivot.pedal) - 12, 60)
  for i, c in ipairs(pivot.chords) do
    local t, len, sym = c[1], c[2], c[3]
    local swell = 52 + i * 10
    s:chord('choir', t, len - 0.05, A.voicing(sym, P('E4') - 2, 3), swell)
    s:chord('strings', t, len - 0.05, A.voicing(sym, P('G3'), 4), swell - 4)
    s:chord('brass', t, len - 0.05, A.voicing(sym, P('D3'), 3), swell - 10)
    s:note('bass', t, len - 0.1, A.root(sym, P('E1')), 70 + i * 8)
    s:power('gtrL', t, len - 0.1, A.root(sym, P('B1')), 70 + i * 8)
    s:power('gtrR', t, len - 0.1, A.root(sym, P('B1')), 66 + i * 8)
  end
  -- The destination's theme, a fragment on bells and the clean guitar.
  s:melody('bells', A.line(key, 5, pivot.line), 64, 1.2)
  s:melody('clean', A.line(key, 4, pivot.line), 58, 0.95)
  -- No drums: a timpani swell on the dominant into the next downbeat.
  local last = pivot.chords[#pivot.chords]
  s:roll('timpani', math.max(0, total - 2), 2, A.root(last[3], P('B1')), 40, 96)
  return { pivot = s }
end
