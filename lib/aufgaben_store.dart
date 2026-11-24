import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'datum.dart';
import 'design.dart';
import 'modelle.dart';
import 'speicher.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Der „Store“ ist das Gedächtnis der App.
// Alle Seiten lesen Aufgaben und Listen von hier. Jede Änderung läuft über eine
// Methode dieser Klasse. Danach werden alle Seiten neu gezeichnet
// (notifyListeners) und die Daten kurz darauf gespeichert.
// ---------------------------------------------------------------------------

class AufgabenStore extends ChangeNotifier {
  AufgabenStore(this._speicher);

  final Speicher _speicher;

  List<Aufgabe> aufgaben = [];
  List<Liste> listen = [];
  Pastell farbe = Pastell.salbei;
  ThemeMode themeMode = ThemeMode.system;

  ErinnerungsEinstellungen erinnerung = ErinnerungsEinstellungen();

  /// Protokoll aller erledigten Aufgaben (für Statistik und Abzeichen).
  List<ErledigtEintrag> erledigtLog = [];

  /// Notizen (mit Aufgaben verknüpfbar).
  List<Notiz> notizen = [];

  /// Gespeicherte Vorlagen.
  List<Vorlage> vorlagen = [];

  /// Wie oft welcher Titel eingetragen wurde (Schlüssel: titelSchluessel).
  Map<String, Haeufig> haeufig = {};

  // Kalender des Handys
  /// Ist die Kalender-Anbindung eingeschaltet?
  bool kalenderAktiv = false;

  /// Kalender, in den Aufgaben eingetragen werden (ID auf dem Handy).
  /// null = eigener Kalender „Agenda“.
  String? kalenderId;

  /// Kalendereinträge gelöschter Aufgaben, die noch zu entfernen sind.
  List<String> zuLoeschendeTermine = [];

  /// Zuletzt geladene Termine.
  List<Termin> termine = [];
  DateTime? termineStand;

  String? _rueckgaengigStand;
  Timer? _speicherTimer;
  Future<void> _letzteSpeicherung = Future.value();

  // ------------------------------------------------------------ Laden/Speichern

  Future<void> laden() async {
    final daten = await _speicher.laden();
    if (daten == null) {
      _startdaten();
      _speichernJetzt();
    } else {
      _ausJson(daten);
    }
    notifyListeners();
  }

  Map<String, dynamic> _alsJson() => {
        'version': 1,
        'einstellungen': {
          'farbe': farbe.name,
          'themeMode': themeMode.name,
          'kalenderAktiv': kalenderAktiv,
          'erinnerungen': erinnerung.toJson(),
        },
        'listen': [for (final l in listen) l.toJson()],
        'aufgaben': [for (final a in aufgaben) a.toJson()],
        'erledigtLog': [for (final e in erledigtLog) e.toJson()],
        'notizen': [for (final n in notizen) n.toJson()],
        'vorlagen': [for (final v in vorlagen) v.toJson()],
        'haeufig': [for (final h in haeufig.values) h.toJson()],
        'kalender': {
          'id': kalenderId,
          'zuLoeschen': zuLoeschendeTermine,
          'termine': [for (final t in termine) t.toJson()],
          'stand': termineStand?.toIso8601String(),
        },
      };

