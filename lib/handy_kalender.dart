import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'aufgaben_store.dart';
import 'datum.dart';
import 'konfiguration.dart';
import 'modelle.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Verbindung zum Kalender des Handys.
// Agenda nutzt die Kalender, die auf dem Galaxy eingerichtet sind (Google,
// Samsung …). Android gleicht sie selbst mit Google ab. Dafür braucht es
// kein Google-Konto in der App und keine Cloud.
//   Lesen:     Termine aus allen sichtbaren Kalendern (7 Tage zurück, 60 voraus)
//   Schreiben: Aufgaben mit Datum UND Uhrzeit kommen in den gewählten Kalender
//              (Standard: eigener Kalender „Agenda“, nur auf dem Handy).
// Der Android-Teil steht in android/app/src/main/kotlin/.../MainActivity.kt.
// ---------------------------------------------------------------------------

enum KalenderStatus { aus, keinZugriff, dauerhaftVerweigert, verbinde, verbunden }

class KalenderInfo {
  const KalenderInfo({
    required this.id,
    required this.name,
    required this.schreibbar,
    required this.sichtbar,
    this.konto,
    this.kontoTyp,
    this.farbe,
  });

  factory KalenderInfo.ausMap(Map<dynamic, dynamic> m) => KalenderInfo(
        id: '${m['id']}',
        name: m['name'] as String? ?? 'Kalender',
        konto: m['konto'] as String?,
        kontoTyp: m['kontoTyp'] as String?,
        farbe: (m['farbe'] as num?)?.toInt(),
        schreibbar: m['schreibbar'] == true,
        sichtbar: m['sichtbar'] == true,
      );

  final String id;
  final String name;
  final String? konto;
  final String? kontoTyp;
  final int? farbe;
  final bool schreibbar;
  final bool sichtbar;

  bool get istEigener => kontoTyp == 'LOCAL' && konto == ruhepolKalenderName;

  String get herkunft => switch (kontoTyp) {
        'com.google' => 'Google${konto != null ? ' · $konto' : ''}',
        'LOCAL' => 'Nur auf diesem Handy',
        _ => konto ?? kontoTyp ?? '',
      };
}

class KalenderDienst extends ChangeNotifier {
  KalenderDienst(this._store, {MethodChannel? kanal})
      : _kanal = kanal ?? const MethodChannel('ruhepol/kalender') {
    _store.addListener(_storeGeaendert);
  }

  final AufgabenStore _store;
  final MethodChannel _kanal;

  KalenderStatus status = KalenderStatus.aus;
  String? fehler;
  bool laedt = false;

  /// Alle Kalender auf dem Handy.
  List<KalenderInfo> kalender = [];

  Timer? _syncTimer;
  bool _syncLaeuft = false;
  bool _nochmal = false;

  bool get verbunden => status == KalenderStatus.verbunden;

  /// Kalender, in die Agenda schreiben darf.
  List<KalenderInfo> get schreibbareKalender =>
      kalender.where((k) => k.schreibbar && k.sichtbar).toList();

  /// Kalender, in den Aufgaben gerade eingetragen werden.
  KalenderInfo? get zielKalender {
    final id = _store.kalenderId;
    for (final k in kalender) {
      if (id == null ? k.istEigener : k.id == id) return k;
    }
    return null;
  }

  // ------------------------------------------------------------ Zugriff

  /// Beim App-Start: weitermachen, wenn die Anbindung eingeschaltet ist.
  Future<void> starten() async {
    if (!_store.kalenderAktiv) return;
    try {
      final s = await _kanal.invokeMethod<String>('status');
      if (s == 'erteilt') {
        status = KalenderStatus.verbunden;
        notifyListeners();
        await aktualisieren();
      } else {
        status = s == 'dauerhaftVerweigert'
            ? KalenderStatus.dauerhaftVerweigert
            : KalenderStatus.keinZugriff;
        fehler = 'Agenda hat keinen Zugriff mehr auf den Kalender.';
        notifyListeners();
      }
    } on MissingPluginException {
      // Kein Android (z. B. in Tests): nichts zu tun.
    } catch (e) {
      fehler = 'Kalender konnte nicht geöffnet werden: $e';
      notifyListeners();
    }
  }

