-- Writes the ground-forces in-between workflows (render plan, Section 2):
--   art/workflows/sprites/inbetween-wan-vace.json      (17 frames)
--   art/workflows/sprites/inbetween-wan-vace-33.json   (33 frames)
--   art/workflows/sprites/matte-birefnet-batch.json
--
-- Wan2.2 Fun VACE 14B (fp8), high-noise then low-noise expert, 480 x 480.
-- Inputs (studio.run_workflow binds only LoadImage nodes):
--   $input    reference keyframe (the finished keyframe at x8 on the key colour)
--   $control  the rig's control clip as ONE horizontal strip of N frames of
--             480 x 480 (silhouette and depth), split here into a batch with
--             ImageCrop + ImageBatch (core nodes only, nothing to pin)
-- Outputs: the decoded frames (sprites/inbetween) and their BiRefNet mattes
-- (sprites/inbetween-matte), so one job yields the clip and its alpha.
--
-- Speed: the Wan2.2-Lightning LoRA (lightx2v/Wan2.2-Lightning rev 18bccf88,
-- Seko-V1.1 high-noise and low-noise), pinned on the studio as
-- lora/high_noise_model.safetensors and lora/low_noise_model.safetensors.
-- One LoraLoaderModelOnly per expert, before ModelSamplingSD3; schedule
-- steps 4, cfg 1, split 2/2. The plain schedule (20 steps, cfg 3.5, split
-- 10/10, smoke-tested 2026-11-14) is reachable without a graph change by
-- $node overrides: strength_model 0 on both loaders, steps 20, cfg 3.5,
-- end_at_step/start_at_step 10.
--
-- Usage: lua tools/production/inbetween_vace_workflow.lua [repo root]

local root = arg[1] or "."
local SIZE = 480
local STEPS, CFG, SPLIT = 4, 1.0, 2

