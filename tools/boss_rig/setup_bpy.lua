#!/usr/bin/env lua
-- boss-hero-assets task 1.1: idempotent preflight for headless Blender.
-- Creates (or verifies) a uv-managed Python 3.13 venv with bpy==5.3.0 at
-- ~/.cache/tillandsias-project/bpy-venv (the cache volume: a host reset can
-- wipe it, so every run calls this first). About 1 min and ~430 MB from
-- PyPI when the venv is missing; ~1 s when it is already there.
--
--   lua tools/boss_rig/setup_bpy.lua          # prints the venv python path
--   lua tools/boss_rig/setup_bpy.lua --check  # exit 1 if bpy is not importable
local BPY = "5.3.0"
local venv = os.getenv("BPY_VENV") or (os.getenv("HOME") .. "/.cache/tillandsias-project/bpy-venv")
local py = venv .. "/bin/python"

local function sh(cmd)
  io.stderr:write("+ " .. cmd .. "\n")
  local ok = os.execute(cmd)
  return ok == true or ok == 0
end

local function bpy_ok()
  local p = io.popen(py .. " -I -c 'import bpy; print(bpy.app.version_string)' 2>/dev/null")
  if not p then return false end
  local v = (p:read("*a") or ""):gsub("%s+$", "")
  p:close()
  return v == BPY, v
end

local ok, have = bpy_ok()
if ok then print(py) os.exit(0) end
if arg[1] == "--check" then
  io.stderr:write("bpy " .. BPY .. " not importable from " .. py .. " (found '" .. (have or "") .. "')\n")
  os.exit(1)
end
if not (sh("uv python install 3.13")
    and sh("uv venv --allow-existing --python 3.13 '" .. venv .. "'")
    and sh("VIRTUAL_ENV='" .. venv .. "' uv pip install bpy==" .. BPY)) then
  io.stderr:write("setup_bpy: install failed\n")
  os.exit(1)
end
ok, have = bpy_ok()
if not ok then
  io.stderr:write("setup_bpy: bpy still not importable (found '" .. (have or "") .. "')\n")
  os.exit(1)
end
print(py)
