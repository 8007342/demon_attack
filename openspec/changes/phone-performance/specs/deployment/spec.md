# Cloudflare deployment

## ADDED Requirements

### Requirement: Compressed painted backdrops
Opaque painted backdrops loaded at startup (the sector paintings, the cosmic sky, the hint scenes) SHALL ship as lossy WebP in one format, with no PNG copy, at a quality that keeps PSNR at or above 35 dB against the source. Sprite atlases and pixel art SHALL stay lossless.

#### Scenario: Startup download
- **WHEN** the release web build is made
- **THEN** the seven backdrops total under 2 MB (15.1 MB as PNG) and each decodes in the game

#### Scenario: Recipe
- **WHEN** `lua tools/asset_compress/webp.lua --dry` runs on the source PNGs
- **THEN** it prints each file's size and PSNR, and the committed WebPs match its quality setting
