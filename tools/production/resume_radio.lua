-- Bound the lifetime of the resident numerical adapter without changing render
-- inputs or trusting ledger flags. run.lua verifies each job's hashes itself.
local function q(s)return "'"..s:gsub("'","'\\''").."'" end
local function command(a)local p={};for _,v in ipairs(a)do p[#p+1]=q(v)end;return table.concat(p,' ')end
local function run(a)return os.execute(command(a))end
local function read(a)local f=assert(io.popen(command(a)));local s=f:read('a');assert(f:close());return s end
local cache='/home/forge/.cache/demon-attack/campaign-batch-2026-11-12'
local specpath='tools/production/radio-bank-2026-11-12.lua'
local spec=assert(loadfile(specpath,'t',{}))()
assert(run({'mkdir','-p',cache}))
if arg[1]~='--locked' then
 local argv={'flock','-n',cache..'/radio-supervisor.lock','lua',arg[0],'--locked'}
 if arg[1]then argv[#argv+1]=arg[1]end
 local ok,_,code=run(argv)
 os.exit(ok and 0 or code or 1)
end
local pid
local function alive()
 local f=io.open('/proc/'..pid..'/stat')
 if not f then return false end
 local stat=f:read('a');f:close()
 return stat:match('%) (%a)')~='Z'
end
local function stop()
 if pid then
  -- Only our exact child PID, never a command-line pattern.
  run({'kill','-TERM',pid})
  for _=1,30 do
   if not alive() then pid=nil;return end
   run({'sleep','1'})
  end
  error('worker failed to terminate; refusing to overlap model processes')
 end
end
local function start()
 local existing=io.popen("pgrep -f '^/home/forge/.cache/demon-attack/voice-trial/cb-venv/bin/python -I tools/production/model_worker.py$'")
 local found=existing:read('a');existing:close()
 assert(found=='','voice worker already exists; inspect it before starting another')
 local argv={'env','HF_HOME=/home/forge/.cache/demon-attack/voice-trial/hf','HF_HUB_DISABLE_XET=1',
  'COMMS_WORK=/home/forge/.cache/demon-attack/voice-trial/work','COMMS_THREADS=20','OMP_NUM_THREADS=20','MKL_NUM_THREADS=20',
  '/home/forge/.cache/demon-attack/voice-trial/cb-venv/bin/python','-I','tools/production/model_worker.py'}
 pid=read({'sh','-c',command(argv)..' >> '..q(cache..'/model-worker-recycled.log')..' 2>&1 & echo $!'}):match('%d+')
 assert(pid)
 for _=1,30 do
  if run({'curl','--fail','--silent','--max-time','1','--output','/dev/null','http://127.0.0.1:18851/'})then return end
  assert(run({'kill','-0',pid}),'worker exited during startup')
  run({'sleep','1'})
 end
 error('worker startup timed out')
end
local ok,err=xpcall(function()
 local from=arg[2]
 if from then
  local found=false;for _,job in ipairs(spec.jobs)do if job.id==from then found=true end end
  assert(found,'unknown starting job '..from)
 end
 local count=0
 for i,job in ipairs(spec.jobs)do
  if not from or job.id==from then
   from=nil
   if count%40==0 then stop();start()end
   assert(run({'lua','tools/production/run.lua',specpath,job.id}),'job failed: '..job.id)
   count=count+1
  end
 end
end,debug.traceback)
stop()
assert(ok,err)
