import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'aufgaben_store.dart';
import 'datum.dart';
import 'modelle.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Erinnerungen.
// `planeErinnerungen` legt fest, WANN woran erinnert wird:
//   • Aufgabe mit Uhrzeit:   [vorlauf] Minuten vorher (Standard 15)
//   • Aufgabe ohne Uhrzeit:  am Fälligkeitstag um [morgens] (Standard 8:00)
//   • Frist:                 3 Tage vorher, 1 Tag vorher und am Tag selbst
//   • Tagesübersicht:        jeden Morgen um [uebersichtUm] (Standard 7:30)
// Geplant werden die nächsten 14 Tage. Die Liste geht an Android
// (Erinnerungen.kt), das die Wecker stellt. Bei jeder Änderung wird neu
// geplant. Eigene Regel ergänzen: in `planeErinnerungen` eine weitere
// `hinzu(...)`-Zeile schreiben.
// ---------------------------------------------------------------------------

const _planungsTage = 14;
const _maxErinnerungen = 150;
const _fristTage = [3, 1, 0];

class Erinnerung {
  Erinnerung({
    required this.zeit,
    required this.titel,
    required this.text,
    this.aufgabeId,
    this.id = 0,
  });

  int id;
  final DateTime zeit;
  final String titel;
  String text;

  /// null = keine Aufgabe (z. B. Tagesübersicht), dann ohne „Erledigt“-Knopf.
  final String? aufgabeId;

  Map<String, Object?> alsMap() => {
        'id': id,
        'zeit': zeit.millisecondsSinceEpoch,
        'titel': titel,
        'text': text,
        'aufgabeId': aufgabeId ?? '',
      };
}

DateTime _um(DateTime tag, int minute) =>
    DateTime(tag.year, tag.month, tag.day, minute ~/ 60, minute % 60);

/// Berechnet alle kommenden Erinnerungen (reine Funktion, gut testbar).
List<Erinnerung> planeErinnerungen({
  required List<Aufgabe> aufgaben,
  required List<Liste> listen,
  required List<Termin> termine,
  required ErinnerungsEinstellungen e,
  required DateTime jetzt,
}) {
  if (!e.aktiv) return [];
  final grenze = jetzt.add(const Duration(days: _planungsTage));
  final h = nurDatum(jetzt);
  final nachSchluessel = <String, Erinnerung>{};

  String listenName(String id) {
    for (final l in listen) {
      if (l.id == id) return l.name;
    }
    return '';
  }

  void hinzu(Aufgabe? a, DateTime zeit, String titel, String text) {
    if (!zeit.isAfter(jetzt) || zeit.isAfter(grenze)) return;
    final schluessel = '${a?.id ?? 'uebersicht'}|${zeit.millisecondsSinceEpoch}';
    final vorhanden = nachSchluessel[schluessel];
    if (vorhanden != null) {
      vorhanden.text = '${vorhanden.text} · $text';
      return;
    }
    nachSchluessel[schluessel] =
        Erinnerung(zeit: zeit, titel: titel, text: text, aufgabeId: a?.id);
  }

  for (final a in aufgaben) {
    if (a.erledigt || !a.erinnern) continue;
    final liste = listenName(a.listeId);
    final zusatz = liste.isEmpty ? '' : ' · $liste';

    final f = a.faellig;
    if (f != null) {
      final u = a.uhrzeit;
      if (u != null) {
        final zeit = _um(f, u).subtract(Duration(minutes: e.vorlauf));
        final text = e.vorlauf == 0
            ? 'Jetzt · ${uhrzeitText(u)} Uhr$zusatz'
            : 'Um ${uhrzeitText(u)} Uhr (in ${e.vorlauf} Min.)$zusatz';
        hinzu(a, zeit, a.titel, text);
      } else {
        hinzu(a, _um(f, e.morgens), a.titel, 'Heute fällig$zusatz');
      }
    }

    final frist = a.frist;
    if (e.fristen && frist != null) {
      for (final tage in _fristTage) {
        final text = switch (tage) {
          0 => 'Frist ist heute!',
          1 => 'Frist ist morgen',
          _ => 'Frist in $tage Tagen (${frist.day}.${frist.month}.)',
        };
        hinzu(a, _um(plusTage(frist, -tage), e.morgens), a.titel, text);
      }
    }
  }

  if (e.uebersicht) {
    for (var i = 0; i < 7; i++) {
      final tag = plusTage(h, i);
      final faellig = aufgaben
          .where((a) =>
              !a.erledigt && a.faellig != null && !a.faellig!.isAfter(tag))
          .toList()
        ..sort(AufgabenStore.sortierung);
      final anzahlTermine = termine.where((t) => t.amTag(tag)).length;
      if (faellig.isEmpty && anzahlTermine == 0) continue;

      final teile = <String>[
        if (faellig.isNotEmpty)
          '${faellig.length} ${faellig.length == 1 ? 'Aufgabe' : 'Aufgaben'}',
        if (anzahlTermine > 0)
          '$anzahlTermine ${anzahlTermine == 1 ? 'Termin' : 'Termine'}',
      ];
      final wichtigste = faellig.isEmpty
          ? null
          : (List<Aufgabe>.of(faellig)
                ..sort((a, b) => b.prioritaet.index.compareTo(a.prioritaet.index)))
              .first;
      final text = 'Heute: ${teile.join(', ')}'
          '${wichtigste != null ? '. Zuerst: ${wichtigste.titel}' : ''}';
      hinzu(null, _um(tag, e.uebersichtUm), 'Dein Tag', text);
    }
  }

  // Wochenrückblick sonntags um 18 Uhr
  if (e.rueckblick) {
    for (var i = 0; i < _planungsTage; i++) {
      final tag = plusTage(h, i);
      if (tag.weekday != DateTime.sunday) continue;
      hinzu(null, _um(tag, 18 * 60), 'Dein Wochenrückblick',
          'Schau dir an, was du diese Woche geschafft hast.');
    }
  }

  final liste = nachSchluessel.values.toList()
    ..sort((a, b) => a.zeit.compareTo(b.zeit));
  final gekuerzt = liste.take(_maxErinnerungen).toList();
  for (var i = 0; i < gekuerzt.length; i++) {
    gekuerzt[i].id = 1000 + i;
  }
  return gekuerzt;
}