  void _ausJson(Map<String, dynamic> d) {
    final e = Map<String, dynamic>.from(d['einstellungen'] as Map? ?? const {});
    farbe = Pastell.values.asNameMap()[e['farbe']] ?? Pastell.salbei;
    themeMode = ThemeMode.values.asNameMap()[e['themeMode']] ?? ThemeMode.system;
    kalenderAktiv = e['kalenderAktiv'] as bool? ?? false;
    erinnerung = ErinnerungsEinstellungen.fromJson(
      Map<String, dynamic>.from(e['erinnerungen'] as Map? ?? const {}),
    );
    final k =Map<String, dynamic>.from(d['kalender'] as Map? ?? const {});
    kalenderId = k['id'] as String?;
    zuLoeschendeTermine = [
      for (final id in (k['zuLoeschen'] as List? ?? const [])) id as String,
    ];
    termine = [
      for (final t in (k['termine'] as List? ?? const []))
        Termin.fromJson(Map<String, dynamic>.from(t as Map)),
    ];
    termineStand = k['stand'] is String ? DateTime.tryParse(k['stand'] as String) : null;
    _datenAusJson(d);

    vorlagen = [
      for (final v in (d['vorlagen'] as List? ?? const []))
        Vorlage.fromJson(Map<String, dynamic>.from(v as Map)),
    ];
    final h = d['haeufig'] as List?;
    haeufig = {};
    if (h != null) {
      for (final e in h) {
        final x = Haeufig.fromJson(Map<String, dynamic>.from(e as Map));
        haeufig[titelSchluessel(x.titel)] = x;
      }
    } else {
      // Ältere Daten: aus den vorhandenen Aufgaben zählen
      for (final a in aufgaben) {
        _haeufigMerken(a);
      }
    }
  }