  /// Vom Knopf „Kalender verbinden“: fragt Android nach der Berechtigung.
  Future<void> verbinden() async {
    status = KalenderStatus.verbinde;
    fehler = null;
    notifyListeners();
    try {
      final s = await _kanal.invokeMethod<String>('berechtigungAnfragen');
      if (s == 'erteilt') {
        status = KalenderStatus.verbunden;
        _store.kalenderAktivSetzen(true);
        notifyListeners();
        await aktualisieren();
        return;
      }
      if (s == 'dauerhaftVerweigert') {
        status = KalenderStatus.dauerhaftVerweigert;
        fehler = 'Der Zugriff wurde abgelehnt. Du kannst ihn in den App-Einstellungen '
            'unter „Berechtigungen → Kalender“ erlauben.';
      } else {
        status = KalenderStatus.keinZugriff;
        fehler = 'Ohne Kalender-Zugriff kann Agenda keine Termine zeigen.';
      }
    } catch (e) {
      status = KalenderStatus.keinZugriff;
      fehler = 'Zugriff konnte nicht angefragt werden: $e';
    }
    notifyListeners();
  }

  Future<void> einstellungenOeffnen() async {
    try {
      await _kanal.invokeMethod<void>('einstellungenOeffnen');
    } catch (_) {
      // Einstellungen ließen sich nicht öffnen: nichts weiter zu tun.
    }
  }

  /// Anbindung ausschalten. Bereits eingetragene Aufgaben bleiben im Kalender.
  void ausschalten() {
    _syncTimer?.cancel();
    _store.kalenderAktivSetzen(false);
    _store.termineAusblenden();
    status = KalenderStatus.aus;
    fehler = null;
    notifyListeners();
  }

  /// Anderen Kalender für Aufgaben wählen (null = eigener Kalender „Agenda“).
  Future<void> zielSetzen(String? kalenderId) async {
    final ziel = kalender.where((k) => k.id == kalenderId).firstOrNull;
    _store.zielKalenderSetzen(ziel == null || ziel.istEigener ? null : kalenderId);
    notifyListeners();
    await synchronisieren();
  }

  void _plattformFehler(PlatformException e) {
    if (e.code == 'keine_berechtigung') {
      status = KalenderStatus.keinZugriff;
      fehler = 'Agenda hat keinen Kalender-Zugriff mehr. Tippe auf „Kalender verbinden“.';
    } else {
      fehler = 'Kalender-Fehler: ${e.message ?? e.code}';
    }
  }

  // ------------------------------------------------------------ Lesen

  /// Lädt Kalender und Termine neu und gleicht danach die Aufgaben ab.
  Future<void> aktualisieren() async {
    if (!verbunden || laedt) return;
    laedt = true;
    notifyListeners();
    try {
      final rohKalender =
          await _kanal.invokeListMethod<Map<dynamic, dynamic>>('kalender') ?? const [];
      kalender = [for (final m in rohKalender) KalenderInfo.ausMap(m)]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final h = heute();
      final von = plusTage(h, -termineTageZurueck);
      final bis = plusTage(h, termineTageVoraus);
      final rohTermine = await _kanal.invokeListMethod<Map<dynamic, dynamic>>(
            'termine',
            {'von': von.millisecondsSinceEpoch, 'bis': bis.millisecondsSinceEpoch},
          ) ??
          const [];

      // Eigene Aufgaben nicht doppelt als Termin zeigen
      final eigeneEintraege = {
        for (final a in _store.aufgaben)
          if (a.kalenderEventId != null) a.kalenderEventId!,
      };
      final eigeneKalender = {for (final k in kalender) if (k.istEigener) k.id};

      final neu = <Termin>[
        for (final m in rohTermine)
          if (!eigeneEintraege.contains('${m['eventId']}') &&
              !eigeneKalender.contains('${m['kalenderId']}'))
            _alsTermin(m),
      ];
      _store.termineSetzen(neu);
      fehler = null;
    } on PlatformException catch (e) {
      _plattformFehler(e);
    } catch (e) {
      fehler = 'Termine konnten nicht gelesen werden: $e';
    }
    laedt = false;
    notifyListeners();
    await synchronisieren();
  }

  /// Nur neu laden, wenn der letzte Stand älter als [alter] ist.
  Future<void> aktualisierenFallsAlt({Duration alter = const Duration(minutes: 1)}) async {
    final stand = _store.termineStand;
    if (stand != null && DateTime.now().difference(stand) < alter) return;
    await aktualisieren();
  }

  Termin _alsTermin(Map<dynamic, dynamic> m) {
    final ganztaegig = m['ganztaegig'] == true;
    final startMs = (m['start'] as num).toInt();
    final endeMs = (m['ende'] as num?)?.toInt() ?? startMs;

    DateTime zeit(int ms) {
      if (!ganztaegig) return DateTime.fromMillisecondsSinceEpoch(ms);
      // Ganztägige Termine speichert Android als UTC-Mitternacht.
      final utc = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      return DateTime(utc.year, utc.month, utc.day);
    }

    final farbe = (m['farbe'] as num?)?.toInt();
    final titel = m['titel'] as String?;
    return Termin(
      id: '${m['eventId']}_$startMs',
      titel: titel == null || titel.isEmpty ? '(Ohne Titel)' : titel,
      start: zeit(startMs),
      ende: zeit(endeMs),
      ganztaegig: ganztaegig,
      kalenderName: m['kalenderName'] as String? ?? 'Kalender',
      farbe: farbe == null ? null : (farbe & 0xFFFFFF) | 0xFF000000,
      ort: m['ort'] as String?,
    );
  }

