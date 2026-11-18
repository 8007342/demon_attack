#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Workers Builds runs a hidden non-production trigger on pushes to `game` (`wrangler preview`,
# which always fails). Stop those builds here, before the Flutter download and the two web
# builds, so they cost seconds of build minutes instead of 4-5 minutes. Production (main)
# and local builds (no WORKERS_CI_BRANCH) are unaffected. Operator, 2026-11-18.
if [[ -n "${WORKERS_CI_BRANCH:-}" && "$WORKERS_CI_BRANCH" != "main" ]]; then
  echo "Skipping the web build: Workers Builds branch '$WORKERS_CI_BRANCH' is not production (main)." >&2
  exit 1
fi

flutter_version="$(tr -d '[:space:]' < .flutter-version)"
flutter_bin="$(command -v flutter || true)"
if [[ -n "$flutter_bin" ]]; then
  installed_version="$("$flutter_bin" --version --machine | node -e 'let data="";process.stdin.on("data",chunk=>data+=chunk);process.stdin.on("end",()=>console.log(JSON.parse(data).frameworkVersion));')"
else
  installed_version=""
fi

if [[ "$installed_version" != "$flutter_version" ]]; then
  sdk_dir="$PWD/.cache/flutter-$flutter_version"
  if [[ ! -x "$sdk_dir/bin/flutter" ]]; then
    # A temporary directory prevents an interrupted download becoming a cached SDK.
    mkdir -p .cache
    download_dir="$(mktemp -d "$PWD/.cache/flutter-download.XXXXXX")"
    trap 'rm -rf "$download_dir"' EXIT
    git clone --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$download_dir/sdk"
    mv "$download_dir/sdk" "$sdk_dir"
  fi
  flutter_bin="$sdk_dir/bin/flutter"
fi

"$flutter_bin" config --no-analytics
"$flutter_bin" pub get --enforce-lockfile
# build-version: vYY.MM.DD.<daily build> from git (scripts/build-version.mjs),
# shown in the game, /console, /gallery and /studio and served at /version.
build_version="$(node scripts/build-version.mjs --out build/version.json)"
echo "Build version: $build_version"
"$flutter_bin" build web --release --base-href / --no-web-resources-cdn --dart-define=BUILD_VERSION="$build_version"
# Art gallery (lib/gallery_main.dart), linked from /console, served at /gallery/.
# Its asset review studio (?page=studio) stamps notes with the build commit.
build_commit="$(git rev-parse --short HEAD 2>/dev/null || true)"
"$flutter_bin" build web --release -t lib/gallery_main.dart --base-href /gallery/ --no-web-resources-cdn --dart-define=BUILD_COMMIT="$build_commit" --dart-define=BUILD_VERSION="$build_version" -o "$PWD/build/web/gallery"
cp build/version.json build/web/version.json
