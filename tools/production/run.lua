#!/usr/bin/env lua
-- Trusted repository job files return {id, inputs, jobs={{id, argv, outputs}}}.
-- Run from the repository root. All paths are explicit; no inferred publishing.
local lfs = require('lfs')
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function command(argv)
  local out = {}; for _, v in ipairs(argv) do out[#out + 1] = quote(v) end
  return table.concat(out, ' ')
end
local function read(command_text)
  local p = assert(io.popen(command_text)); local s = p:read('a')
  assert(p:close(), command_text .. ' failed'); return s
end
local function hash(path)
  if not lfs.attributes(path, 'mode') then return nil end
  return read('sha256sum -- ' .. quote(path)):match('^(%x+)')
end
local function serialize(value)
  if type(value) == 'table' then
    local keys = {}; for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
    local parts = {}; for _,k in ipairs(keys) do
      parts[#parts+1] = '[' .. serialize(k) .. ']=' .. serialize(value[k])
    end
    return '{' .. table.concat(parts, ',\n') .. '}'
  elseif type(value) == 'string' then return string.format('%q', value)
  else assert(type(value) == 'number' or type(value) == 'boolean'); return tostring(value) end
end
local function write(path, value)
  local f = assert(io.open(path .. '.tmp', 'w')); assert(f:write('return ' .. serialize(value) .. '\n')); assert(f:close())
  assert(os.rename(path .. '.tmp', path))
end
local spec_path = assert(arg[1], 'usage: lua tools/production/run.lua JOBS.lua [--locked]')
local spec = assert(loadfile(spec_path, 't', {}))()
assert(spec.id:match('^[%w_-]+$'), 'invalid run id')
local state_dir = 'plan/render-runs/' .. spec.id
assert(os.execute(command({'mkdir','-p',state_dir})))
if arg[2] ~= '--locked' then
  local argv = {'flock','-n',state_dir .. '/runner.lock','lua',arg[0],spec_path,'--locked'}
  if arg[2] then argv[#argv+1] = arg[2] end
  local ok, _, code = os.execute(command(argv))
  os.exit(ok and 0 or code or 1)
end
local wanted = arg[3]
if wanted then
  local found = false
  for _,job in ipairs(spec.jobs) do if job.id == wanted then found = true end end
  assert(found, 'unknown selected job ' .. wanted)
end
local fingerprint_inputs = {spec_path, arg[0]}
for _,path in ipairs(spec.inputs or {}) do fingerprint_inputs[#fingerprint_inputs+1] = path end
local inputs = {}; for _,path in ipairs(fingerprint_inputs) do inputs[path] = assert(hash(path), 'missing input ' .. path) end
local function checkpoint(job)
  if not spec.checkpoint then return end
  local argv = {'lua','tools/production/checkpoint.lua','Checkpoint production ' .. spec.id .. '/' .. job.id,
    state_dir .. '/' .. job.id .. '.lua'}
  for _,path in ipairs(job.outputs) do
    assert(path:match('^assets/research/'), 'checkpoint output must be a research asset')
    argv[#argv+1] = path
  end
  assert(os.execute(command(argv)))
end
for _,job in ipairs(spec.jobs) do
 if not wanted or wanted == job.id then
  assert(job.id:match('^[%w_-]+$'), 'invalid job id')
  local record_path = state_dir .. '/' .. job.id .. '.lua'
  local previous = lfs.attributes(record_path) and assert(loadfile(record_path,'t',{}))() or nil
  local job_inputs = {}; for path,digest in pairs(inputs) do job_inputs[path] = digest end
  for _,path in ipairs(job.inputs or {}) do job_inputs[path] = assert(hash(path), 'missing job input ' .. path) end
  local fingerprint = serialize({inputs=job_inputs, argv=job.argv, outputs=job.outputs})
  local valid = previous and previous.status == 'done' and previous.fingerprint == fingerprint
  if valid then
    for _,path in ipairs(job.outputs) do if hash(path) ~= previous.outputs[path] then valid = false; break end end
  end
  if valid then
    print('verified, skipping ' .. job.id)
    -- Retry an interrupted remote push on resume, even when rendering is cached.
    checkpoint(job)
  else
    local record = {schema='demon-attack.production-job/v1', fingerprint=fingerprint, inputs=job_inputs,
      status='running', started=os.date('!%Y-%m-%dT%H:%M:%SZ'), outputs={}}
    write(record_path,record)
    print('starting ' .. job.id); io.stdout:flush()
    local ok, why, code = os.execute(command(job.argv))
    record.finished=os.date('!%Y-%m-%dT%H:%M:%SZ'); record.exit=code or 1
    record.status=ok and 'done' or 'failed'; record.result=why
    for _,path in ipairs(job.outputs) do
      local digest=hash(path)
      if not digest then record.status='failed'; record.error='missing output ' .. path else record.outputs[path]=digest end
    end
    write(record_path,record)
    if record.status ~= 'done' then error('job failed: ' .. job.id .. '; see ' .. record_path) end
    checkpoint(job)
  end
 end
end
