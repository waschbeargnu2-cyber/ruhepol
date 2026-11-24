# Agenda

Deine To-Do-App für Android: Aufgaben, Listen, Fristen, Handy-Kalender, Erinnerungen,
Eisenhower-Matrix, Erfolge und ein Homescreen-Widget. Pastellfarben im Material-3-Stil.
Gebaut mit Flutter (Dart) und kleinen Android-Teilen in Kotlin. Die App wird in der Cloud
(GitHub Actions) gebaut, nicht auf dem PC.

## So kommt eine neue Version aufs Handy

1. Code ändern und zu GitHub hochladen (`git push`).
2. GitHub baut die App automatisch (ca. 6–8 Minuten) und legt sie als Release
   `agenda-build-<Nummer>.apk` ab.
3. Die App findet das Update von selbst. Auf **Heute** erscheint „Neue Version verfügbar“,
   alternativ unter **Mehr → App → Nach Updates suchen**. „Aktualisieren“ lädt die neue
   Version und öffnet den Installer. Deine Daten bleiben erhalten.

## Ordner und Dateien

| Pfad | Inhalt |
|---|---|
| `lib/main.dart` | App-Start, Navigation, Übersicht aller Dateien |
| `lib/aufgaben_store.dart` | Gedächtnis der App, alle Änderungen laufen hier durch |
| `lib/modelle.dart` | Aufgabe, Liste, Wiederholung, Erledigt-Protokoll, Einstellungen |
| `lib/eingabe_parser.dart` | Erkennung von „morgen 15 Uhr #Liste !!“ |
| `lib/handy_kalender.dart` | Kalender des Handys lesen und schreiben |
| `lib/erinnerungen.dart` | Regeln, wann woran erinnert wird |
| `lib/erfolge.dart` | Punkte, Level, Serien, Abzeichen |
| `lib/widget_daten.dart` | Daten für das Homescreen-Widget |
| `lib/updates.dart` | Updates von GitHub |
| `lib/app_aktionen.dart` | Teilen, Kurzbefehl „Neue Aufgabe“, Widget-„+“ |
| `lib/seiten/` | Heute, Listen und Matrix, Kalender, Erfolge, Mehr |
| `lib/widgets/` | Bausteine (Aufgaben-Kachel, Fenster, Details) |
| `android/app/src/main/kotlin/…` | Android-Teile: Kalender, Wecker, Widget, Updates |
| `android/app/src/main/res/` | App-Symbol, Widget-Layout, Startbildschirm |
| `test/` | Automatische Tests, die bei jedem Build laufen |
| `.github/workflows/build.yml` | Anleitung für den Cloud-Build |
| `schluessel/` | **Nur lokal:** Signaturschlüssel. Nicht löschen und nicht weitergeben. |

## Selbst anpassen

- **App-Farbe:** `lib/design.dart` → `enum Pastell`
- **Listenfarben und Symbole:** `lib/design.dart` → `listenFarben`, `listenIcons`
- **Erinnerungsregeln:** `lib/erinnerungen.dart` → `planeErinnerungen`
- **Punkte, Level, Abzeichen:** `lib/erfolge.dart`
- **Matrix-Regeln (wichtig/dringend):** `lib/aufgaben_store.dart` → `istWichtig`, `istDringend`
- **Freie Zeitfenster (8–20 Uhr, min. 60 Min.):** `lib/seiten/kalender_seite.dart`
- **App-Symbol:** `android/app/src/main/res/drawable/ic_launcher_*.xml`

## Hinweise

- Der interne Paketname bleibt `app.ruhepol.ruhepol` (früherer Name). Würde er geändert,
  wäre es für Android eine neue App, und die Daten wären weg.
- `schluessel/ruhepol.keystore` signiert jede Version. Er liegt zusätzlich als Secret
  `RUHEPOL_KEYSTORE_B64` bei GitHub. **Geht er verloren, lassen sich keine Updates mehr
  installieren.** Die Kopie in OneDrive dient als Sicherung.
- Das Repository ist öffentlich, damit die App Updates ohne Zugangsdaten abrufen kann.
  Persönliche Daten liegen nur auf dem Handy, nie im Repository.
