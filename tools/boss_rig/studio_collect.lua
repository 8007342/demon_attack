-- boss-hero-assets: copy one studio job's outputs to ~/.cache/tillandsias-project/boss-raw/<hull>/<subdir>/<prefix><seed>.png
-- and append a run record (from each provenance sidecar) to ~/.cache/tillandsias-project/b3/runs.jsonl.
--   lua tools/boss_rig/studio_collect.lua JOB TICKET|"" HULL STAGE SUBDIR [PREFIX]
local job, ticket, hull, stage, sub, prefix = arg[1], arg[2], arg[3], arg[4], arg[5], arg[6] or ""
local C = os.getenv("HOME") .. "/.cache/tillandsias-project"
local dir = "/work/tmp/imagegen/studio/" .. job
local dst = ("%s/boss-raw/%s/%s"):format(C, hull, sub)
os.execute("mkdir -p " .. dst)
local p = io.popen("ls " .. dir .. "/*.png"); local files = {}
for f in p:lines() do files[#files + 1] = f end; p:close()
for _, f in ipairs(files) do
  local seed = io.popen("jq -r .seed " .. f .. ".provenance.json"):read("l")
  local out = ("%s/%s%s.png"):format(dst, prefix, seed)
  assert(os.execute(("cp %s %s"):format(f, out)))
  local rec = io.popen(([[jq -c --arg job %q --arg tk %q --arg hull %q --arg stage %q '{job:$job, ticket:(if $tk=="" then null else $tk end), hull:$hull, stage:$stage, view:"p45_y+00", workflow:.workflow.path, workflow_sha256:.workflow.sha256, models:[.models[]|{file,sha256}], inputs:[.inputs[]|{name,path,sha256}], seed, prompt, negative_prompt, output_sha256, at, verdict:""}' %s.provenance.json]]):format(job, ticket, hull, stage, f)):read("a")
  local log = io.open(C .. "/b3/runs.jsonl", "a"); log:write(rec); log:close()
  print(out)
end
