# Shared asset-pipeline contract: status and test fixture

Contract: `1935-k2ib/v0`, owned by calmecacpilli (Tillandsias design row). It is committed on Tillandsias `work/1935-k2ib` (84236b088, revision 4c7f51c1a) as the design's direction. **It is not formally signed off yet.** Open rulings: whether `palette_fails_all_gates` is mandatory, and the `camera` field (`floor-perspective` | `side-on`).

User decision (2026-11-01): demon_attack does **not** build character-frame support (regionMask, baseline/pivot cells, baseline_drift, head_size_variance, kumbiaManifest target) until the contract is signed off and the ComfyUI studio can do pose-conditioned generation. Interim note: Tillandsias `work/1954-gdi6` adds `control_net` + `control_image` + `loras` to image.generate, but sd.cpp documents ControlNet for SD1.5 only.

## Kumbia fixture for future unit tests (gatekeeper-v3, pose `left_hand.peak`)

- `regions.png`: 768×960 RGBA, alpha only {0,255}, opaque bbox x 213–595 / y 137–910. Pixel counts: cloth `#0000FF` 45770, trousers `#FF8000` 42916, skin `#FF0000` 10649, hat `#FFFF00` 6243, shoes `#00FFFF` 3448, hair `#00FF00` 107, and no other colours.
- `rig.json` semantics: `groundY` is the projected floor and is constant per family (Gatekeeper 902.4, Mācron 874.67). Shoe bottoms land about 8 px lower because of the capsule radius. `pivotX` is the support ankle's x, or the midpoint of both ankles when `support` is "both" (368.6 here).
- Test palette: plum cloth `#6A2A7A` (passes the plum gate), skin `#C07850` (fails all gates), outline `#1A1018` (fails all gates; `#1A1020` wrongly passes cool).
- Gates (un-premultiplied 0–1 RGB, hard thresholds):
  - cool: b≥0.12, r≥0.70b, b≥0.99r, g≥0.20b, g≤0.66b
  - plum: r≥100/255, r≥0.70b, b≥0.32r, g≤0.55b, b−g≥12/255
  - pink: r≥180/255, r≥0.70b, b≥0.32r, g≤0.86b, b−g≥12/255
- Pack facts: the runtime fails a scene if `imageWidth`/`imageHeight` differ from the real PNG size or a frame ID is missing. Each sheet has one scale and one `pixelsPerUnit`. The anchor is the floor contact in px from the top-left of the trimmed rect. The same accepted frame may be pixel-finished per room, so cache by (frame sha, target).
