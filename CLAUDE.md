# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Flutter **web-only** app (PWA) for logging trips to München / Heilbronn. It is
installed on an iPhone via Safari "Zum Home-Bildschirm" and hosted on GitHub
Pages. There is no backend: all data lives in the browser's localStorage. The UI
and all user-facing text are German.

## Commands

The toolchain is pinned to **Flutter 3.24.4 / Dart 3.5**. Do not use newer APIs
such as `Color.withValues` (use `withOpacity`). `intl` is pinned to 0.19.0 by
`flutter_localizations`.

```sh
flutter run -d chrome
flutter analyze
flutter test
flutter test --plain-name "<test name substring>"
flutter build web --release --no-web-resources-cdn --base-href /Munich-Counter/
dart run tool/generate_icons.dart   # regenerates web/icons + favicon
```

CI (`.github/workflows/deploy.yml`) runs analyze, test and build on every push
to `main`, then deploys `build/web` to GitHub Pages using the repo name as the
base href.

## Architecture

- `TripRepository` (`lib/data/`) is the single source of truth. It is a
  `ChangeNotifier` that keeps all trips in memory (sorted newest first) and
  persists them as one JSON string under the SharedPreferences key `trips_v1`
  (= `flutter.trips_v1` in localStorage). Screens receive it through their
  constructor and rebuild with `ListenableBuilder`. No state-management package.
- "Current location" is not stored. `currentLocation()` derives it from the
  destination of the latest trip whose departure is not in the future.
- Changing the `Trip` JSON shape affects saved user data and backup files
  (`format: munich-counter-backup`). Keep `fromJson` backward compatible.
- `lib/services/export_service.dart` contains pure CSV/PDF builders: CSV uses
  `;`, a UTF-8 BOM and German formats for Excel. The PDF embeds the bundled
  Roboto fonts.
- `lib/services/file_access.dart` uses a conditional import: the `_web`
  implementation uses `package:web` (Web Share API with download fallback, file
  picker) and the `_stub` keeps `flutter test` on the VM compiling. Never import
  `file_access_web.dart` directly.
- iOS Safari only opens the share sheet during a user gesture. Call
  `shareOrDownload` synchronously from a tap handler. Async work such as PDF
  generation happens first, then a bottom sheet asks for a second tap.
- Fonts are bundled in `assets/fonts` and Flutter is built with
  `--no-web-resources-cdn` so the installed PWA works offline. Don't reintroduce
  runtime font or CanvasKit CDN fetches.
- Flutter web reports no safe-area inset on iOS, so `AppShell` in `main.dart`
  manually pads the bottom navigation bar.
