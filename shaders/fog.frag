#version 460 core
// Fog layers for Demon Attack (openspec/changes/atmosphere-and-swarms,
// plan/atmosphere-research.md §2): domain-warped fBm, 4 octaves,
// lacunarity 2, gain .5 (Quilez, "Domain warping"; The Book of Shaders
// ch. 13), shaped by the layer's vertical profile. The ground layer is
// projected through the flyover camera (y = 172 + 348 z0 / z) so it lies on
// and scrolls with the terrain. One rect per slot; output premultiplied.

#include <flutter/runtime_effect.glsl>

uniform vec4 uXform;  // local = arena * scale (xy) + offset (zw)
uniform vec4 uBand;   // top, peak, bottom, alpha
uniform vec4 uColor;  // rgb, wisp threshold
uniform vec4 uMotion; // time, drift x, drift y, warp
uniform vec4 uLook;   // scale, flatten, ground (0/1), lateral offset (0: world-anchored)
uniform vec4 uShip;   // ship-zone top, ship-zone factor, ground cam, seed

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float sum = 0.0;
  float amp = 0.5;
  for (int o = 0; o < 4; o++) {
    sum += amp * noise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    amp *= 0.5;
  }
  return sum / 0.9375;
}

// Cheaper fBm (3 octaves) for the warp field.
float fbm3(vec2 p) {
  float sum = 0.0;
  float amp = 0.5;
  for (int o = 0; o < 3; o++) {
    sum += amp * noise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    amp *= 0.5;
  }
  return sum / 0.875;
}

float profile(float y) {
  if (y <= uBand.x || y >= uBand.z) return 0.0;
  if (y < uBand.y) return smoothstep(uBand.x, uBand.y, y);
  return 1.0 - smoothstep(uBand.y, uBand.z, y);
}

void main() {
  vec2 device = FlutterFragCoord().xy;
  vec2 arena = (device - uXform.zw) / uXform.xy;
  float t = uMotion.x;
  vec2 drift = uMotion.yz;
  vec2 p;
  if (uLook.z > 0.5) {
    // Ground: lateral and forward ground texels under this pixel.
    float n = max(0.02, (arena.y - 172.0) / 348.0);
    float z = 174.0 / n;
    p = vec2((arena.x - 180.0) / (2.0 * n), uShip.z + z) / uLook.x;
    p += drift * t / uLook.x;
  } else {
    p = vec2(arena.x - uLook.w, arena.y / uLook.y) / uLook.x;
    p -= drift * t / uLook.x;
  }
  p += vec2(uShip.w, uShip.w * 0.37);
  // Domain warp: f(p + w * q), q itself drifting slowly with time, so the
  // shapes evolve rather than translate.
  float slow = t * 0.035;
  vec2 q = vec2(fbm3(p + vec2(0.0, slow)), fbm3(p + vec2(5.2, 1.3) - slow));
  float d = fbm(p + uMotion.w * 1.6 * (q - 0.5) + vec2(slow * 0.6, 0.0));
  // Value-noise fBm clusters near .5: stretch it before the wisp cut. A
  // wide cut keeps the billows' edges soft where the warp folds them
  // (fog-restoration: no hard-edged sheets).
  d = (d - 0.5) * 1.8 + 0.5;
  float density = smoothstep(0.18 + uColor.w, 0.86, d);
  density *= density * (3.0 - 2.0 * density);
  float a = density * profile(arena.y) * uBand.w;
  if (arena.y > uShip.x - 30.0) {
    float zone = smoothstep(uShip.x - 30.0, uShip.x, arena.y);
    a *= 1.0 - zone * (1.0 - uShip.y);
  }
  // Ordered dither against banding on the slow gradients (Playdead).
  a += (hash(device) - 0.5) / 255.0;
  a = clamp(a, 0.0, 1.0);
  fragColor = vec4(uColor.rgb * a, a);
}