  // ------------------------------------------------------------ Schreiben

  bool get _hatArbeit =>
      _store.zuLoeschendeTermine.isNotEmpty ||
      _store.aufgaben.any((a) => a.gehoertInKalender
          ? a.kalenderEventId == null || a.kalenderStand != a.kalenderFingerabdruck
          : a.kalenderEventId != null);

  void _storeGeaendert() {
    if (!verbunden || !_hatArbeit) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 1), synchronisieren);
  }

  Future<String> _zielKalenderId() async {
    final gewaehlt = _store.kalenderId;
    if (gewaehlt != null && kalender.any((k) => k.id == gewaehlt && k.schreibbar)) {
      return gewaehlt;
    }
    if (gewaehlt != null) {
      // Gewählter Kalender existiert nicht mehr: zurück zum eigenen
      _store.zielKalenderSetzen(null);
    }
    final id = await _kanal.invokeMethod<String>('eigenerKalender', {
      'name': kalenderAnzeigeName,
      'farbe': ruhepolKalenderFarbe,
    });
    if (id == null) throw StateError('Kalender „Agenda“ konnte nicht angelegt werden');
    return id;
  }

  /// Überträgt geänderte Aufgaben in den Kalender.
  Future<void> synchronisieren() async {
    if (!verbunden || !_hatArbeit) return;
    if (_syncLaeuft) {
      _nochmal = true;
      return;
    }
    _syncLaeuft = true;
    try {
      await _abgleichen();
    } on PlatformException catch (e) {
      _plattformFehler(e);
      notifyListeners();
    } catch (e) {
      fehler = 'Aufgaben konnten nicht eingetragen werden: $e';
      notifyListeners();
    } finally {
      _syncLaeuft = false;
    }
    if (_nochmal) {
      _nochmal = false;
      await synchronisieren();
    }
  }

  Future<void> _abgleichen() async {
    final ziel = await _zielKalenderId();
    var geaendert = false;

    // 1. Einträge gelöschter Aufgaben entfernen
    for (final id in List<String>.of(_store.zuLoeschendeTermine)) {
      await _kanal.invokeMethod<int>('eintragLoeschen', {'id': id});
      _store.zuLoeschendeTermine.remove(id);
      geaendert = true;
    }

    // 2. Aufgaben eintragen, ändern oder austragen
    for (final a in List<Aufgabe>.of(_store.aufgaben)) {
      if (!a.gehoertInKalender) {
        if (a.kalenderEventId != null) {
          await _kanal.invokeMethod<int>('eintragLoeschen', {'id': a.kalenderEventId});
          a.kalenderEventId = null;
          a.kalenderStand = null;
          geaendert = true;
        }
        continue;
      }
      final stand = a.kalenderFingerabdruck;
      if (a.kalenderEventId != null && a.kalenderStand == stand) continue;

      final f = a.faellig!;
      final u = a.uhrzeit!;
      final start = DateTime(f.year, f.month, f.day, u ~/ 60, u % 60);
      final ende = start.add(Duration(minutes: a.dauer ?? standardDauerMinuten));
      final id = await _kanal.invokeMethod<String>('eintragSpeichern', {
        'id': a.kalenderEventId,
        'kalenderId': ziel,
        'titel': a.erledigt ? '✓ ${a.titel}' : a.titel,
        'beschreibung':
            a.notiz.isEmpty ? 'Aufgabe aus Agenda' : '${a.notiz}\n\nAufgabe aus Agenda',
        'start': start.millisecondsSinceEpoch,
        'ende': ende.millisecondsSinceEpoch,
      });
      if (id == null) throw StateError('Eintrag konnte nicht gespeichert werden');
      a.kalenderEventId = id;
      a.kalenderStand = stand;
      geaendert = true;
    }

    if (geaendert) _store.kalenderDatenGeaendert();
    if (fehler != null) {
      fehler = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _store.removeListener(_storeGeaendert);
    super.dispose();
  }
}

/// Macht den Kalender-Dienst erreichbar: `KalenderScope.of(context)`.
class KalenderScope extends InheritedNotifier<KalenderDienst> {
  const KalenderScope({
    super.key,
    required KalenderDienst dienst,
    required super.child,
  }) : super(notifier: dienst);

  static KalenderDienst of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KalenderScope>()!.notifier!;
}
