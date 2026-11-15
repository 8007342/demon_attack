#!/usr/bin/env lua
-- rigkit: copy one studio job's outputs to RAWDIR/<prefix><seed>.png and append one run record per
-- output (from its provenance sidecar) to LOG (JSON lines). Generalises tools/boss_rig/studio_collect.lua.
--   lua tools/rigkit/collect.lua JOB HULL STAGE RAWDIR LOG [PREFIX] [VIEW]
-- The verdicts are filled in later by tools/rigkit/runs_merge.lua.
local job, hull, stage, dst, log, prefix, view = arg[1], arg[2], arg[3], arg[4], arg[5], arg[6] or "", arg[7] or "p45_y+00"
assert(job and hull and stage and dst and log, "usage: collect.lua JOB HULL STAGE RAWDIR LOG [PREFIX] [VIEW]")
local dir = "/work/tmp/imagegen/studio/" .. job
os.execute(("mkdir -p '%s' \"$(dirname '%s')\""):format(dst, log))
local p = io.popen("ls " .. dir .. "/*.png 2>/dev/null"); local files = {}
for f in p:lines() do files[#files + 1] = f end; p:close()
assert(#files > 0, "no outputs in " .. dir)
for _, f in ipairs(files) do
  local seed = io.popen("jq -r .seed " .. f .. ".provenance.json"):read("l")
  local out = ("%s/%s%s.png"):format(dst, prefix, seed)
  assert(os.execute(("cp %s %s"):format(f, out)))
  local rec = io.popen(([[jq -c --arg job %q --arg hull %q --arg stage %q --arg view %q --arg raw %q '{job:$job, hull:$hull, stage:$stage, view:$view, raw:$raw, workflow:.workflow.path, workflow_sha256:.workflow.sha256, models:[.models[]|{file,sha256}], inputs:[.inputs[]|{name,path,sha256}], seed, prompt, negative_prompt, output_sha256, at, verdict:""}' %s.provenance.json]]):format(job, hull, stage, view, out, f)):read("a")
  local fh = io.open(log, "a"); fh:write(rec); fh:close()
  print(out)
end
