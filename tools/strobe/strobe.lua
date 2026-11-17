-- fire-rate-tune: the anti-strobe tables of openspec/changes/fire-rate-tune/design.md.
--   lua tools/strobe/strobe.lua            the tables for the current constants
--   lua tools/strobe/strobe.lua --before   the same for the constants before the change
-- The model steps at a fixed h = 1/60 s and the scene draws its state without
-- interpolation, rounding each projectile's position to whole logical units
-- (ship_painter.dart paintShot). So, per display rate f (Hz):
--   D_f   = v / f              displacement per displayed frame (at 120 Hz the
--                              model moves every other frame: D = v/60, then 0)
--   S     = v * n * h          stream spacing, n = fire interval in model steps
--   rho_f = D_f / S            correspondence ratio: < 1/2 reads forward, 1/2 is
--                              ambiguous, (1/2, 1) runs backwards, 1 stands still
--   beat_f = f * dist(D_f, Z)  how often the rounded step changes length (a
--                              one-unit hitch); 0 when D_f is a whole number
local before = arg[1] == "--before"
local h = 1 / 60

local function dist(x) return math.abs(x - math.floor(x + 0.5)) end
local function beat(d, f)
  -- The rounded positions advance by floor(d) or ceil(d): the pattern of the
  -- longer step repeats at f * dist(d, Z) (exactly, for rational d).
  local fr = dist(d)
  return fr < 1e-9 and 0 or f * fr
end

-- Interval pattern of `_fire += T; _fire -= h; fire when <= 0`.
local function intervals(T, shots)
  local fire, out, steps = 0, {}, 0
  while #out < shots do
    fire = fire - h; steps = steps + 1
    if fire <= (before and 0 or 1e-9) then
      out[#out + 1] = steps; steps = 0
      fire = (before and fire or math.max(0, fire)) + T
    end
  end
  table.remove(out, 1)
  return out
end

local player
if before then
  player = {
    { "base", 390, 0.23 }, { "rapid", 390, 0.105 }, { "spread side", 370, 0.23 },
  }
else
  player = {
    { "base", 480, 18 * h }, { "rapid", 480, 8 * h }, { "spread side", 420, 18 * h },
  }
end

print(("# Player streams (%s)"):format(before and "before" or "after"))
print("| Stream | v u/s | interval steps | S u | D60 | D30 | rho60 | rho30 | beat60 Hz | beat30 Hz | on screen |")
print("|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|")
for _, p in ipairs(player) do
  local name, v, T = p[1], p[2], p[3]
  local iv = intervals(T, 12)
  local lo, hi = math.huge, 0
  for _, n in ipairs(iv) do lo = math.min(lo, n); hi = math.max(hi, n) end
  local steps = lo == hi and tostring(lo) or table.concat(iv, ",", 1, 10)
  local S = v * T
  print(("| %s | %d | %s | %.1f | %.2f | %.2f | %.3f | %.3f | %.1f | %.1f | %.1f |"):format(
    name, v, steps, S, v / 60, v / 30, v / 60 / S, v / 30 / S,
    beat(v / 60, 60), beat(v / 30, 30), 474 / S))
end

-- Hostile shots: vy = base * speed, speed = (1 + 0.04 * min(route, 4)) * rate.
local rates = { easy = 0.9, normal = 1.0, hard = 1.05 }
local kinds = {
  { "ordinary L1", 113 }, { "ordinary L2", 126 }, { "ordinary L3", 139 },
  { "ordinary L4", 152 }, { "ordinary L5", 165 }, { "elite fan", 130 },
  { "carrier fan", 120 }, { "sentinel", 240 },
}
local q = nil -- the hostile speed grid (u/s) after the change (ArcadeModel.hostileSpeedGrid)
if not before then q = tonumber(os.getenv("STROBE_QUANTUM") or "15") end
print()
print(("# Hostile shots (%s): worst 60/30 Hz rounding beat over routes 0-4"):format(before and "before" or "after"))
print("| Kind | mode | vy range u/s | beat60 Hz (min-max) | beat30 Hz (min-max) | max change % |")
print("|---|---|---|---|---|---:|")
for _, k in ipairs(kinds) do
  for _, mode in ipairs({ "easy", "normal", "hard" }) do
    local vlo, vhi, b6lo, b6hi, b3lo, b3hi, dmax = math.huge, 0, math.huge, 0, math.huge, 0, 0
    for r = 0, 4 do
      local v0 = k[2] * (1 + 0.04 * r) * rates[mode]
      local v = q and q * math.floor(v0 / q + 0.5) or v0
      dmax = math.max(dmax, math.abs(v / v0 - 1))
      vlo, vhi = math.min(vlo, v), math.max(vhi, v)
      local b6, b3 = beat(v / 60, 60), beat(v / 30, 30)
      b6lo, b6hi = math.min(b6lo, b6), math.max(b6hi, b6)
      b3lo, b3hi = math.min(b3lo, b3), math.max(b3hi, b3)
    end
    print(("| %s | %s | %.0f-%.0f | %.1f-%.1f | %.1f-%.1f | %.1f |"):format(
      k[1], mode, vlo, vhi, b6lo, b6hi, b3lo, b3hi, dmax * 100))
  end
end

-- How many hostile (kind, mode, route) combinations hitch slowly: a beat
-- above 0 and below 15 Hz, where a one-unit hitch is easiest to see.
local slow, total = 0, 0
for _, k in ipairs(kinds) do
  for _, mode in ipairs({ "easy", "normal", "hard" }) do
    for r = 0, 4 do
      local v0 = k[2] * (1 + 0.04 * r) * rates[mode]
      local v = q and q * math.floor(v0 / q + 0.5) or v0
      for _, f in ipairs({ 60, 30 }) do
        local b = beat(v / f, f)
        total = total + 1
        if b > 1e-9 and b < 15 - 1e-9 then slow = slow + 1 end
      end
    end
  end
end
print()
print(("Hostile combinations (x 60/30 fps) with a 0-15 Hz hitch: %d of %d"):format(slow, total))
