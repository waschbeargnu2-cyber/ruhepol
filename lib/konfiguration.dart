// ---------------------------------------------------------------------------
// ERKLÄRUNG: Einstellungen für die Google-Anbindung.
// Die Web-Client-ID stammt aus der Google Cloud Console
// (siehe docs/GOOGLE_EINRICHTUNG.md, Schritt 7). Sie ist nicht geheim.
// ---------------------------------------------------------------------------

const googleWebClientId = 'NOCH_NICHT_EINGETRAGEN';

bool get googleEingerichtet => googleWebClientId.endsWith('.apps.googleusercontent.com');

/// Name des eigenen Kalenders, in den Ruhepol Aufgaben mit Uhrzeit einträgt.
const ruhepolKalenderName = 'Ruhepol';

/// Zeitzone für neue Kalendereinträge.
const zeitzone = 'Europe/Berlin';

/// Standarddauer eines Kalendereintrags für eine Aufgabe (Minuten).
const standardDauerMinuten = 30;

/// Berechtigungen: eigenen Kalender verwalten, andere Kalender nur lesen.
const googleBerechtigungen = <String>[
  'https://www.googleapis.com/auth/calendar.app.created',
  'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
  'https://www.googleapis.com/auth/calendar.events.readonly',
];
