// ---------------------------------------------------------------------------
// ERKLÄRUNG: Einstellungen für die Kalender-Anbindung.
// ---------------------------------------------------------------------------

/// Internes Konto des eigenen Kalenders auf dem Handy. Nicht ändern,
/// sonst legt die App einen zweiten Kalender an (stammt vom alten Namen).
const ruhepolKalenderName = 'Ruhepol';

/// Angezeigter Name des eigenen Kalenders (z. B. im Samsung Kalender).
const kalenderAnzeigeName = 'Agenda';

/// Farbe dieses Kalenders (Salbei).
const ruhepolKalenderFarbe = 0xFF7FA88C;

/// Standarddauer einer Aufgabe ohne eigene Dauer (Minuten).
const standardDauerMinuten = 30;

/// Zeitfenster für freie Lücken und „Tag planen“ (Minuten seit Mitternacht).
const tagBeginn = 8 * 60;
const tagEnde = 20 * 60;

/// Kleine Pause zwischen zwei eingeplanten Aufgaben (Minuten).
const planungsPuffer = 10;

/// Zeitraum, aus dem Termine gelesen werden.
const termineTageZurueck = 7;
const termineTageVoraus = 60;
