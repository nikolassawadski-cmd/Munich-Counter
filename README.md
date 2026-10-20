# Munich Counter

Fahrtenbuch für Fahrten nach **München** und **Heilbronn** als Flutter-Web-App
(PWA). Die App läuft im Browser, lässt sich auf dem iPhone wie eine normale App
auf den Home-Bildschirm legen und speichert alle Daten lokal auf dem Gerät.

## Funktionen

- Startseite mit „Sie befinden sich aktuell in …“ (abgeleitet aus der letzten Fahrt)
- Fahrten mit einem Tap eintragen: Ziel, Datum, Uhrzeit, Verkehrsmittel,
  Schalter „ICE-Ticket vorhanden“, Notiz
- Verlauf je Monat, Einträge bearbeiten oder per Wischen löschen
- Monatsexport als CSV (Excel) oder PDF über das iOS-Teilen-Menü
- Sicherung als JSON exportieren und wieder importieren

## Auf dem iPhone installieren

1. Die veröffentlichte Seite in **Safari** öffnen (z. B.
   `https://<github-name>.github.io/Munich-Counter/`).
2. **Teilen** → **Zum Home-Bildschirm**.
3. Die App über das neue Icon starten. Sie läuft im Vollbild und auch offline.

> Die Daten liegen im Speicher dieser Home-Bildschirm-App. Wird sie gelöscht,
> sind die Daten weg. Deshalb regelmäßig unter **Export → Sicherung
> exportieren** eine Sicherung anlegen.

## Entwicklung

Voraussetzung: Flutter 3.24.x.

```sh
flutter pub get
flutter run -d chrome            # lokal im Browser starten
flutter analyze
flutter test                     # alle Tests
flutter test --plain-name "CSV"  # einzelnen Test ausführen
```

Release-Build (wie in der CI):

```sh
flutter build web --release --no-web-resources-cdn --base-href /Munich-Counter/
```

App-Icons neu erzeugen: `dart run tool/generate_icons.dart`

## Veröffentlichen (GitHub Pages)

Jeder Push auf `main` baut die App über
[.github/workflows/deploy.yml](.github/workflows/deploy.yml) und
veröffentlicht sie auf GitHub Pages. Einmalig im Repository unter
**Settings → Pages → Source** „GitHub Actions“ auswählen.
