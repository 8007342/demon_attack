#!/usr/bin/env lua
-- rigkit: rebuild one hull of a family from its committed picks, no GPU (the offline path).
-- rig (rig.py) -> fit each picked raw to the rig frame and symmetrise (rigsheet fit) ->
-- drop texels of geometry that left in S3 (maskdiff) -> projection bake (bake.py) ->
-- finish every layer and wreck at its class density + manifest (bakefinish) -> budget
-- [-> sheets]. Run from the repository root:
--   lua tools/rigkit/bake_family.lua art/families/alien-carriers.json carrier1-thorn [--sheets PREFIX]
-- Picks come from FAMILY .selected[HULL] = {S0, S1, S2, S3 (paths under .selected.root), sym}.
-- Outputs: ~/.cache/tillandsias-project/rigkit/<family>/{rig,bake,in}/...
local family, hull = assert(arg[1], "usage: bake_family.lua FAMILY.json HULL [--sheets PREFIX]"), assert(arg[2])
local home = os.getenv("HOME")
local name = family:match("([^/]+)%.json$")
local base = home .. "/.cache/tillandsias-project/rigkit/" .. name
local rig, bake, inp = base .. "/rig", base .. "/bake", base .. "/in"
local sheet = home .. "/.cache/tillandsias-project/rigsheet"
local threads = os.getenv("RIGKIT_THREADS") or "8"

local function sh(cmd)
  io.stderr:write("+ " .. cmd .. "\n")
  local ok = os.execute(cmd)
  if not (ok == true or ok == 0) then error("failed: " .. cmd) end
end
local function capture(cmd)
  local p = assert(io.popen(cmd)); local s = p:read("a"); p:close(); return (s:gsub("%s+$", ""))
end
local function pick(k)
  return capture(("jq -r '.selected[%q].%s // empty' %s"):format(hull, k, family))
end

local t0 = os.time()
local py = capture("lua tools/boss_rig/setup_bpy.lua")
sh("cd tools/rigsheet && go build -o " .. sheet .. " .")
sh(("mkdir -p %s %s %s"):format(rig, bake, inp))
-- RIGKIT_REUSE_RIG=1 keeps an existing rig of this hull (rendered from the same family JSON)
if not (os.getenv("RIGKIT_REUSE_RIG") == "1" and io.open(rig .. "/" .. hull .. "/rig.json")) then
  sh(("%s -I tools/rigkit/rig.py %s %s --hulls %s --threads %s"):format(py, family, rig, hull, threads))
end
local root = capture(("jq -r '.selected.root // \"\"' %s"):format(family))
local side = pick("sym"); if side == "" then side = "left" end
local geo = {S0 = "S0", S1 = "S0", S2 = "S2", S3 = "S3"}
local args = {}
for _, s in ipairs({"S0", "S1", "S2", "S3"}) do
  local p = pick(s)
  if p ~= "" then
    local out = ("%s/%s-%s-fit.png"):format(inp, hull, s)
    sh(("%s fit %s %s %s %s p45_y+00 %s %s"):format(sheet, root .. p, rig, hull, geo[s], out, side))
    -- drop texels whose geometry left (S2: scales and emitter crystals shed; S3: the first
    -- detach group), so the bake fills them from the geometry instead of painting ghosts
    if s == "S2" then
      sh(("%s maskdiff %s %s %s S0 S2 %s"):format(sheet, out, rig, hull, out))
    elseif s == "S3" then
      sh(("%s maskdiff %s %s %s S0 S3 %s"):format(sheet, out, rig, hull, out))
    end
    args[#args + 1] = s .. "=" .. out
  end
end
assert(#args > 0, "no picks for " .. hull .. " in " .. family)
sh(("%s -I tools/rigkit/bake.py %s %s %s %s %s --threads %s"):format(py, family, rig, bake, hull, table.concat(args, ","), threads))
-- the belly (boss-grandeur Overflight): one finished underside image, its own rig frame, never in the
-- resident hull budget (it is drawn before the fight, at <= 0.55 opacity, so 0.5 px per unit)
local belly = pick("belly")
if belly ~= "" then
  local rb = base .. "/rig-belly"
  if not (os.getenv("RIGKIT_REUSE_RIG") == "1" and io.open(rb .. "/" .. hull .. "/rig.json")) then
    sh(("%s -I tools/rigkit/rig.py %s %s --hulls %s --views belly --envelope off --stages S0 --passes clay,hint --threads %s"):format(py, family, rb, hull, threads))
  end
  local bt = ("p%02d_y+00"):format(tonumber(capture(("jq -r \x27.views.belly[0]\x27 %s"):format(family))))
  sh(("%s finish %s %s %s S0 %s 0.5 %s/%s/fin_belly.png"):format(sheet, root .. belly, rb, hull, bt, bake, hull))
end
sh(("%s bakefinish %s %s %s"):format(sheet, bake, rig, hull))
sh(("%s budget %s %s %s"):format(sheet, bake, rig, hull))
if arg[3] == "--sheets" then
  local pre = assert(arg[4], "--sheets needs a PREFIX, e.g. art/contact/boss-carrier-v2-t1-thorn")
  sh(("%s views %s %s %s %s-views.png"):format(sheet, bake, rig, hull, pre))
  sh(("%s stages %s %s %s %s-stages.png"):format(sheet, bake, rig, hull, pre))
end
io.stderr:write(("bake_family %s %s: %d s\n"):format(name, hull, os.time() - t0))