local function enc(v, ind)
  ind = ind or ""
  local t = type(v)
  if t == "table" then
    if #v > 0 or next(v) == nil then
      local parts = {}
      for _, x in ipairs(v) do parts[#parts + 1] = enc(x, ind) end
      return "[" .. table.concat(parts, ", ") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      local na, nb = tonumber(a), tonumber(b)
      if na and nb then return na < nb end
      return tostring(a) < tostring(b)
    end)
    local parts = {}
    for _, k in ipairs(keys) do
      parts[#parts + 1] = ind .. "  " .. string.format("%q", k) .. ": " .. enc(v[k], ind .. "  ")
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "}"
  elseif t == "string" then
    return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
  elseif t == "number" then
    if math.type(v) == "integer" then return tostring(v) end
    return string.format("%.4g", v)
  else
    return tostring(v)
  end
end

local function graph(frames)
  local g, n = {}, 0
  local function node(class, title, inputs)
    n = n + 1
    local id = tostring(n)
    g[id] = {class_type = class, _meta = {title = title}, inputs = inputs}
    return id
  end
  local function o(id, i) return {id, i or 0} end

  local high = node("UNETLoader", "wan2.2-fun-vace-high", {unet_name = "wan2.2_fun_vace_high_noise_14B_fp8_scaled.safetensors", weight_dtype = "default"})
  local low = node("UNETLoader", "wan2.2-fun-vace-low", {unet_name = "wan2.2_fun_vace_low_noise_14B_fp8_scaled.safetensors", weight_dtype = "default"})
  local te = node("CLIPLoader", "umt5-xxl", {clip_name = "umt5_xxl_fp8_e4m3fn_scaled.safetensors", type = "wan"})
  local vae = node("VAELoader", "wan-vae", {vae_name = "wan_2.1_vae.safetensors"})
  local highL = node("LoraLoaderModelOnly", "lightning high (Seko-V1.1)", {model = o(high), lora_name = "high_noise_model.safetensors", strength_model = 1.0})
  local lowL = node("LoraLoaderModelOnly", "lightning low (Seko-V1.1)", {model = o(low), lora_name = "low_noise_model.safetensors", strength_model = 1.0})
  local highS = node("ModelSamplingSD3", "shift high", {model = o(highL), shift = 8.0})
  local lowS = node("ModelSamplingSD3", "shift low", {model = o(lowL), shift = 8.0})
  local pos = node("CLIPTextEncode", "$prompt", {clip = o(te), text = "a small game sprite unit moving in place, flat key colour background, consistent materials and colours"})
  local neg = node("CLIPTextEncode", "$negative_prompt", {clip = o(te), text = "blurry, text, watermark, camera motion, background scenery, extra limbs, morphing"})
  local ref = node("LoadImage", "reference keyframe", {image = "$input"})
  local refS = node("ImageScale", "reference 480", {image = o(ref), upscale_method = "nearest-exact", width = SIZE, height = SIZE, crop = "center"})
  local strip = node("LoadImage", "control strip (N x 480 frames)", {image = "$control"})
  local batch
  for f = 0, frames - 1 do
    local c = node("ImageCrop", "control frame " .. f, {image = o(strip), width = SIZE, height = SIZE, x = f * SIZE, y = 0})
    if batch then
      batch = node("ImageBatch", "control batch " .. f, {image1 = o(batch), image2 = o(c)})
    else
      batch = c
    end
  end
  local vace = node("WanVaceToVideo", "vace", {positive = o(pos), negative = o(neg), vae = o(vae), width = SIZE, height = SIZE,
    length = frames, batch_size = 1, strength = 1.0, control_video = o(batch), reference_image = o(refS)})
  local s1 = node("KSamplerAdvanced", "$seed", {model = o(highS), positive = o(vace, 0), negative = o(vace, 1), latent_image = o(vace, 2),
    add_noise = "enable", noise_seed = 790000, steps = STEPS, cfg = CFG, sampler_name = "euler", scheduler = "simple",
    start_at_step = 0, end_at_step = SPLIT, return_with_leftover_noise = "enable"})
  local s2 = node("KSamplerAdvanced", "low-noise expert", {model = o(lowS), positive = o(vace, 0), negative = o(vace, 1), latent_image = o(s1),
    add_noise = "disable", noise_seed = 790000, steps = STEPS, cfg = CFG, sampler_name = "euler", scheduler = "simple",
    start_at_step = SPLIT, end_at_step = 10000, return_with_leftover_noise = "disable"})
  local trim = node("TrimVideoLatent", "drop reference frame", {samples = o(s2), trim_amount = o(vace, 3)})
  local dec = node("VAEDecode", "decode", {samples = o(trim), vae = o(vae)})
  node("SaveImage", "save frames", {images = o(dec), filename_prefix = "sprites/inbetween"})
  local bm = node("LoadRembgByBiRefNetModel", "birefnet", {model = "model.safetensors", device = "AUTO", use_weight = false, dtype = "float32"})
  local mask = node("GetMaskByBiRefNet", "mattes", {model = o(bm), images = o(dec), width = 1024, height = 1024, upscale_method = "bilinear", mask_threshold = 0.0})
  local mi = node("MaskToImage", "matte images", {mask = o(mask)})
  node("SaveImage", "save mattes", {images = o(mi), filename_prefix = "sprites/inbetween-matte"})
  return g
end

-- Single-image matte that also saves the cut-out (RGBA), for Qwen candidates.
local function matte()
  return {
    ["1"] = {class_type = "LoadImage", _meta = {title = "image"}, inputs = {image = "$input"}},
    ["2"] = {class_type = "LoadRembgByBiRefNetModel", _meta = {title = "birefnet"}, inputs = {model = "model.safetensors", device = "AUTO", use_weight = false, dtype = "float32"}},
    ["3"] = {class_type = "GetMaskByBiRefNet", _meta = {title = "mask"}, inputs = {model = {"2", 0}, images = {"1", 0}, width = 1024, height = 1024, upscale_method = "bilinear", mask_threshold = 0.0}},
    ["4"] = {class_type = "MaskToImage", _meta = {title = "mask image"}, inputs = {mask = {"3", 0}}},
    ["5"] = {class_type = "SaveImage", _meta = {title = "save matte"}, inputs = {images = {"4", 0}, filename_prefix = "sprites/matte"}},
  }
end

local function write(path, t)
  local f = assert(io.open(root .. "/" .. path, "w"))
  f:write(enc(t), "\n")
  f:close()
  print("wrote " .. path)
end

write("art/workflows/sprites/inbetween-wan-vace.json", graph(17))
write("art/workflows/sprites/inbetween-wan-vace-33.json", graph(33))
write("art/workflows/sprites/matte-birefnet-batch.json", matte())
