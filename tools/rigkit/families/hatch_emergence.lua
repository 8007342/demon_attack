#!/usr/bin/env lua
-- hatch-emergence: writes art/families/hatch-emergence.json, the rig family of the carrier's
-- launched gargoyles in their one-shot emergence poses (openspec/changes/hatch-emergence,
-- design §3; ledger plan/render-runs/hatch-emergence.md). The JSON is the rigkit input and is
-- committed; this script is its recipe (one skeleton, three species by parameters).
--   lua tools/rigkit/families/hatch_emergence.lua > art/families/hatch-emergence.json
--
-- Frame (rigkit units = finished texels at texel 1.0 = combat-atlas pixels): x screen right,
-- y away from the player (screen up at the hero pitch), z up out of the carrier's deck. The
-- hatch rim's centre is the origin; the rim plane is z = 0. The rest pose stands on the rim,
-- upright, wings spread toward the camera (every part visible for the hero paint).

-- ---------------------------------------------------------------- ordered JSON
local function obj(...) return {__o = {...}} end
local enc
local function num(v)
  if math.type(v) == "integer" then return tostring(v) end
  local s = string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")
  if s == "-0" then s = "0" end
  return s
end
function enc(v, ind)
  ind = ind or ""
  local t = type(v)
  if t == "number" then return num(v) end
  if t == "string" then return string.format("%q", v):gsub("\\\n", "\\n") end
  if t == "boolean" then return tostring(v) end
  if v.__o then
    local parts = {}
    for _, kv in ipairs(v.__o) do
      parts[#parts + 1] = ind .. " " .. string.format("%q", kv[1]) .. ": " .. enc(kv[2], ind .. " ")
    end
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "}"
  end
  -- array: numbers inline, anything else one per line
  local flat = true
  for _, x in ipairs(v) do if type(x) == "table" and (x.__o or type(x[1]) == "table") then flat = false end end
  local parts = {}
  for _, x in ipairs(v) do parts[#parts + 1] = enc(x, ind .. " ") end
  if flat then return "[" .. table.concat(parts, ", ") .. "]" end
  return "[\n" .. ind .. " " .. table.concat(parts, ",\n" .. ind .. " ") .. "\n" .. ind .. "]"
end

-- ---------------------------------------------------------------- helpers
local function mx(p) return {-p[1], p[2], p[3]} end
local function mxs(ps) local o = {} for i, p in ipairs(ps) do o[i] = mx(p) end return o end
local function ell(name, tag, at, r, extra)
  local o = obj({"name", name}, {"type", "ell"}, {"tag", tag}, {"radii", r}, {"seg", 14}, {"at", at}, {"smooth", true})
  if extra then for _, kv in ipairs(extra) do table.insert(o.__o, kv) end end
  return o
end
local function horn(name, tag, pts, radii, seg)
  return obj({"name", name}, {"type", "horn"}, {"tag", tag}, {"seg", seg or 8}, {"smooth", true}, {"pts", pts}, {"radii", radii})
end
local function web(name, pts) return obj({"name", name}, {"type", "web"}, {"tag", "membrane"}, {"pts", pts}) end
local function mirrored(o) table.insert(o.__o, {"mirror", true}) return o end

-- Joints (the rest pose).
local J = {
  hip = {0, 0.5, 10}, neck = {0, -0.5, 22.4},
  sh = {6.4, 0, 20.4}, el = {9, -1, 14.6}, wr = {10, -3, 9.6},
  hp = {3, 0.2, 10}, kn = {4.4, -2.6, 5.6},
  wing = {6, 1.6, 21}, wwr = {14, 2.4, 27}, tail = {0, 2.6, 9},
}

-- ---------------------------------------------------------------- species
-- sw: wing span factor (finger tips), wd: how low the trailing edge reaches, arm: limb radius
-- factor, sh: shoulder radius.
local SPECIES = {
  {id = "violet", title = "Violet brute", sw = 0.86, wd = 1.0, arm = 1.25, sh = 3.6,
   hide = "#9070FF", mem = "#6A4CD0", notes = "armoured brute: massive steel pauldrons, small head sunk between them, short thick metal-capped horns, heavy fists, stubby broad wings, thick tail"},
  {id = "coral", title = "Coral hunter", sw = 1.08, wd = 0.72, arm = 0.9, sh = 2.6,
   hide = "#F25A64", mem = "#B8385A", notes = "predatory hunter: sleek, head thrust forward on long jaws, very long swept-back horns, the longest and narrowest wings, a long whip tail with a stinger"},
  {id = "gold", title = "Gold elder", sw = 1.0, wd = 1.0, arm = 1.0, sh = 3.0,
   hide = "#C8902A", mem = "#8A5A2E", notes = "crowned elder: a three-tined gold crown with a ruby over back-swept ram horns, a forked beard, broad ornate wings with gold finger bones, a gold breastplate with a ruby, an orb in each claw"},
}

local function torso(s)
  local p = {
    ell("pelvis", "hide", {0, 0.5, 10}, {3.8, 3, 3}),
    ell("belly", "belly", {0, -0.6, 14.4}, {4.2, 3.2, 4.4}),
    ell("chest", "hide", {0, 0, 18.4}, {5.4 * (s.id == "coral" and 0.88 or 1), 3.8, 4.2}),
    ell("hump", "hide", {0, 2.6, 19.6}, {5.4, 3, 3.6}),
    mirrored(ell("shoulder", s.id == "violet" and "plate" or "hide", {6.2, 0.3, 20.6}, {s.sh, s.sh * 0.95, s.sh * 0.9})),
  }
  if s.id == "violet" then
    p[#p + 1] = ell("breastplate", "plate", {0, -2.8, 18.2}, {4.4, 1.3, 3.2})
    p[#p + 1] = mirrored(horn("pauldronbarb", "horn", {{7.6, 0.2, 22.6}, {8.8, 0.8, 24.6}}, {1.0, 0.15}))
  elseif s.id == "gold" then
    p[#p + 1] = ell("breastplate", "gilt", {0, -2.7, 18.4}, {4.2, 1.2, 3.0})
    p[#p + 1] = ell("ruby", "gem", {0, -3.9, 18.6}, {1.0, 0.6, 1.0})
  end
  return p
end

local function head(s)
  local fwd = s.id == "coral" and -1.2 or 0
  local low = s.id == "violet" and -1.0 or 0
  local p = {
    ell("neck", "hide", {0, -0.6, 22.4 + low}, {2.2, 2.2, 2}),
    ell("skull", "hide", {0, -1.6 + fwd, 25 + low}, {3.3, 3.1, 3.0}),
    ell("muzzle", "hide", {0, -4.3 + fwd, 24 + low}, {2.3, 2.1, 1.6}),
    ell("jaw", "hide", {0, -3.8 + fwd, 22.6 + low}, {2.0, 2.0, 1.0}),
    mirrored(ell("eye", "eye", {1.3, -4.2 + fwd, 25.7 + low}, {0.75, 0.5, 0.55})),
    mirrored(horn("fang", "horn", {{0.9, -5.4 + fwd, 23.4 + low}, {0.8, -5.7 + fwd, 22.0 + low}}, {0.45, 0.1}, 6)),
  }
  if s.id == "violet" then
    p[#p + 1] = mirrored(horn("horn", "plate", {{2.4, -0.8, 26.2}, {3.8, -0.2, 27.8}, {4.3, -0.8, 29.2}}, {1.3, 1.0, 0.45}))
  elseif s.id == "coral" then
    p[#p + 1] = ell("snout", "hide", {0, -6.4 + fwd, 23.8}, {1.5, 1.9, 1.1})
    p[#p + 1] = mirrored(horn("horn", "horn", {{2.0, -1.8, 27.2}, {3.0, 0.6, 29.0}, {3.5, 3.8, 30.0}, {3.7, 7.6, 29.6}}, {1.0, 0.8, 0.5, 0.12}))
  else
    p[#p + 1] = mirrored(horn("horn", "horn", {{2.2, -0.8, 27}, {3.6, 1.0, 28.4}, {4.6, 2.2, 27.2}, {4.8, 1.4, 25.6}}, {1.0, 0.8, 0.6, 0.2}))
    p[#p + 1] = horn("tine", "gilt", {{0, -1.6, 27.8}, {0, -2.0, 31.0}}, {0.75, 0.12}, 6)
    p[#p + 1] = mirrored(horn("tineside", "gilt", {{1.4, -1.4, 27.6}, {1.9, -1.6, 30.0}}, {0.6, 0.12}, 6))
    p[#p + 1] = ell("crownband", "gilt", {0, -1.4, 27.6}, {2.6, 2.4, 0.7})
    p[#p + 1] = ell("crownruby", "gem", {0, -3.6, 28.0}, {0.6, 0.4, 0.6})
    p[#p + 1] = mirrored(horn("beard", "horn", {{0.6, -4.4, 22.0}, {0.9, -4.6, 20.0}}, {0.6, 0.15}, 6))
  end
  return p
end

-- One side's limbs (x > 0 = screen right; the left side mirrors).
local function arm(s, side)
  local f = side < 0 and mxs or function(x) return x end
  local a = s.arm
  local p = {horn("upper", "hide", f({J.sh, {8.2, -0.6, 17.2}, J.el}), {1.9 * a, 1.6 * a, 1.4 * a})}
  if s.id == "violet" then p[#p + 1] = ell("bracer", "plate", f({J.el})[1], {1.7, 1.7, 1.5}) end
  return p
end
local function fore(s, side)
  local f = side < 0 and mxs or function(x) return x end
  local a = s.arm
  local p = {
    horn("fore", "hide", f({J.el, {9.8, -2.2, 11.8}, J.wr}), {1.4 * a, 1.2 * a, 1.0 * a}),
    ell("hand", "hide", f({{10, -3.2, 9}})[1], {1.3 * a, 1.2 * a, 1.2 * a}),
    horn("claw1", "claw", f({{10, -3.6, 8.4}, {10.3, -4.6, 7.0}, {10.1, -5.2, 6.0}}), {0.45, 0.3, 0.08}, 6),
    horn("claw2", "claw", f({{9.3, -3.8, 8.4}, {9.2, -4.8, 7.0}, {8.8, -5.3, 6.2}}), {0.45, 0.3, 0.08}, 6),
    horn("claw3", "claw", f({{10.8, -3.4, 8.6}, {11.4, -4.2, 7.4}, {11.4, -4.8, 6.4}}), {0.45, 0.3, 0.08}, 6),
  }
  if s.id == "gold" then p[#p + 1] = ell("orb", "orb", f({{10.2, -5.0, 8.0}})[1], {1.1, 1.1, 1.1}) end
  return p
end
local function thigh(s, side)
  local f = side < 0 and mxs or function(x) return x end
  local a = s.arm
  return {horn("thigh", "hide", f({J.hp, {4.2, -1.8, 6.8}, J.kn}), {2.0 * a, 1.7 * a, 1.4 * a})}
end
local function shin(s, side)
  local f = side < 0 and mxs or function(x) return x end
  local a = s.arm
  return {
    horn("shin", "hide", f({J.kn, {4.2, -0.6, 2.8}, {4.0, 0.4, 1.0}}), {1.4 * a, 1.1 * a, 0.9 * a}),
    horn("talon1", "claw", f({{4.0, 0.4, 1.0}, {4.0, -1.8, 0.5}, {4.0, -3.2, 0.4}}), {0.9, 0.6, 0.15}, 6),
    horn("talon2", "claw", f({{4.0, 0.4, 1.0}, {5.4, -1.4, 0.5}, {6.0, -2.4, 0.4}}), {0.7, 0.45, 0.12}, 6),
    horn("talon3", "claw", f({{4.0, 0.4, 1.0}, {2.8, -1.4, 0.5}, {2.2, -2.4, 0.4}}), {0.7, 0.45, 0.12}, 6),
  }
end
local function wing(s, side)
  local f = side < 0 and mxs or function(x) return x end
  local w, d = s.sw, s.wd
  local function tip(x, z) -- span-scaled from the wrist, trailing edge raised by wd
    return {J.wwr[1] + (x - J.wwr[1]) * w, 2.8 + 0.2 * w, J.wwr[3] + (z - J.wwr[3]) * (z < J.wwr[3] and d or 1)}
  end
  local t1, t2, t3 = tip(29, 30.5), tip(28, 20.5), tip(22, 13.5)
  local n1, n2 = tip(25.5, 25.2), tip(23, 17.6)
  local bone = s.id == "gold" and "gilt" or "bone"
  return {
    horn("humerus", bone, f({J.wing, {10, 2, 24.5}, J.wwr}), {1.1, 0.9, 0.8}),
    horn("finger1", bone, f({J.wwr, tip(22, 30), t1}), {0.7, 0.5, 0.15}, 6),
    horn("finger2", bone, f({J.wwr, tip(21, 24), t2}), {0.6, 0.45, 0.12}, 6),
    horn("finger3", bone, f({J.wwr, tip(18.5, 19), t3}), {0.55, 0.4, 0.12}, 6),
    horn("thumb", "claw", f({J.wwr, {14.4, 2.2, 29.2}}), {0.6, 0.1}, 6),
    web("panel1", f({J.wwr, tip(22, 30), t1, n1, t2})),
    web("panel2", f({J.wwr, t2, n2, t3})),
    web("panel3", f({J.wwr, t3, tip(17, 14.6), {11.5, 2.2, 15.8}, {7.6, 1.8, 18}, J.wing})),
  }
end
local function tail(s)
  local r = s.id == "violet" and 1.3 or (s.id == "coral" and 0.8 or 1.0)
  local p = {horn("tail", "hide", {J.tail, {0.4, 6, 5.6}, {2.2, 9, 2.4}, {4.6, 8.6, 0.8}, {6.6, 7.0, 0.6}}, {1.6 * r, 1.3 * r, 1.0 * r, 0.7 * r, 0.5 * r})}
  if s.id == "coral" then
    p[#p + 1] = horn("stinger", "claw", {{6.6, 7.0, 0.6}, {7.8, 5.4, 1.4}}, {0.7, 0.1}, 6)
  else
    p[#p + 1] = horn("barb", "claw", {{6.6, 7.0, 0.6}, {8.0, 6.0, 0.8}}, {0.8, 0.1}, 6)
  end
  return p
end

-- ---------------------------------------------------------------- key poses
-- ops: rot about axis by deg at pivot, or move. Axes (family frame): +x rot leans the top
-- toward the camera (-y); +y rot leans the top toward +x; +z rot turns +x toward +y (back).
local function R(ax, deg, pv) return obj({"rot", ax}, {"deg", deg}, {"pivot", pv}) end
local function M(v) return obj({"move", v}) end
local X, Y, Z = {1, 0, 0}, {0, 1, 0}, {0, 0, 1}
local function L(p) return mx(p) end
-- Wing fold (back behind the body) and cock (tips up), per side.
local function wingOps(side, back, up)
  local pv = side > 0 and J.wing or L(J.wing)
  return {R(Z, side * back, pv), R(Y, -side * up, pv)}
end
-- Wing tuck (inside the hatch): droop along the flank first, then swing behind the body.
local function tuckOps(side, down, back)
  local pv = side > 0 and J.wing or L(J.wing)
  return {R(Y, side * down, pv), R(Z, side * back, pv)}
end

local KP = {
  -- 0: the hero / rest pose, also the "flare" frame at the leap's apex (wings snap open).
  {id = "flare", slots = {}},
  -- 1-2: the claw grips the rim: the body deep in the hatch, wings folded flat down its back,
  -- the right arm up over the rim (the side tusk), its claws hooked forward.
  {id = "grip1", slots = {
    torso = {R(X, 10, J.hip), M({2.5, 4, -29})},
    armR = {R(Y, -170, J.sh), R(X, 20, J.sh)},
    foreR = {R(X, 75, J.el)},
    armL = {R(Y, 20, L(J.sh))},
    wingL = tuckOps(-1, 85, 70), wingR = tuckOps(1, 85, 70),
  }},
  {id = "grip2", slots = {
    torso = {R(X, 12, J.hip), M({2.5, 3.5, -25})},
    head = {R(X, 20, J.neck)},
    armR = {R(Y, -165, J.sh), R(X, 30, J.sh)},
    foreR = {R(X, 90, J.el)},
    armL = {R(Y, -150, L(J.sh)), R(X, 25, L(J.sh))},
    foreL = {R(X, 85, L(J.el))},
    wingL = tuckOps(-1, 85, 70), wingR = tuckOps(1, 85, 70),
  }},
  -- 3-4: the head and shoulders peek out beside the held rim, then the head turns.
  {id = "peek1", slots = {
    torso = {R(Y, -14, J.hip), R(X, 14, J.hip), M({3, 3, -16})},
    head = {R(Y, 12, J.neck)},
    armR = {R(Y, -150, J.sh), R(X, 30, J.sh)},
    foreR = {R(X, 85, J.el)},
    armL = {R(Y, 20, L(J.sh))},
    wingL = tuckOps(-1, 85, 70), wingR = tuckOps(1, 85, 70),
  }},
  {id = "peek2", slots = {
    torso = {R(Y, -10, J.hip), R(X, 16, J.hip), M({3, 3, -16})},
    head = {R(Z, -30, J.neck), R(Y, -10, J.neck)},
    armR = {R(Y, -145, J.sh), R(X, 35, J.sh)},
    foreR = {R(X, 85, J.el)},
    armL = {R(Y, -120, L(J.sh)), R(X, 40, L(J.sh))},
    foreL = {R(X, 70, L(J.el))},
    wingL = tuckOps(-1, 82, 70), wingR = tuckOps(1, 82, 70),
  }},
  -- 5: holds the door: chest out of the hatch, the right hand braced high on the tusk, the
  -- left forearm on the rim, the head turned toward the player.
  {id = "hold", slots = {
    torso = {R(Y, -10, J.hip), R(X, 12, J.hip), M({3, 2, -9})},
    head = {R(Z, 15, J.neck), R(X, -8, J.neck)},
    armR = {R(Y, -110, J.sh), R(Z, 15, J.sh)},
    foreR = {R(Y, -40, J.el)},
    armL = {R(Y, 80, L(J.sh)), R(X, 35, L(J.sh))},
    foreL = {R(X, 50, L(J.el))},
    wingL = tuckOps(-1, 70, 55), wingR = tuckOps(1, 70, 55),
  }},
  -- 6-7: anticipation: out on the rim, crouched, wings cocked high; then the deep squash.
  {id = "crouch1", slots = {
    torso = {R(X, 22, J.hip), M({0, 0, -2.5})},
    thighL = {R(X, 55, L(J.hp))}, thighR = {R(X, 50, J.hp)},
    shinL = {R(X, -85, L(J.kn))}, shinR = {R(X, -80, J.kn)},
    armL = {R(X, 35, L(J.sh)), R(Y, 15, L(J.sh))}, armR = {R(X, 40, J.sh), R(Y, -10, J.sh)},
    wingL = wingOps(-1, 70, 45), wingR = wingOps(1, 70, 45),
  }},
  {id = "crouch2", slots = {
    torso = {R(X, 34, J.hip), M({0, 0.5, -4.5})},
    head = {R(X, -15, J.neck)},
    thighL = {R(X, 75, L(J.hp))}, thighR = {R(X, 70, J.hp)},
    shinL = {R(X, -110, L(J.kn))}, shinR = {R(X, -105, J.kn)},
    armL = {R(X, 55, L(J.sh)), R(Y, 20, L(J.sh))}, armR = {R(X, 60, J.sh), R(Y, -15, J.sh)},
    wingL = wingOps(-1, 75, 60), wingR = wingOps(1, 75, 60),
  }},
  -- 8: the leap: the body stretched up, legs trailing, arms reaching, wings folded back tight.
  {id = "leap", slots = {
    torso = {R(X, -6, J.hip), M({0, 0, 3})},
    head = {R(X, -12, J.neck)},
    thighL = {R(X, -20, L(J.hp))}, thighR = {R(X, -25, J.hp)},
    shinL = {R(X, -15, L(J.kn))}, shinR = {R(X, -10, J.kn)},
    armL = {R(Y, 140, L(J.sh))}, armR = {R(Y, -135, J.sh)},
    wingL = wingOps(-1, 85, 20), wingR = wingOps(1, 85, 20),
  }},
  -- 9: the wings open (half spread), the body starts to pitch toward the player.
  {id = "unfurl", slots = {
    torso = {R(X, 14, J.hip)},
    thighL = {R(X, -30, L(J.hp))}, thighR = {R(X, -28, J.hp)},
    armL = {R(Y, 40, L(J.sh)), R(X, 30, L(J.sh))}, armR = {R(Y, -40, J.sh), R(X, 30, J.sh)},
    wingL = wingOps(-1, 35, 30), wingR = wingOps(1, 35, 30),
  }},
  -- 10-11: the glide down to fighting distance: body leaning toward the player, wings spread
  -- face-on with a slight dihedral, legs trailing; then the membranes settle (follow-through).
  {id = "glide1", slots = {
    torso = {R(X, 22, J.hip)},
    head = {R(X, -12, J.neck)},
    thighL = {R(X, -45, L(J.hp))}, thighR = {R(X, -48, J.hp)},
    shinL = {R(X, -20, L(J.kn))}, shinR = {R(X, -20, J.kn)},
    armL = {R(Y, 20, L(J.sh)), R(X, 35, L(J.sh))}, armR = {R(Y, -20, J.sh), R(X, 35, J.sh)},
    wingL = {R(X, -22, L(J.wing)), R(Y, 8, L(J.wing))}, wingR = {R(X, -22, J.wing), R(Y, -8, J.wing)},
  }},
  {id = "glide2", slots = {
    torso = {R(X, 26, J.hip)},
    head = {R(X, -14, J.neck)},
    thighL = {R(X, -50, L(J.hp))}, thighR = {R(X, -50, J.hp)},
    shinL = {R(X, -25, L(J.kn))}, shinR = {R(X, -25, J.kn)},
    armL = {R(Y, 20, L(J.sh)), R(X, 40, L(J.sh))}, armR = {R(Y, -20, J.sh), R(X, 40, J.sh)},
    wingL = {R(X, -26, L(J.wing)), R(Y, 3, L(J.wing))}, wingR = {R(X, -26, J.wing), R(Y, -3, J.wing)},
    tail = {R(Y, 14, J.tail)},
  }},
}

local function poseObj(k)
  local order = {"torso", "head", "armL", "foreL", "armR", "foreR", "thighL", "shinL", "thighR", "shinR", "wingL", "wingR", "tail"}
  local slots = {}
  for _, s in ipairs(order) do if k.slots[s] then slots[#slots + 1] = {s, k.slots[s]} end end
  return obj({"id", k.id}, {"slots", {__o = slots}})
end

-- ---------------------------------------------------------------- slots and hulls
local slotDefs = {
  {"torso", "#3A7BD5", torso, 0}, {"head", "#D53A7B", head, 0},
  {"armL", "#7BD53A", arm, -1}, {"foreL", "#D5B03A", fore, -1},
  {"armR", "#3AD5B0", arm, 1}, {"foreR", "#B03AD5", fore, 1},
  {"thighL", "#5A8AE0", thigh, -1}, {"shinL", "#E05A8A", shin, -1},
  {"thighR", "#8AE05A", thigh, 1}, {"shinR", "#E0C05A", shin, 1},
  {"wingL", "#5AE0C0", wing, -1}, {"wingR", "#C05AE0", wing, 1}, {"tail", "#A0A0F0", tail, 0},
}
local slots = {}
for _, d in ipairs(slotDefs) do
  local sets = {}
  for _, s in ipairs(SPECIES) do
    sets[#sets + 1] = {s.id, obj({"prims", d[3](s, d[4])})}
  end
  slots[#slots + 1] = {d[1], obj({"id", d[2]}, {"texel", "creature"}, {"gameplay", "none"}, {"wreck", false},
    {"default_set", "violet"}, {"sets", {__o = sets}})}
end
local hulls, slotNames = {}, {}
for _, d in ipairs(slotDefs) do slotNames[#slotNames + 1] = d[1] end
for _, s in ipairs(SPECIES) do
  hulls[#hulls + 1] = {s.id, obj({"title", s.title}, {"notes", s.notes}, {"set", s.id},
    {"texel", obj({"creature", 1.0})}, {"tag_map", obj({"hide", "hide_" .. s.id}, {"belly", "belly_" .. s.id}, {"membrane", "membrane_" .. s.id})},
    {"slots", slotNames})}
end

local mats = {
  {"plate", obj({"clay", 0.62}, {"fill", "#8A9CC8"}, {"hint", "#5A6A94"}, {"notes", "steel pauldrons, bracers, breastplate and horn caps (the violet brute)"})},
  {"gilt", obj({"clay", 0.72}, {"fill", "#FFD866"}, {"hint", "#E0B040"}, {"notes", "the gold elder's crown, breastplate and finger bones"})},
  {"gem", obj({"clay", 0.6}, {"fill", "#FF355F"}, {"hint", "#E0284C"}, {"notes", "rubies"})},
  {"orb", obj({"clay", 0.8}, {"fill", "#FFAD53"}, {"hint", "#FFAD53"}, {"notes", "the elder's orbs (its weapon glow)"})},
  {"horn", obj({"clay", 0.8}, {"fill", "#D8C69A"}, {"hint", "#D8C69A"}, {"notes", "horns, fangs and the beard: ivory bone"})},
  {"bone", obj({"clay", 0.55}, {"fill", "#9A8466"}, {"notes", "wing finger bones"})},
  {"claw", obj({"clay", 0.85}, {"fill", "#FFF3D6"}, {"hint", "#E8DCC0"}, {"notes", "claws, talons, barbs"})},
  {"eye", obj({"clay", 0.9}, {"fill", "#FFD23F"}, {"hint", "#FFD23F"}, {"notes", "glowing eyes (on the creature only, never in the hatch)"})},
}
for _, s in ipairs(SPECIES) do
  mats[#mats + 1] = {"hide_" .. s.id, obj({"clay", 0.5}, {"fill", s.hide}, {"hint", s.hide}, {"notes", s.title .. " hide"})}
  mats[#mats + 1] = {"belly_" .. s.id, obj({"clay", 0.6}, {"fill", s.hide}, {"hint", s.hide}, {"notes", s.title .. " belly plates"})}
  mats[#mats + 1] = {"membrane_" .. s.id, obj({"clay", 0.35}, {"fill", s.mem}, {"hint", s.mem}, {"notes", s.title .. " wing membrane"})}
end
-- placeholders resolved by tag_map (the grammar needs every prim tag to be a material)
mats[#mats + 1] = {"hide", obj({"clay", 0.5}, {"fill", "#808080"})}
mats[#mats + 1] = {"belly", obj({"clay", 0.6}, {"fill", "#808080"})}
mats[#mats + 1] = {"membrane", obj({"clay", 0.35}, {"fill", "#808080"})}

local poseList = {}
for i, k in ipairs(KP) do poseList[i] = poseObj(k) end
local parents = obj({"head", "torso"}, {"armL", "torso"}, {"armR", "torso"}, {"foreL", "armL"}, {"foreR", "armR"},
  {"thighL", "torso"}, {"thighR", "torso"}, {"shinL", "thighL"}, {"shinR", "thighR"},
  {"wingL", "torso"}, {"wingR", "torso"}, {"tail", "torso"})

local ramps = obj(
  {"gink", {"#0A0716"}},
  {"violet", {"#24164E", "#4A2FA0", "#9070FF", "#CDB8FF"}},
  {"violetMembrane", {"#1E1440", "#3A2678", "#6A4CD0"}},
  {"coral", {"#4A0E24", "#9A2040", "#F25A64", "#FFA08A"}},
  {"coralMembrane", {"#2E0A1E", "#5E1638", "#B8385A"}},
  {"gold", {"#3E2108", "#7A4A12", "#C8902A", "#FFD866"}},
  {"goldMembrane", {"#2A1A10", "#4A2C1A", "#8A5A2E"}},
  {"bone", {"#4A3A2E", "#9A8466", "#D8C69A", "#FFF3D6"}},
  {"eye", {"#FFD23F", "#FFFBE0"}},
  {"metal", {"#2B3355", "#4A5680", "#8A9CC8", "#D8E2FF"}},
  {"accent", {"#FF355F", "#C4203F", "#FFAD53"}})

local fam = obj(
  {"schema", "demon-attack.rig-family/v1"},
  {"name", "hatch-emergence"},
  {"notes", "The carrier's launched gargoyles in their one-shot emergence poses (openspec/changes/hatch-emergence design §3, plan/render-runs/hatch-emergence.md). GENERATED by tools/rigkit/families/hatch_emergence.lua: edit that and rerun. Units are finished texels at texel 1.0 (= combat-atlas pixels, drawn at 40/64 arena units each). Frame: x screen right, y away from the player, z up out of the deck; the origin is the hatch rim's centre and the rim plane is z = 0. The rest pose (flare) stands on the rim, wings spread toward the camera, so the hero paint reaches every part. One skeleton for every species, so the key poses are shared."},
  {"symmetric", false},
  {"views", obj({"pitch", {45}}, {"yaw", {0}}, {"hero", {45, 0}}, {"stored", {{45, 0}}})},
  {"render", obj({"scale", 12}, {"margin", 0}, {"frame", {-32, -40, 32, 24}})},
  {"grade", obj({"notes", "rigsheet pose finish: the 12:1 area scale averages the paint's own outlines into mud, so lift it before the palette snap"}, {"gain", 1.35}, {"lift", 0.03}, {"sat", 1.15})},
  {"articulation", obj({"notes", "Named key poses (rigkit keyposes): one rigid op list per slot, children follow their parents. Order = atlas columns; the runtime names them in lib/game/hatch_emergence_atlas.dart."}, {"parents", parents}, {"keyposes", poseList})},
  {"materials", {__o = mats}},
  {"palettes", obj({"notes", "The combat atlas's gargoyle ramps (plan/sprite-atlas.md, Palette), so the emergence frames match the flight frames they hand off to."}, {"ramps", ramps})},
  {"stages", obj({"S0", obj({"notes", "the only stage"})})},
  {"slots", {__o = slots}},
  {"hulls", {__o = hulls}},
  {"prompts", obj(
    {"hero", "Repaint this clay model as a finished, detailed painted game sprite of a small demonic gargoyle creature standing with its bat wings spread wide, seen from the front and above, in the style of a high-resolution 16-bit fantasy arcade sprite painting. Stony, leathery hide with heavy shoulders and a hunched torso, clawed hands and feet with ivory claws, a barbed tail, bat-wing membranes stretched between bony fingers with torn, scalloped trailing edges, small glowing yellow eyes. Keep each part's colour exactly as the clay shows it: the hide, belly, membranes, ivory horns and claws. Crisp edge highlights, lit from the upper left, readable at small size. Keep the outline, every shape, the pose and the viewing angle exactly. Solid flat green background (#00FF00), no checkerboard, no shadow."},
    {"hero_notes", "The prompt is hero, then hero_<species>, then negative (one job per species, seeds 90N0000)."},
    {"hero_violet", "A violet-purple armoured brute with massive blue-steel pauldrons and breastplate, a small head sunk between them, short thick steel-capped horns, heavy fists, stubby broad dark purple wings."},
    {"hero_coral", "A coral-red predatory hunter, sleek, head thrust forward on long jaws, very long swept-back ivory horns, long narrow dark crimson wings, a whip tail with a stinger."},
    {"hero_gold", "A golden-ochre crowned elder with a three-tined gold crown set with a ruby over back-swept ivory ram horns, a forked beard, a gold breastplate with a ruby, gold finger bones in broad brown wings, a glowing amber orb in each claw."},
    {"negative", "human, person, angel, bird, feathers, armour plates on the wings, text, letters, watermark, logo, frame, border, blurry, photo, multiple views, grid, background scene, checkerboard, shadow, cartoon, chibi, toy, extra limbs, extra heads, extra eyes"})},
  {"selected", obj({"notes", "Picked raws (paths under root); ledger plan/render-runs/hatch-emergence.md. register bbox: the hero control was cropped around the subject, so each raw is registered to the clay silhouette box."}, {"root", "art/sprites/sources/hatch-emergence/"},
    {"violet", obj({"S0", "hero/violet-9010000.png"}, {"sym", "none"}, {"register", "bbox"})},
    {"coral", obj({"S0", "hero/coral-9020002.png"}, {"sym", "none"}, {"register", "bbox"})},
    {"gold", obj({"S0", "hero/gold-9030003.png"}, {"sym", "none"}, {"register", "bbox"})})}
)
print(enc(fam))
