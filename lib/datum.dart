// ERKLÄRUNG: Kleine Helfer für deutsche Datumsangaben.

const wochentage = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag',
];
const wochentageKurz = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const monate = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

DateTime nurDatum(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime heute() => nurDatum(DateTime.now());

DateTime plusTage(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Anzahl Kalendertage von [von] bis [bis] (Sommerzeit-sicher).
int tageZwischen(DateTime von, DateTime bis) =>
    DateTime.utc(bis.year, bis.month, bis.day)
        .difference(DateTime.utc(von.year, von.month, von.day))
        .inDays;

/// „Heute“, „Morgen“, „Freitag“ oder „Mo, 15.12.“
String relativ(DateTime d, {DateTime? bezug}) {
  final h = bezug ?? heute();
  final n = tageZwischen(h, d);
  if (n == 0) return 'Heute';
  if (n == 1) return 'Morgen';
  if (n == -1) return 'Gestern';
  if (n == 2) return 'Übermorgen';
  if (n > 2 && n < 7) return wochentage[d.weekday - 1];
  final jahr = d.year != h.year ? '${d.year}' : '';
  return '${wochentageKurz[d.weekday - 1]}, ${d.day}.${d.month}.$jahr';
}

String langesDatum(DateTime d) =>
    '${wochentage[d.weekday - 1]}, ${d.day}. ${monate[d.month - 1]}';

String uhrzeitText(int minuten) =>
    '${(minuten ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuten % 60).toString().padLeft(2, '0')}';
