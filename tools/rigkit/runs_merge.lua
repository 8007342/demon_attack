#!/usr/bin/env lua
-- rigkit: merge the run records logged by collect.lua (JSON lines) into a family's runs file, with a
-- verdict per record: VERDICTS.json maps a seed ("1015001") or a job ("st-...-96") to a verdict string;
-- a seed beats its job. Records already in OUT (same output_sha256) are kept once. Uses jq.
--   lua tools/rigkit/runs_merge.lua LOG.jsonl VERDICTS.json OUT.json FAMILY
local log, verdicts, out, family = arg[1], arg[2], arg[3], arg[4] or "family"
assert(log and verdicts and out, "usage: runs_merge.lua LOG.jsonl VERDICTS.json OUT.json [FAMILY]")
local f = io.open(out)
if f then f:close() else
  f = assert(io.open(out, "w")); f:write('{"runs": []}\n'); f:close()
end
local cmd = ([=[jq -n --arg fam %q --slurpfile v %q --slurpfile old %q --slurpfile new %q '
  ($v[0]) as $V
  | ([$old[0].runs[]] + [$new[] | .verdict = ($V[(.seed|tostring)] // $V[.job] // error("no verdict for \(.job) \(.seed)"))])
  | unique_by(.output_sha256) | sort_by(.at, .job, .seed)
  | {schema: "demon-attack.rig-runs/v1", family: $fam, runs: .}' > %q.tmp && mv %q.tmp %q]=]):format(
  family, verdicts, out, log, out, out, out)
local ok = os.execute(cmd)
assert(ok == true or ok == 0, "merge failed")
local p = io.popen(("jq '.runs|length' %q"):format(out)); print(p:read("l") .. " runs in " .. out); p:close()
