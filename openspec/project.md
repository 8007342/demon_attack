# Demon Attack

An original pixel-art arcade remake inspired by Imagic's 1982 Demon Attack: a five-tour campaign of demon swarms,
ground war and carrier bosses, told by squad radio. Mobile-first web, deployed on Cloudflare.

## Stack

Flutter with the Flame engine; a Cloudflare Worker (`worker/`) with SQLite Durable Objects; Go, Lua and (where a
library forces it) Python tools under `tools/`.

## Conventions

The working rules are in [`CLAUDE.md`](../CLAUDE.md): branch flow, test gates, generated files, asset pipelines,
calibration gates and the provenance rule. OpenSpec authoring rules are in `config.yaml` (`rules:`).
