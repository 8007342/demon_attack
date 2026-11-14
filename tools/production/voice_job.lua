-- Small adapter around the existing Python model library pipeline.
local mode, id = assert(arg[1]), assert(arg[2])
assert(mode == 'refs' or mode == 'expressive')
assert(id:match('^[%w_.-]+$'))
local base = '/home/forge/.cache/demon-attack/voice-trial'
local dest = 'assets/research/battle-metal-radio/forge-trial/voices'
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function run(argv)
  local parts = {}; for _,v in ipairs(argv) do parts[#parts+1] = q(v) end
  assert(os.execute(table.concat(parts,' ')), 'voice adapter command failed')
end
local function stage(name)
run({'env','VIRTUAL_ENV=' .. base .. '/cb-venv','HF_HOME=' .. base .. '/hf','HF_HUB_DISABLE_XET=1',
  'COMMS_WORK=' .. base .. '/work', '/home/forge/.cache/tillandsias-project/bin/forge-guard',
  'run','--need','3','--threads','4','--timeout','900','--',base .. '/cb-venv/bin/python','-I',
  'tools/comms_pipeline.py',name,'--only',id,'--limit','1','--threads','4'})
end
if mode == 'expressive' then
  -- Restore the committed reference after a forge reset, even if its job skips.
  run({'mkdir','-p',base .. '/work/refs'})
  run({'cp','--',dest .. '/reference-pip.wav',base .. '/work/refs/pip.wav'})
  run({'cp','--',dest .. '/refs.json',base .. '/work/refs.json'})
  stage('voices')
end
stage(mode)
run({'mkdir','-p',dest})
if mode == 'refs' then
  run({'cp','--',base .. '/work/refs/' .. id .. '.wav',dest .. '/reference-' .. id .. '.wav'})
  run({'cp','--',base .. '/work/refs.json',dest .. '/refs.json'})
else
  -- The old adapter logs per-clip errors but exits zero. Reject those explicitly.
  run({'jq','-e','--arg','id',id,'has($id) and .[$id].error == null',base .. '/work/expressive.json'})
  run({'cp','--',base .. '/work/expressive/' .. id .. '.wav',dest .. '/' .. id .. '.wav'})
  run({'cp','--',base .. '/work/expressive/' .. id .. '.key',dest .. '/' .. id .. '.key'})
  run({'cp','--',base .. '/work/raw/' .. id .. '.wav',dest .. '/' .. id .. '.baseline.wav'})
end
