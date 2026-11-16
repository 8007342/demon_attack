#!/usr/bin/env lua
-- rigkit: rebuild the pose atlas of an articulated family (rigkit "articulation") from its
-- committed hero pick, no GPU. rig (rig.py, hero view, clay per pose) -> fit the picked raw to
-- the rig frame (rigsheet fit, optionally registered by the silhouette box) -> projection bake
-- of every pose (bake.py --poses 1) -> finish, trim and pack (rigsheet poseatlas) [-> sheet].
-- Run from the repository root:
--   lua tools/rigkit/bake_poses.lua FAMILY.json HULL --texel 1.0 --cols 5 --atlas OUT.png
--       [--dart OUT.dart CLASS] [--sheet OUT.png "TITLE"]
-- The pick comes from FAMILY .selected[HULL] = {S0 (path under .selected.root), sym, register}.
-- Work files: ~/.cache/tillandsias-project/rigkit/<family>/{rig,bake,in}/...
local family, hull = assert(arg[1], "usage: bake_poses.lua FAMILY.json HULL --atlas OUT.png ..."), assert(arg[2])
local opt, i = {}, 3
while arg[i] do
  local k = assert(arg[i]:match("^%-%-(.+)$"), "bad option " .. arg[i])
  if k == "dart" or k == "sheet" then opt[k] = {arg[i + 1], arg[i + 2]}; i = i + 3
  else opt[k] = arg[i + 1]; i = i + 2 end
end
assert(opt.atlas, "--atlas OUT.png is required")
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
local hero = capture(("jq -r '\"p\" + (.views.hero[0]|tostring) + \"_y+\" + (.views.hero[1]|tostring|if length < 2 then \"0\" + . else . end)' %s"):format(family))
sh(("%s -I tools/rigkit/rig.py %s %s --hulls %s --stages S0 --views hero --passes clay,hint,z --pose-passes clay --threads %s"):format(py, family, rig, hull, threads))
local root = capture(("jq -r '.selected.root // \"\"' %s"):format(family))
local s0 = assert(pick("S0") ~= "" and pick("S0"), "no S0 pick for " .. hull .. " in " .. family)
local side = pick("sym"); if side == "" then side = "none" end
local reg = pick("register")
local fit = ("%s/%s-S0-fit.png"):format(inp, hull)
sh(("%s fit %s %s %s S0 %s %s %s %s"):format(sheet, root .. s0, rig, hull, hero, fit, side, reg))
sh(("%s -I tools/rigkit/bake.py %s %s %s %s S0=%s --views hero --layers 0 --wrecks 0 --poses 1 --threads %s"):format(py, family, rig, bake, hull, fit, threads))
local texel, cols = opt.texel or "1.0", opt.cols or "5"
local dart = opt.dart and (" %s %s"):format(opt.dart[1], opt.dart[2]) or ""
sh(("%s poseatlas %s %s %s %s %s %s%s"):format(sheet, bake, rig, hull, texel, cols, opt.atlas, dart))
if opt.sheet then
  sh(("%s posesheet %s %s %s %s %s %q"):format(sheet, bake, rig, hull, texel, opt.sheet[1], opt.sheet[2]))
end
io.stderr:write(("bake_poses %s %s: %d s\n"):format(name, hull, os.time() - t0))
