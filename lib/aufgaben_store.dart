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

  // Google Kalender
  /// Wurde Google schon einmal verbunden? Dann beim Start still neu verbinden.
  bool googleAktiv = false;

  /// ID des eigenen Kalenders „Ruhepol“ bei Google.
  String? kalenderId;

  /// Kalendereinträge gelöschter Aufgaben, die noch bei Google zu entfernen sind.
  List<String> zuLoeschendeTermine = [];

  /// Zuletzt geladene Google-Termine (auch offline sichtbar).
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
          'googleAktiv': googleAktiv,
        },
        'listen': [for (final l in listen) l.toJson()],
        'aufgaben': [for (final a in aufgaben) a.toJson()],
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
    googleAktiv = e['googleAktiv'] as bool? ?? false;
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
      );
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

  // ------------------------------------------------------------ Google Kalender

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

  void googleAktivSetzen(bool wert) {
    if (googleAktiv == wert) return;
    googleAktiv = wert;
    _geaendert();
  }

  /// Vom Kalender-Abgleich aufgerufen (Event-IDs gesetzt usw.), ohne Rückgängig.
  void kalenderDatenGeaendert() => _geaendert();

  /// Beim Trennen von Google: Termine ausblenden. Die Verknüpfungen bleiben,
  /// damit beim erneuten Verbinden keine doppelten Einträge entstehen.
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

  void themeModeSetzen(ThemeMode m) {
    themeMode = m;
    _geaendert();
  }
}

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
