# Ruhepol

Deine To-Do-App für Android mit Google-Kalender, Pastellfarben und Material 3.
Gebaut mit Flutter. Die App wird in der Cloud (GitHub Actions) gebaut, nicht auf deinem PC.

## So kommt eine neue Version aufs Handy

1. Code wird geändert und zu GitHub hochgeladen (`git push`).
2. GitHub baut automatisch die App. Das dauert etwa 5 bis 8 Minuten.
3. Unter **Releases** im Repository erscheint `ruhepol-build-<Nummer>.apk`.
4. Auf dem Handy die APK herunterladen und antippen. Android installiert sie als Update.
   Deine Daten bleiben erhalten, weil jede Version mit demselben Schlüssel signiert ist.

## Ordner und Dateien

| Pfad | Inhalt |
|---|---|
| `lib/main.dart` | App-Start, Farbschema, Navigation, Seiten |
| `test/` | Automatische Tests, die bei jedem Build laufen |
| `pubspec.yaml` | Name, Version und benutzte Pakete |
| `.github/workflows/build.yml` | Anleitung für den Cloud-Build |
| `android/` | Android-Projektdateien. Sie werden beim ersten Build automatisch erzeugt. |
| `schluessel/` | **Nur lokal:** Signaturschlüssel. Nicht löschen und nicht weitergeben. |

## Selbst anpassen

- **Eigene Farbe hinzufügen:** In `lib/main.dart` im `enum Pastell` eine Zeile ergänzen.
- **Versionsnummer ändern:** In `pubspec.yaml` die Zeile `version:` anpassen. Die Build-Nummer hinter dem `+` setzt der Cloud-Build automatisch.

## Wichtig: der Signaturschlüssel

`schluessel/ruhepol.keystore` ist der Schlüssel, mit dem jede Version signiert wird.
Er liegt zusätzlich als Secret `RUHEPOL_KEYSTORE_B64` bei GitHub.
**Geht er verloren, lassen sich keine Updates mehr installieren.** Du müsstest die App dann
deinstallieren und verlierst dabei deine Daten. Die Kopie in OneDrive dient als Sicherung.