enum ErinnerungsStatus { aus, keineBerechtigung, dauerhaftVerweigert, verbinde, aktiv }

class ErinnerungsDienst extends ChangeNotifier {
  ErinnerungsDienst(this._store, {MethodChannel? kanal})
      : _kanal = kanal ?? const MethodChannel('ruhepol/kalender') {
    _store.addListener(_storeGeaendert);
  }

  final AufgabenStore _store;
  final MethodChannel _kanal;

  ErinnerungsStatus status = ErinnerungsStatus.aus;
  String? fehler;

  /// Anzahl geplanter Erinnerungen und die nächste davon.
  int geplant = 0;
  Erinnerung? naechste;

  /// Darf Android auf die Minute genau erinnern?
  bool exakt = true;

  Timer? _planTimer;

  bool get aktiv => status == ErinnerungsStatus.aktiv;

  /// Beim App-Start und beim Zurückkehren in die App.
  Future<void> starten() async {
    try {
      await abholen();
      if (!_store.erinnerung.aktiv) return;
      final s = await _kanal.invokeMethod<String>('benachrichtigungStatus');
      exakt = await _kanal.invokeMethod<bool>('exakteWecker') ?? true;
      if (s == 'erteilt') {
        status = ErinnerungsStatus.aktiv;
        await planen();
      } else {
        status = s == 'dauerhaftVerweigert'
            ? ErinnerungsStatus.dauerhaftVerweigert
            : ErinnerungsStatus.keineBerechtigung;
        fehler = 'Agenda darf gerade keine Benachrichtigungen zeigen.';
      }
    } on MissingPluginException {
      // Kein Android (z. B. in Tests).
    } catch (e) {
      fehler = 'Erinnerungen konnten nicht geladen werden: $e';
    }
    notifyListeners();
  }

