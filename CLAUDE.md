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
  The repository also holds `AppSettings` (`settings_v1`) and per-month
  `DTicketMonth` entries (`dtickets_v1`); all three go into the JSON backup
  (version 2; version 1 backups with trips only must still import).
- Location is never stored; `lib/services/timeline.dart` derives it from the
  trips (`locationAt`, `locationsOn`, `daysAt`). A trip departing on a day
  counts that day for both cities. This drives the home card, the calendar
  and "Tage am Studienort".
- Changing the `Trip` JSON shape affects saved user data and backup files
  (`format: munich-counter-backup`). Keep `fromJson` backward compatible: old
  trips have no `purpose`/costs and default to `studyRelated: true`.
- Costs: `tripCost()` in `lib/services/tax_summary.dart` is the ticket price
  (`priceCents`), or `distanceKm × settings.kmRate` for `Transport.auto`, so a
  changed km rate recalculates past car trips. `summarizeYear` counts only
  `studyRelated` trips plus the Deutschlandticket share.
- `lib/services/export_service.dart` contains pure CSV/PDF builders (month and
  tax year). CSV uses `;`, decimal commas, a UTF-8 BOM and German formats for
  Excel. The PDFs embed the bundled Roboto, which lacks some glyphs (e.g. `→`),
  so check the `pdf` package's "Unable to find a font" warnings in test output.
- `lib/services/haptics.dart` uses the same conditional-import pattern as
  `file_access`. On iOS the web version toggles a hidden
  `<input type="checkbox" switch>` (iOS 18+), so call `hapticTick()` inside the
  tap handler before any `await`.
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
