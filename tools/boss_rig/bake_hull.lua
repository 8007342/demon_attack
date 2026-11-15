#!/usr/bin/env lua
-- boss-hero-assets: rebuild one hull's projected view set from the committed
-- picks, no GPU (task 5.3's offline path). Steps: rig (build.py) -> fit each
-- picked raw to the rig frame (boss_sheet finish) -> drop texels of geometry
-- that left in S3 (maskdiff) -> symmetrise (sym) -> projection bake
-- (project_bake.py) -> finish every view, layer and wreck (bakefinish) -> B2
-- sheets. Run from the repository root:
--   lua tools/boss_rig/bake_hull.lua frigate [--sheets]
local hull = assert(arg[1], "usage: bake_hull.lua HULL [--sheets]")
local home = os.getenv("HOME")
local cache = home .. "/.cache/tillandsias-project"
local rig, bake = cache .. "/boss-rig", cache .. "/boss-bake"
local sheet = cache .. "/boss_sheet"

local function sh(cmd)
  io.stderr:write("+ " .. cmd .. "\n")
  local ok = os.execute(cmd)
  if not (ok == true or ok == 0) then error("failed: " .. cmd) end
end
local function capture(cmd)
  local p = assert(io.popen(cmd)); local s = p:read("a"); p:close(); return (s:gsub("%s+$", ""))
end

local py = capture("lua tools/boss_rig/setup_bpy.lua")
sh("cd tools/boss_sheet && go build -o " .. sheet .. " .")
-- picks from the grammar (jq keeps this script free of a JSON library)
local function pick(k) return capture(("jq -r '.selected.%s.%s // empty' art/families/boss-hulls.json"):format(hull, k)) end
local src = "art/sprites/sources/boss-selected/" .. hull .. "/"
local side = pick("sym"); if side == "" then side = "left" end
sh(("%s -I tools/boss_rig/build.py %s --hulls %s"):format(py, rig, hull))
sh("mkdir -p " .. bake .. "/in")
local geo = {S0 = "S0", S1 = "S0", S2 = "S2", S3 = "S3"}
local args = {}
for _, s in ipairs({"S0", "S1", "S2", "S3"}) do
  local p = pick(s)
  if p ~= "" then
    local base = ("%s/in/%s-%s"):format(bake, hull, s)
    sh(("%s finish %s %s %s %s p45_y+00 %s.png --no-quant"):format(sheet, src .. p, rig, hull, geo[s], base))
    if s == "S3" then
      sh(("%s maskdiff %s-fit.png %s %s S2 S3 %s-fit.png"):format(sheet, base, rig, hull, base))
    end
    sh(("%s sym %s-fit.png %s %s %s-sym.png %s"):format(sheet, base, rig, hull, base, side))
    args[#args + 1] = s .. "=" .. base .. "-sym.png"
  end
end
sh(("%s -I tools/boss_rig/project_bake.py %s %s %s %s"):format(py, rig, bake, hull, table.concat(args, ",")))
for _, s in ipairs({"S0", "S1", "S2", "S3", "wrecks"}) do
  sh(("%s bakefinish %s %s %s %s"):format(sheet, bake, rig, hull, s))
end
sh(("%s bakebudget %s %s %s"):format(sheet, bake, rig, hull))
if arg[2] == "--sheets" then
  sh(("%s views %s %s %s art/contact/boss-pilot-views.png"):format(sheet, bake, rig, hull))
  sh(("%s stages %s %s %s art/contact/boss-pilot-stages.png"):format(sheet, bake, rig, hull))
end
