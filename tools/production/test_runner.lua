-- Exercise actual recovery decisions, including corrupted outputs and failure.
local lfs = require('lfs')
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local temp = os.tmpname(); os.remove(temp); assert(lfs.mkdir(temp))
local id = 'runner-test-' .. temp:match('([^/]+)$'):gsub('[^%w_-]', '')
local state = 'plan/render-runs/' .. id
local spec, output, input, log = temp .. '/jobs.lua', temp .. '/output', temp .. '/input', temp .. '/log'
local function write(path, text) local f=assert(io.open(path,'w')); assert(f:write(text)); f:close() end
local function read(path) local f=assert(io.open(path)); local s=f:read('a'); f:close(); return s end
local function job(fail)
  write(spec, string.format('return {id=%q,inputs={%q},jobs={{id="sample",argv={"lua","-e",%q},outputs={%q}}}}',
    id,input,fail and 'os.exit(7)' or string.format('local f=assert(io.open(%q,"w")); f:write("good"); f:close()', output),output))
end
local function run(expectSuccess)
  local ok = os.execute('lua tools/production/run.lua ' .. q(spec) .. ' > ' .. q(log) .. ' 2>&1')
  assert((ok == true) == expectSuccess, read(log))
end
write(input,'version one'); job(false); run(true)
assert(read(output) == 'good')
run(true); assert(read(log):find('verified, skipping',1,true))
write(output,'corrupt'); run(true); assert(read(log):find('starting sample',1,true)); assert(read(output)=='good')
write(input,'version two'); run(true); assert(read(log):find('starting sample',1,true))
write(state .. '/sample.lua','return {status="running"}'); run(true)
assert(read(log):find('starting sample',1,true))
job(true); run(false)
local record=assert(loadfile(state .. '/sample.lua','t',{}))()
assert(record.status=='failed' and record.exit==7)
job(false); run(true)
record=assert(loadfile(state .. '/sample.lua','t',{}))(); assert(record.status=='done')
for _,path in ipairs({spec,output,input,log,state .. '/sample.lua',state .. '/runner.lock'}) do assert(os.remove(path)) end
assert(lfs.rmdir(state)); assert(lfs.rmdir(temp))
print('PASS: resume, corruption, changed inputs, interrupted job, failure and retry')
