# Google Kalender einrichten (einmalig, ca. 15 Minuten)

Damit Ruhepol deinen Google Kalender lesen und Aufgaben eintragen darf, braucht die App bei Google
ein eigenes „Projekt“ mit Zugangsdaten. Das ist kostenlos. Alles passiert unter
**https://console.cloud.google.com**, angemeldet mit deinem Google-Konto.

Google benennt Menüpunkte gelegentlich um. Wenn etwas anders heißt, such nach dem fett gedruckten Begriff.

## 1. Projekt anlegen
1. Oben links neben „Google Cloud“ auf die **Projektauswahl** klicken, dann auf **Neues Projekt**.
2. Projektname: `Ruhepol`. Dann **Erstellen**.
3. Prüfe, dass oben das Projekt **Ruhepol** ausgewählt ist.

## 2. Google Calendar API einschalten
1. Menü (☰) → **APIs und Dienste** → **Bibliothek**
2. Nach **Google Calendar API** suchen, öffnen und auf **Aktivieren** klicken.

## 3. Anmeldebildschirm einrichten („Google Auth Platform“)
1. Menü (☰) → **APIs und Dienste** → **OAuth-Zustimmungsbildschirm**. Das führt zur
   „Google Auth Platform“. Dort auf **Jetzt starten** klicken.
2. App-Informationen: App-Name `Ruhepol`, Nutzersupport-E-Mail = deine Gmail-Adresse → **Weiter**
3. Zielgruppe: **Extern** → **Weiter**
4. Kontaktdaten: deine Gmail-Adresse → **Weiter**. Den Richtlinien zustimmen und **Erstellen**.

## 4. App auf „In Produktion“ stellen
1. Links **Zielgruppe** öffnen und auf **App veröffentlichen** klicken, dann bestätigen.
2. *Warum?* Im Testmodus verfällt die Kalender-Freigabe alle 7 Tage. Da nur du die App nutzt,
   brauchst du keine Prüfung durch Google. Beim Anmelden erscheint einmal die Warnung
   „Google hat diese App nicht überprüft“. Tippe dort auf **Erweitert → Zu Ruhepol wechseln**.

## 5. Berechtigungen eintragen (empfohlen)
1. Links **Datenzugriff** → **Bereiche hinzufügen oder entfernen**
2. In der Filterzeile `calendar` eingeben und diese drei Bereiche anhaken:
   - `.../auth/calendar.app.created`: eigenen Kalender „Ruhepol“ anlegen und darin Aufgaben eintragen
   - `.../auth/calendar.calendarlist.readonly`: Liste deiner Kalender sehen
   - `.../auth/calendar.events.readonly`: deine Termine lesen
3. **Aktualisieren**, dann unten **Speichern**.

Ruhepol kann damit deine bestehenden Termine **nur lesen**. Schreiben darf es ausschließlich in
seinen eigenen Kalender „Ruhepol“.

## 6. Android-Client anlegen
1. Links **Clients** → **Client erstellen**
2. Anwendungstyp: **Android**
3. Name: `Ruhepol Android`
4. Paketname: `app.ruhepol.ruhepol`
5. SHA-1-Zertifikatfingerabdruck:
   `5D:51:57:4D:2A:B3:F0:AA:0D:48:9A:DF:77:84:ED:D2:8E:BC:4E:A4`
6. **Erstellen**

## 7. Web-Client anlegen (wird für die Android-Anmeldung gebraucht)
1. Wieder **Clients** → **Client erstellen**
2. Anwendungstyp: **Webanwendung**, Name: `Ruhepol Web`. Alle anderen Felder bleiben leer.
3. **Erstellen**. Es erscheint eine **Client-ID** in dieser Form:
   `123456789012-abc123def456.apps.googleusercontent.com`
4. **Nur diese Client-ID** an Claude schicken. Den „Clientschlüssel“ (Client Secret) NICHT
   weitergeben, er wird nicht gebraucht.

Die Client-ID kommt in `lib/konfiguration.dart`. Sie ist nicht geheim, denn sie funktioniert nur
zusammen mit dem Signaturschlüssel der App.
