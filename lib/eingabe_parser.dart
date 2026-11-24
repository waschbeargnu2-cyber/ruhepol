import 'datum.dart';
import 'modelle.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Eingabe in normaler Sprache
// Aus „Zahnarzt morgen 15 Uhr #Gesundheit !!“ wird:
//   Titel „Zahnarzt“, morgen, 15:00, Liste Gesundheit, Priorität hoch.
// Jede Regel unten sucht ein Muster (regulärer Ausdruck), merkt sich den Wert
// und entfernt das Wort aus dem Titel. Neue Regel = neuer `nimm(...)`-Aufruf.
// ---------------------------------------------------------------------------

class ParseErgebnis {
  String titel = '';
  DateTime? faellig;
  int? uhrzeit;
  String? listeName;
  String? listeId;
  Prioritaet prioritaet = Prioritaet.keine;
  Wiederholung? wiederholung;
  DateTime? frist;
}

const _tage = [
  'montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag', 'samstag', 'sonntag',
];
const _tagNamen = 'montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag';
const _tagAusdruck =
    r'(heute|morgen|übermorgen|' + _tagNamen + r'|\d{1,2}\.\d{1,2}\.(?:\d{2,4})?)';

ParseErgebnis analysiere(
  String eingabe, {
  required DateTime heute,
  required List<Liste> listen,
}) {
  final r = ParseErgebnis();
  var x = ' $eingabe ';
  var abErledigung = false;

  void nimm(String muster, void Function(Match m) aktion) {
    final re = RegExp(muster, caseSensitive: false, unicode: true);
    x = x.replaceFirstMapped(re, (m) {
      aktion(m);
      return ' ';
    });
  }

  // #Liste
  nimm(r'\s#([\p{L}\d_-]+)', (m) {
    final name = m[1]!;
    r.listeName = name;
    final klein = name.toLowerCase();
    for (final l in listen) {
      if (l.name.toLowerCase() == klein) {
        r.listeId = l.id;
        return;
      }
    }
    for (final l in listen) {
      if (l.name.toLowerCase().startsWith(klein)) {
        r.listeId = l.id;
        return;
      }
    }
  });

  // Priorität: ! / !! / !!! oder !hoch, !mittel, !niedrig
  nimm(r'\s!(hoch|mittel|niedrig|!{0,2})(?=\s)', (m) {
    final v = m[1]!.toLowerCase();
    r.prioritaet = switch (v) {
      'hoch' => Prioritaet.hoch,
      'mittel' => Prioritaet.mittel,
      'niedrig' => Prioritaet.niedrig,
      // „!“ = niedrig, „!!“ = mittel, „!!!“ = hoch
      _ => Prioritaet.values[v.length + 1],
    };
  });

  // Wiederholungen
  nimm(r'\s(?:täglich|jeden tag)(?=\s)',
      (_) => r.wiederholung = const Wiederholung(art: Intervall.tage));
  nimm(r'\s(?:wöchentlich|jede woche)(?=\s)',
      (_) => r.wiederholung = const Wiederholung(art: Intervall.wochen));
  nimm(r'\s(?:monatlich|jeden monat)(?=\s)',
      (_) => r.wiederholung = const Wiederholung(art: Intervall.monate));
  nimm(r'\s(?:jährlich|jedes jahr)(?=\s)',
      (_) => r.wiederholung = const Wiederholung(art: Intervall.monate, anzahl: 12));
  nimm(r'\salle (\d{1,2}) (tage|wochen|monate)(?=\s)', (m) {
    final art = switch (m[2]!.toLowerCase()) {
      'wochen' => Intervall.wochen,
      'monate' => Intervall.monate,
      _ => Intervall.tage,
    };
    r.wiederholung = Wiederholung(art: art, anzahl: int.parse(m[1]!));
  });
  nimm(r'\sjeden (' + _tagNamen + r')(?=\s)', (m) {
    r.wiederholung = const Wiederholung(art: Intervall.wochen);
    r.faellig = _tag(m[1]!, heute, heuteErlaubt: true);
  });
  nimm(r'\snach (?:dem )?erledigen(?=\s)', (_) => abErledigung = true);

  // Frist: „bis Freitag“, „Frist 15.12.“
  nimm(r'\s(?:bis|frist)\s+(?:zum\s+|am\s+)?' + _tagAusdruck + r'(?=\s)',
      (m) => r.frist = _tag(m[1]!, heute));

  // Fälligkeit: „morgen“, „am Freitag“, „15.12.“
  nimm(r'\s(?:am\s+|nächsten\s+|kommenden\s+)?' + _tagAusdruck + r'(?=\s)',
      (m) => r.faellig ??= _tag(m[1]!, heute));
  nimm(r'\snächste woche(?=\s)', (_) => r.faellig ??= _tag('montag', heute));

  // Uhrzeit: „18:30“, „um 9 Uhr“, „15.30 Uhr“
  nimm(r'\s(?:um\s+)?(\d{1,2}):(\d{2})(?:\s*uhr)?(?=\s)', (m) {
    r.uhrzeit = _zeit(m[1]!, m[2]!);
  });
  if (r.uhrzeit == null) {
    nimm(r'\s(?:um\s+)?(\d{1,2})(?:\.(\d{2}))?\s*uhr(?=\s)', (m) {
      r.uhrzeit = _zeit(m[1]!, m[2] ?? '00');
    });
  }

  if (abErledigung && r.wiederholung != null) {
    r.wiederholung = r.wiederholung!.mitAbErledigung(true);
  }
  if ((r.uhrzeit != null || r.wiederholung != null) && r.faellig == null) {
    r.faellig = heute;
  }
  r.titel = x.replaceAll(RegExp(r'\s+'), ' ').trim();
  return r;
}

int? _zeit(String stunde, String minute) {
  final h = int.parse(stunde), m = int.parse(minute);
  if (h > 23 || m > 59) return null;
  return h * 60 + m;
}

DateTime? _tag(String wort, DateTime heute, {bool heuteErlaubt = false}) {
  final w = wort.toLowerCase();
  if (w == 'heute') return heute;
  if (w == 'morgen') return plusTage(heute, 1);
  if (w == 'übermorgen') return plusTage(heute, 2);

  final datum = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})?').firstMatch(w);
  if (datum != null) {
    final tag = int.parse(datum[1]!), monat = int.parse(datum[2]!);
    if (monat < 1 || monat > 12 || tag < 1 || tag > 31) return null;
    var jahr = datum[3] == null ? heute.year : int.parse(datum[3]!);
    if (jahr < 100) jahr += 2000;
    var d = DateTime(jahr, monat, tag);
    if (datum[3] == null && d.isBefore(heute)) d = DateTime(jahr + 1, monat, tag);
    return d;
  }

  final i = _tage.indexOf(w);
  if (i < 0) return null;
  var abstand = (i + 1 - heute.weekday + 7) % 7;
  if (abstand == 0 && !heuteErlaubt) abstand = 7;
  return plusTage(heute, abstand);
}
