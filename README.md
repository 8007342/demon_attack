# Demon Attack

Demon Attack game, inspired by Atari's 1982 title of the same name.
Built with Flutter and Flame for mobile web, Android, and iOS.

The first version is a quiet dark “Under Construction” landing page announcing **Coded Live Oct 20** with a link to the [live build](https://eventship.com/event/building-a-game-in-a-framework-i-ve-never-touched).

## Development

```sh
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

## Validation

```sh
flutter analyze
flutter test
flutter build web
openspec validate --all --strict
```

## Project layout

- `lib/main.dart`: responsive landing page and Flame starfield.
- `openspec/specs/`: requirements; update these before changing behavior.
- `openspec/config.yaml`: OpenSpec project context.
- `plan/roadmap.md`: remaining work.

## Cloudflare deployment

Production domain: **https://demonattack.tlatoani.net**. This uses Cloudflare Workers Static Assets (including SPA navigation fallback).

Requirements: Node.js 22+, npm, Bash, and Git. The build uses Flutter from `.flutter-version`, downloading that SDK automatically when a matching local installation is unavailable. Flutter and Flame assets, including the web renderer, are bundled in `build/web`.

```sh
npm ci
npx wrangler login
npx wrangler deploy
```

Wrangler automatically runs `npm run build` before deployment. `npm run deploy:check` runs that same build and validates the upload without publishing. `npm run dev` builds and serves the app through Wrangler locally.

The Cloudflare account must contain the active `tlatoani.net` zone. Wrangler configures `demonattack.tlatoani.net` as a custom domain, including DNS and TLS. For CI, configure `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` in the build environment; keep credentials out of source control.

For Cloudflare Workers Builds, connect this repository with root directory `/`, worker name `demon-attack`, Node.js 22 or later, and deploy command `npx wrangler deploy`. Leave the separate build command empty because Wrangler invokes the build itself. The normal npm dependency installation uses the committed lockfile.
