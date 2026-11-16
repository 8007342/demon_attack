#!/usr/bin/env lua
-- rigkit: rebuild the layer atlas of a layer family (render.frame + a "layers" block) from its
-- committed hero picks, no GPU. rig (rig.py: every hull in the one fixed frame, hero view,
-- clay + hint + id) -> cut each hull's pick into per-module cells by the id pass, finish and pack
-- (rigsheet layeratlas) [-> the variants sheet (rigsheet layersheet)]. Run from the repository root:
--   lua tools/rigkit/bake_layers.lua FAMILY.json --cols 6 --atlas OUT.png
--       [--dart OUT.dart CLASS] [--sheet OUT.png "TITLE"]
-- Picks come from FAMILY .selected[HULL] = {S0 (path under .selected.root), register}.
-- Work files: ~/.cache/tillandsias-project/rigkit/<family>/rig/...
local family = assert(arg[1], "usage: bake_layers.lua FAMILY.json --cols N --atlas OUT.png ...")
local opt, i = {}, 2
while arg[i] do
  local k = assert(arg[i]:match("^%-%-(.+)$"), "bad option " .. arg[i])
  if k == "dart" or k == "sheet" then opt[k] = {arg[i + 1], arg[i + 2]}; i = i + 3
  else opt[k] = arg[i + 1]; i = i + 2 end
end
assert(opt.atlas, "--atlas OUT.png is required")
local home = os.getenv("HOME")
local name = family:match("([^/]+)%.json$")
local rig = home .. "/.cache/tillandsias-project/rigkit/" .. name .. "/rig"
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

local t0 = os.time()
local py = capture("lua tools/boss_rig/setup_bpy.lua")
sh("cd tools/rigsheet && go build -o " .. sheet .. " .")
sh(("mkdir -p %s"):format(rig))
local hulls = capture(("jq -r '.layers.hulls | join(\",\")' %s"):format(family))
sh(("%s -I tools/rigkit/rig.py %s %s --hulls %s --stages S0 --views hero --passes clay,hint,id --threads %s > /dev/null"):format(py, family, rig, hulls, threads))
local dart = opt.dart and (" %s %s"):format(opt.dart[1], opt.dart[2]) or ""
sh(("%s layeratlas %s %s %s %s%s"):format(sheet, family, rig, opt.cols or "6", opt.atlas, dart))
if opt.sheet then
  sh(("%s layersheet %s %s %s %q"):format(sheet, family, rig, opt.sheet[1], opt.sheet[2]))
end
io.stderr:write(("bake_layers %s: %d s\n"):format(name, os.time() - t0))