  void _datenAusJson(Map<String, dynamic> d) {
    listen = [
      for (final l in (d['listen'] as List? ?? const []))
        Liste.fromJson(Map<String, dynamic>.from(l as Map)),
    ];
    aufgaben = [
      for (final a in (d['aufgaben'] as List? ?? const []))
        Aufgabe.fromJson(Map<String, dynamic>.from(a as Map)),
    ];
    if (listen.isEmpty) listen = _standardListen();

    notizen = [
      for (final n in (d['notizen'] as List? ?? const []))
        Notiz.fromJson(Map<String, dynamic>.from(n as Map)),
    ];

    final log = d['erledigtLog'] as List?;
    if (log != null) {
      erledigtLog = [
        for (final e in log) ErledigtEintrag.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    } else {
      // Ältere Daten ohne Protokoll: aus den erledigten Aufgaben übernehmen
      erledigtLog = [
        for (final a in aufgaben)
          if (a.erledigt && a.erledigtAm != null) ErledigtEintrag.aus(a, a.erledigtAm!),
      ]..sort((a, b) => a.zeit.compareTo(b.zeit));
    }
  }

  void _geaendert() {
    notifyListeners();
    _speicherTimer?.cancel();
    _speicherTimer = Timer(const Duration(milliseconds: 400), _speichernJetzt);
  }

  void _speichernJetzt() {
    _speicherTimer?.cancel();
    final daten = _alsJson();
    _letzteSpeicherung = _letzteSpeicherung
        .then((_) => _speicher.speichern(daten))
        .catchError((Object _) {});
  }

  /// Wird aufgerufen, wenn die App in den Hintergrund geht.
  void sofortSpeichern() {
    if (_speicherTimer?.isActive ?? false) _speichernJetzt();
  }

  @override
  void dispose() {
    _speicherTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ Startdaten

  List<Liste> _standardListen() => [
        Liste(id: 'privat', name: 'Privat', farbe: 0, icon: 'herz'),
        Liste(id: 'arbeit', name: 'Arbeit', farbe: 1, icon: 'arbeit'),
        Liste(id: 'haushalt', name: 'Haushalt', farbe: 2, icon: 'haus'),
        Liste(id: 'gesundheit', name: 'Gesundheit', farbe: 3, icon: 'gesundheit'),
        Liste(id: 'einkauf', name: 'Einkauf', farbe: 4, icon: 'einkauf'),
      ];

  void _startdaten() {
    listen = _standardListen();
    final h = heute();
    aufgaben = [
      Aufgabe(
        titel: 'Tippe auf den Kreis, um mich abzuhaken',
        listeId: 'privat',
        faellig: h,
      ),
      Aufgabe(
        titel: 'Tippe auf mich, um Details zu sehen',
        listeId: 'privat',
        faellig: h,
        prioritaet: Prioritaet.mittel,
        unteraufgaben: [
          Unteraufgabe(titel: 'Unteraufgaben abhaken'),
          Unteraufgabe(titel: 'Frist und Wiederholung einstellen'),
        ],
      ),
      Aufgabe(
        titel: 'Wische mich nach links, um mich zu löschen',
        listeId: 'privat',
        faellig: h,
      ),
      Aufgabe(
        titel: 'Tippe auf „Aufgabe“ und schreib: Zahnarzt morgen 15 Uhr #Gesundheit !!',
        listeId: 'gesundheit',
        faellig: h,
        frist: plusTage(h, 1),
      ),
    ];
  }

  // ------------------------------------------------------------ Rückgängig

  void _merken() {
    _rueckgaengigStand = jsonEncode({
      'listen': [for (final l in listen) l.toJson()],
      'aufgaben': [for (final a in aufgaben) a.toJson()],
      'erledigtLog': [for (final e in erledigtLog) e.toJson()],
      'notizen': [for (final n in notizen) n.toJson()],
    });
  }

  void rueckgaengig() {
    final stand = _rueckgaengigStand;
    if (stand == null) return;
    _datenAusJson(Map<String, dynamic>.from(jsonDecode(stand) as Map));
    _rueckgaengigStand = null;
    _geaendert();
  }

  // ------------------------------------------------------------ Abfragen

  Aufgabe? aufgabe(String id) {
    for (final a in aufgaben) {
      if (a.id == id) return a;
    }
    return null;
  }

  Liste listeVon(String id) =>
      listen.firstWhere((l) => l.id == id, orElse: () => listen.first);

  /// Sortierung: offen vor erledigt, dann nach Datum, Uhrzeit, Priorität.
  static int sortierung(Aufgabe a, Aufgabe b) {
    if (a.erledigt != b.erledigt) return a.erledigt ? 1 : -1;
    final fa = a.faellig, fb = b.faellig;
    if (fa != fb) {
      if (fa == null) return 1;
      if (fb == null) return -1;
      final c = fa.compareTo(fb);
      if (c != 0) return c;
    }
    final za = a.uhrzeit ?? 24 * 60, zb = b.uhrzeit ?? 24 * 60;
    if (za != zb) return za.compareTo(zb);
    if (a.prioritaet != b.prioritaet) {
      return b.prioritaet.index.compareTo(a.prioritaet.index);
    }
    return a.erstellt.compareTo(b.erstellt);
  }

  // ------------------------------------------------------------ Aufgaben ändern

  void hinzufuegen(Aufgabe a) {
    _merken();
    aufgaben.add(a);
    _haeufigMerken(a);
    _geaendert();
  }

  void _haeufigMerken(Aufgabe a) {
    final k = titelSchluessel(a.titel);
    if (k.isEmpty) return;
    final bisher = haeufig[k];
    haeufig[k] = Haeufig(
      titel: a.titel.trim(),
      listeId: a.listeId,
      anzahl: (bisher?.anzahl ?? 0) + 1,
      prioritaet: a.prioritaet,
      dauer: a.dauer,
    );
  }

  /// Wie oft wurde dieser Titel schon eingetragen?
  int haeufigkeit(String titel) => haeufig[titelSchluessel(titel)]?.anzahl ?? 0;

  // ------------------------------------------------------------ Vorlagen

  Vorlage? vorlageFuer(String titel) {
    final k = titelSchluessel(titel);
    for (final v in vorlagen) {
      if (titelSchluessel(v.titel) == k) return v;
    }
    return null;
  }

  /// Speichert eine Aufgabe als Vorlage (ersetzt eine gleichnamige).
  Vorlage vorlageSpeichern(Aufgabe a) {
    final neu = Vorlage.aus(a);
    final alt = vorlageFuer(a.titel);
    if (alt != null) vorlagen.remove(alt);
    vorlagen.add(neu);
    _geaendert();
    return neu;
  }

  void vorlageLoeschen(String id) {
    vorlagen.removeWhere((v) => v.id == id);
    _geaendert();
  }

  /// Vorschläge für das Eingabefenster: Vorlagen und häufige Einträge
  /// (mindestens 2×), passend zum bisher getippten [filter].
  ({List<Vorlage> vorlagen, List<Haeufig> haeufig}) vorschlaege({String filter = '', int max = 6}) {
    final f = titelSchluessel(filter);
    bool passt(String titel) => f.isEmpty || titelSchluessel(titel).contains(f);
    final v = vorlagen.where((x) => passt(x.titel)).toList()
      ..sort((a, b) => haeufigkeit(b.titel).compareTo(haeufigkeit(a.titel)));
    final vorlagenSchluessel = {for (final x in vorlagen) titelSchluessel(x.titel)};
    final offen = {for (final a in aufgaben) if (!a.erledigt) titelSchluessel(a.titel)};
    final h = haeufig.entries
        .where((e) =>
            e.value.anzahl >= 2 &&
            !vorlagenSchluessel.contains(e.key) &&
            !offen.contains(e.key) &&
            passt(e.value.titel) &&
            e.key != f)
        .map((e) => e.value)
        .toList()
      ..sort((a, b) {
        final c = b.anzahl.compareTo(a.anzahl);
        return c != 0 ? c : b.zuletzt.compareTo(a.zuletzt);
      });
    return (vorlagen: v.take(max).toList(), haeufig: h.take(max).toList());
  }

  // ------------------------------------------------------------ Notizen

  Notiz? notiz(String id) {
    for (final n in notizen) {
      if (n.id == id) return n;
    }
    return null;
  }

  Notiz notizAnlegen({String? aufgabeId, String titel = ''}) {
    final n = Notiz(
      titel: titel,
      farbe: notizen.length % listenFarben.length,
      aufgabenIds: [if (aufgabeId != null) aufgabeId],
    );
    notizen.add(n);
    _geaendert();
    return n;
  }

  /// Nach direktem Bearbeiten einer Notiz aufrufen.
  void notizGeaendert(Notiz n) {
    n.geaendert = DateTime.now();
    _geaendert();
  }

  void notizLoeschen(String id) {
    _merken();
    notizen.removeWhere((n) => n.id == id);
    _geaendert();
  }

  /// Leere, unverknüpfte Notizen still entfernen (z. B. beim Schließen).
  void leereNotizEntfernen(String id) {
    final n = notiz(id);
    if (n != null && n.istLeer && n.aufgabenIds.isEmpty) {
      notizen.remove(n);
      _geaendert();
    }
  }

  void verknuepfen(String notizId, String aufgabeId) {
    final n = notiz(notizId);
    if (n == null || n.aufgabenIds.contains(aufgabeId)) return;
    n.aufgabenIds.add(aufgabeId);
    _geaendert();
  }

  void verknuepfungLoesen(String notizId, String aufgabeId) {
    notiz(notizId)?.aufgabenIds.remove(aufgabeId);
    _geaendert();
  }

  List<Notiz> notizenZu(String aufgabeId) =>
      notizen.where((n) => n.aufgabenIds.contains(aufgabeId)).toList();

  List<Aufgabe> aufgabenZu(Notiz n) => [
        for (final id in n.aufgabenIds)
          if (aufgabe(id) case final a?) a,
      ];

  // ------------------------------------------------------------ Planen

  /// Verschiebt eine Aufgabe auf einen anderen Tag (Uhrzeit bleibt).
  void verschieben(String id, DateTime tag) {
    final a = aufgabe(id);
    if (a == null) return;
    _merken();
    a.faellig = nurDatum(tag);
    _geaendert();
  }

  /// Übernimmt einen Tagesplan: Aufgabe-ID → Minute des Tages.
  void tagesplanUebernehmen(DateTime tag, Map<String, int> plan) {
    _merken();
    for (final e in plan.entries) {
      final a = aufgabe(e.key);
      if (a == null) continue;
      a.faellig = nurDatum(tag);
      a.uhrzeit = e.value;
    }
    _geaendert();
  }

  /// Nach direktem Bearbeiten einer Aufgabe aufrufen (Titel, Datum …).
  void geaendert() => _geaendert();

  /// Hakt ab bzw. öffnet wieder. Gibt bei Wiederholungen die neue Aufgabe zurück.
  Aufgabe? umschalten(String id) {
    final a = aufgabe(id);
    if (a == null) return null;
    _merken();
    a.erledigt = !a.erledigt;
    a.erledigtAm = a.erledigt ? DateTime.now() : null;
    if (a.erledigt) {
      erledigtLog.add(ErledigtEintrag.aus(a, a.erledigtAm!));
    } else {
      final i = erledigtLog.lastIndexWhere((e) => e.aufgabeId == a.id);
      if (i >= 0) erledigtLog.removeAt(i);
    }

    Aufgabe? naechste;
    final w = a.wiederholung;
    if (a.erledigt && w != null) {
      final basis = w.abErledigung ? heute() : (a.faellig ?? heute());
      final neu = w.naechstes(basis);
      final verschiebung = tageZwischen(a.faellig ?? basis, neu);
      naechste = Aufgabe(
        titel: a.titel,
        listeId: a.listeId,
        notiz: a.notiz,
        faellig: neu,
        uhrzeit: a.uhrzeit,
        frist: a.frist == null ? null : plusTage(a.frist!, verschiebung),
        prioritaet: a.prioritaet,
        unteraufgaben: [
          for (final u in a.unteraufgaben) Unteraufgabe(titel: u.titel),
        ],
        wiederholung: w,
        erinnern: a.erinnern,
        dauer: a.dauer,
      );
      // Verknüpfte Notizen gelten auch für die nächste Wiederholung
      for (final n in notizen) {
        if (n.aufgabenIds.contains(a.id)) n.aufgabenIds.add(naechste.id);
      }
      a.wiederholung = null; // nur die neue Aufgabe wiederholt sich weiter
      aufgaben.add(naechste);
    }
    _geaendert();
    return naechste;
  }

  void loeschen(String id) {
    _merken();
    final eventId = aufgabe(id)?.kalenderEventId;
    if (eventId != null) zuLoeschendeTermine.add(eventId);
    aufgaben.removeWhere((a) => a.id == id);
    for (final n in notizen) {
      n.aufgabenIds.remove(id);
    }
    _geaendert();
  }

  /// Eisenhower-Matrix: Aufgabe in ein anderes Feld ziehen.
  /// Wichtig → Priorität mindestens „Mittel“, unwichtig → höchstens „Niedrig“.
  /// Dringend → fällig heute, nicht dringend → Datum entfernen.
  void matrixVerschieben(String id, {required bool wichtig, required bool dringend}) {
    final a = aufgabe(id);
    if (a == null) return;
    _merken();
    final h = heute();
    if (wichtig && !istWichtig(a)) a.prioritaet = Prioritaet.mittel;
    if (!wichtig && istWichtig(a)) a.prioritaet = Prioritaet.niedrig;
    if (dringend && !istDringend(a, h)) a.faellig = h;
    if (!dringend && a.faellig != null && !a.faellig!.isAfter(plusTage(h, 1))) {
      a.faellig = null;
      a.uhrzeit = null;
    }
    _geaendert();
  }

  int ueberfaelligeAufHeute() {
    _merken();
    final h = heute();
    var anzahl = 0;
    for (final a in aufgaben) {
      if (!a.erledigt && a.faellig != null && a.faellig!.isBefore(h)) {
        a.faellig = h;
        anzahl++;
      }
    }
    _geaendert();
    return anzahl;
  }

  // ------------------------------------------------------------ Listen

  Liste listeAnlegen(String name, {int? farbe, String icon = 'liste'}) {
    final l = Liste(name: name, farbe: farbe ?? listen.length, icon: icon);
    listen.add(l);
    _geaendert();
    return l;
  }

  void listeLoeschen(String id) {
    if (listen.length <= 1) return;
    _merken();
    listen.removeWhere((l) => l.id == id);
    final ersatz = listen.first.id;
    for (final a in aufgaben) {
      if (a.listeId == id) a.listeId = ersatz;
    }
    _geaendert();
  }

  // ------------------------------------------------------------ Kalender

  /// Termine an einem Tag, sortiert (ganztägige zuerst).
  List<Termin> termineAm(DateTime tag) => termine.where((t) => t.amTag(tag)).toList()
    ..sort((a, b) {
      if (a.ganztaegig != b.ganztaegig) return a.ganztaegig ? -1 : 1;
      return a.start.compareTo(b.start);
    });

  void termineSetzen(List<Termin> neu) {
    termine = neu;
    termineStand = DateTime.now();
    _geaendert();
  }

  void kalenderAktivSetzen(bool wert) {
    if (kalenderAktiv == wert) return;
    kalenderAktiv = wert;
    _geaendert();
  }

  /// Wechselt den Kalender für Aufgaben. Alte Einträge werden entfernt und
  /// im neuen Kalender neu angelegt.
  void zielKalenderSetzen(String? id) {
    if (kalenderId == id) return;
    for (final a in aufgaben) {
      final e = a.kalenderEventId;
      if (e != null) zuLoeschendeTermine.add(e);
      a.kalenderEventId = null;
      a.kalenderStand = null;
    }
    kalenderId = id;
    _geaendert();
  }

  /// Vom Kalender-Abgleich aufgerufen (Event-IDs gesetzt usw.), ohne Rückgängig.
  void kalenderDatenGeaendert() => _geaendert();

  /// Beim Ausschalten: Termine ausblenden. Die Verknüpfungen bleiben,
  /// damit beim erneuten Einschalten keine doppelten Einträge entstehen.
  void termineAusblenden() {
    termine = [];
    termineStand = null;
    _geaendert();
  }

  // ------------------------------------------------------------ Einstellungen

  void farbeSetzen(Pastell p) {
    farbe = p;
    _geaendert();
  }

  /// Ändert die Erinnerungs-Einstellungen, z. B.
  /// `store.erinnerungAendern((e) => e.vorlauf = 30)`.
  void erinnerungAendern(void Function(ErinnerungsEinstellungen e) aenderung) {
    aenderung(erinnerung);
    _geaendert();
  }

  void themeModeSetzen(ThemeMode m) {
    themeMode = m;
    _geaendert();
  }
}

/// Eisenhower: wichtig = Priorität „Mittel“ oder „Hoch“.
bool istWichtig(Aufgabe a) => a.prioritaet.index >= Prioritaet.mittel.index;

/// Eisenhower: dringend = fällig bis morgen oder Frist in höchstens 2 Tagen.
bool istDringend(Aufgabe a, DateTime heute) =>
    (a.faellig != null && !a.faellig!.isAfter(plusTage(heute, 1))) ||
    (a.frist != null && !a.frist!.isAfter(plusTage(heute, 2)));

/// Macht den Store für alle Seiten erreichbar: `StoreScope.of(context)`.
class StoreScope extends InheritedNotifier<AufgabenStore> {
  const StoreScope({
    super.key,
    required AufgabenStore store,
    required super.child,
  }) : super(notifier: store);

  /// Liest den Store und zeichnet das Widget bei Änderungen neu.
  static AufgabenStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Liest den Store ohne Neuzeichnen (für Klick-Aktionen).
  static AufgabenStore lesen(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
