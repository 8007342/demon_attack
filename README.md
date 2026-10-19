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
