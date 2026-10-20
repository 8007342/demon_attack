# Cloudflare deployment

## Purpose
Build and deploy the Flutter and Flame web application through Wrangler.

## Requirements

### Requirement: Automatic Flutter web build
Running `npx wrangler deploy` SHALL build the Flutter application in release mode before uploading `build/web`. The build SHALL obtain the pinned Flutter SDK when no matching local SDK is available.

#### Scenario: Deploying from a fresh checkout
- **WHEN** dependencies are installed with `npm ci` and Wrangler deployment runs
- **THEN** the build resolves locked Dart dependencies and produces the web assets before upload

### Requirement: Production custom domain
Wrangler SHALL configure `demonattack.tlatoani.net` as a Cloudflare Workers custom domain and serve static assets with single page application navigation fallback.

#### Scenario: Opening a deep link
- **WHEN** a visitor navigates to an application path without a matching static asset
- **THEN** Cloudflare serves the Flutter application shell

### Requirement: Score Worker and Durable Object
The deployed Worker SHALL serve `/api/scores` through a bound SQLite Durable Object and serve the bundled Flutter app for non-API routes.

#### Scenario: Mixed asset and API traffic
- **WHEN** a browser requests the app shell and then `/api/scores`
- **THEN** it receives Flutter assets and a JSON scoreboard from the same origin

### Requirement: Session branch
Development checkpoints SHALL be pushed to `game`; `main` SHALL only receive a stable release.

#### Scenario: Development checkpoint
- **WHEN** a working increment is committed this session
- **THEN** it is pushed to game without changing main
