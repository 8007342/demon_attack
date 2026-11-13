-- Restore external voice dependencies; Lua owns orchestration, Python is only
-- the required Kokoro/Chatterbox runtime. Run from the repository root.
local lfs = require('lfs')
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function cmd(args)
 local out = {}; for _, v in ipairs(args) do out[#out+1] = q(v) end
 return table.concat(out, ' ')
end
local function run(args) assert(os.execute(cmd(args)), 'failed: ' .. cmd(args)) end
local function read(args)
 local p = assert(io.popen(cmd(args))); local s = p:read('a')
 assert(p:close()); return (s:gsub('%s+$', ''))
end
local alias = '/home/forge/.cache/demon-attack'
local durable = '/home/forge/.cache/tillandsias-project/demon-attack'
run({'mkdir', '-p', durable})
if not lfs.symlinkattributes(alias) then
 run({'ln', '-s', durable, alias})
else
 assert(lfs.symlinkattributes(alias, 'mode') == 'link',
  'existing cache is not a symlink; move it to the persistent cache before bootstrap')
 assert(read({'readlink', '-f', alias}) == durable, 'cache points elsewhere')
end
local base = alias .. '/voice-trial'
local envfile = 'assets/research/battle-metal-radio/forge-trial/voices/environment.txt'
local venv = base .. '/cb-venv'
local digest = read({'sha256sum', envfile}):match('^(%x+)')
local stamp = venv .. '/production-environment.sha256'
local f = io.open(stamp); local installed = f and f:read('a'); if f then f:close() end
if installed ~= digest then
 if not lfs.attributes(venv .. '/bin/python') then
  run({'uv', 'venv', '--python', '3.11', venv})
 end
 -- This file captures the known working installed environment, including
 -- deliberate overrides of upstream package requirements. Restore every pin.
 run({'uv', 'pip', 'install', '--no-deps', '--python', venv .. '/bin/python', '-r', envfile})
 f = assert(io.open(stamp, 'w')); assert(f:write(digest)); f:close()
end
local spec = 'art/comms/audio.json'
local function value(filter) return read({'jq', '-er', filter, spec}) end
local function download(repo, revision, files)
 local args = {'env', 'HF_HOME=' .. base .. '/hf', 'HF_HUB_DISABLE_XET=1',
  venv .. '/bin/hf', 'download', repo, '--revision', revision}
 for _, file in ipairs(files) do args[#args+1] = file end
 run(args)
end
download(value('.kokoro.repo'), value('.kokoro.revision'),
 {'--include', 'config.json', 'kokoro-v1_0.pth', 'voices/*.pt'})
local files = {'--include'}; for file in value('.chatterbox.files[]'):gmatch('[^\n]+') do files[#files+1] = file end
download(value('.chatterbox.repo'), value('.chatterbox.revision'), files)
local ffmpeg = '/home/linuxbrew/.linuxbrew/bin/ffmpeg'
if not lfs.attributes(ffmpeg) then
 -- The forge shim provisions the signed bottle on a cold start.
 os.execute(cmd({'ffmpeg', '-version'}))
end
run({ffmpeg, '-version'})
print('Radio runtime restored. Resume with forge-guard and tools/production/resume_radio.lua.')