  /// Vom Knopf „Erinnerungen einschalten“.
  Future<void> einschalten() async {
    status = ErinnerungsStatus.verbinde;
    fehler = null;
    notifyListeners();
    try {
      final s = await _kanal.invokeMethod<String>('benachrichtigungAnfragen');
      exakt = await _kanal.invokeMethod<bool>('exakteWecker') ?? true;
      if (s == 'erteilt') {
        status = ErinnerungsStatus.aktiv;
        _store.erinnerungAendern((e) => e.aktiv = true);
        await planen();
      } else if (s == 'dauerhaftVerweigert') {
        status = ErinnerungsStatus.dauerhaftVerweigert;
        fehler = 'Benachrichtigungen sind für Agenda aus. Du kannst sie in den '
            'App-Einstellungen unter „Benachrichtigungen“ erlauben.';
      } else {
        status = ErinnerungsStatus.keineBerechtigung;
        fehler = 'Ohne Benachrichtigungen kann Agenda nicht erinnern.';
      }
    } catch (e) {
      status = ErinnerungsStatus.keineBerechtigung;
      fehler = 'Benachrichtigungen konnten nicht angefragt werden: $e';
    }
    notifyListeners();
  }

  Future<void> ausschalten() async {
    _planTimer?.cancel();
    _store.erinnerungAendern((e) => e.aktiv = false);
    status = ErinnerungsStatus.aus;
    fehler = null;
    geplant = 0;
    naechste = null;
    try {
      await _kanal.invokeMethod<int>('erinnerungenPlanen', {'liste': const []});
    } catch (_) {
      // Ohne Android nichts zu tun.
    }
    notifyListeners();
  }

  Future<void> einstellungenOeffnen() async {
    try {
      await _kanal.invokeMethod<void>('einstellungenOeffnen');
    } catch (_) {
      // Einstellungen ließen sich nicht öffnen.
    }
  }

  Future<void> testErinnerung() async {
    try {
      await _kanal.invokeMethod<void>('testErinnerung');
    } catch (e) {
      fehler = 'Test-Erinnerung fehlgeschlagen: $e';
      notifyListeners();
    }
  }

  /// Übernimmt Aufgaben, die über „Erledigt“ in der Benachrichtigung
  /// abgehakt wurden. Gibt die Anzahl zurück.
  Future<int> abholen() async {
    try {
      final ids = await _kanal.invokeListMethod<String>('erledigteAbholen') ?? const [];
      var anzahl = 0;
      for (final id in ids) {
        final a = _store.aufgabe(id);
        if (a != null && !a.erledigt) {
          _store.umschalten(id);
          anzahl++;
        }
      }
      return anzahl;
    } on MissingPluginException {
      return 0;
    }
  }

  void _storeGeaendert() {
    if (!aktiv) return;
    _planTimer?.cancel();
    _planTimer = Timer(const Duration(seconds: 2), planen);
  }

  /// Berechnet alle Erinnerungen neu und übergibt sie an Android.
  Future<void> planen() async {
    if (!aktiv) return;
    final liste = planeErinnerungen(
      aufgaben: _store.aufgaben,
      listen: _store.listen,
      termine: _store.termine,
      e: _store.erinnerung,
      jetzt: DateTime.now(),
    );
    try {
      await _kanal.invokeMethod<int>('erinnerungenPlanen', {
        'liste': [for (final e in liste) e.alsMap()],
      });
      geplant = liste.length;
      naechste = liste.isEmpty ? null : liste.first;
      fehler = null;
    } on MissingPluginException {
      // Ohne Android nichts zu tun.
    } catch (e) {
      fehler = 'Erinnerungen konnten nicht gestellt werden: $e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _planTimer?.cancel();
    _store.removeListener(_storeGeaendert);
    super.dispose();
  }
}

/// Macht den Erinnerungs-Dienst erreichbar: `ErinnerungsScope.of(context)`.
class ErinnerungsScope extends InheritedNotifier<ErinnerungsDienst> {
  const ErinnerungsScope({
    super.key,
    required ErinnerungsDienst dienst,
    required super.child,
  }) : super(notifier: dienst);

  static ErinnerungsDienst of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ErinnerungsScope>()!.notifier!;
}
