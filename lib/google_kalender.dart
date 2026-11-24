import 'dart:async';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import 'aufgaben_store.dart';
import 'datum.dart';
import 'konfiguration.dart';
import 'modelle.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Verbindung zum Google Kalender.
// 1. Anmelden mit deinem Google-Konto (google_sign_in).
// 2. Lesen: Termine aus allen sichtbaren Kalendern (7 Tage zurück, 60 voraus).
// 3. Schreiben: Aufgaben mit Datum UND Uhrzeit landen im eigenen Kalender
//    „Ruhepol“. Geänderte Aufgaben werden aktualisiert, gelöschte entfernt,
//    erledigte bekommen ein ✓ vor den Titel.
// Abgleich: 3 Sekunden nach jeder Änderung und beim Öffnen der App.
// ---------------------------------------------------------------------------

enum KalenderStatus { nichtEingerichtet, getrennt, verbinde, verbunden }

class KalenderDienst extends ChangeNotifier {
  KalenderDienst(this._store) {
    _store.addListener(_storeGeaendert);
  }

  final AufgabenStore _store;
  GoogleSignIn get _signIn => GoogleSignIn.instance;

  KalenderStatus status =
      googleEingerichtet ? KalenderStatus.getrennt : KalenderStatus.nichtEingerichtet;
  String? email;
  String? fehler;
  bool laedt = false;

  GoogleSignInAccount? _konto;
  bool _initialisiert = false;
  Timer? _syncTimer;
  bool _syncLaeuft = false;
  bool _nochmal = false;

  bool get verbunden => status == KalenderStatus.verbunden;

  // ------------------------------------------------------------ Anmelden

  Future<void> _initialisieren() async {
    if (_initialisiert) return;
    await _signIn.initialize(serverClientId: googleWebClientId);
    _initialisiert = true;
  }

  /// Beim App-Start: still neu verbinden, falls früher schon verbunden.
  Future<void> starten() async {
    if (!googleEingerichtet || !_store.googleAktiv) return;
    try {
      await _initialisieren();
      final konto = await _signIn.attemptLightweightAuthentication();
      if (konto != null) await _angemeldet(konto, mitDialog: false);
    } catch (e) {
      debugPrint('Google-Start fehlgeschlagen: $e');
    }
    notifyListeners();
  }

  /// Vom Knopf „Mit Google verbinden“.
  Future<void> verbinden() async {
    if (!googleEingerichtet) return;
    fehler = null;
    status = KalenderStatus.verbinde;
    notifyListeners();
    try {
      await _initialisieren();
      final konto = await _signIn.authenticate(scopeHint: googleBerechtigungen);
      await _angemeldet(konto, mitDialog: true);
    } on GoogleSignInException catch (e) {
      status = KalenderStatus.getrennt;
      fehler = e.code == GoogleSignInExceptionCode.canceled ? null : _anmeldeFehler(e);
    } catch (e) {
      status = KalenderStatus.getrennt;
      fehler = 'Verbindung fehlgeschlagen: $e';
    }
    notifyListeners();
  }

  Future<void> _angemeldet(GoogleSignInAccount konto, {required bool mitDialog}) async {
    var freigabe =
        await konto.authorizationClient.authorizationForScopes(googleBerechtigungen);
    if (freigabe == null && mitDialog) {
      freigabe = await konto.authorizationClient.authorizeScopes(googleBerechtigungen);
    }
    if (freigabe == null) {
      status = KalenderStatus.getrennt;
      fehler = mitDialog ? 'Der Kalender-Zugriff wurde nicht erlaubt.' : null;
      return;
    }
    _konto = konto;
    email = konto.email;
    status = KalenderStatus.verbunden;
    fehler = null;
    _store.googleAktivSetzen(true);
    notifyListeners();
    await aktualisieren();
  }

  Future<void> trennen() async {
    try {
      await _signIn.disconnect();
    } catch (_) {
      // Bereits getrennt, nichts zu tun.
    }
    _konto = null;
    email = null;
    fehler = null;
    status = googleEingerichtet ? KalenderStatus.getrennt : KalenderStatus.nichtEingerichtet;
    _store.googleAktivSetzen(false);
    _store.termineAusblenden();
    notifyListeners();
  }

  /// Führt [arbeit] mit einem frischen Zugang zur Kalender-API aus.
  Future<void> _mitApi(Future<void> Function(gcal.CalendarApi api) arbeit) async {
    final konto = _konto;
    if (konto == null) return;
    final freigabe =
        await konto.authorizationClient.authorizationForScopes(googleBerechtigungen);
    if (freigabe == null) {
      status = KalenderStatus.getrennt;
      fehler = 'Bitte in „Mehr“ erneut mit Google verbinden.';
      notifyListeners();
      return;
    }
    final client = freigabe.authClient(scopes: googleBerechtigungen);
    try {
      await arbeit(gcal.CalendarApi(client));
    } finally {
      client.close();
    }
  }

  // ------------------------------------------------------------ Lesen

  /// Lädt die Termine neu und gleicht danach die Aufgaben ab.
  Future<void> aktualisieren() async {
    if (!verbunden || laedt) return;
    laedt = true;
    notifyListeners();
    try {
      await _mitApi((api) async {
        final eigenerKalender = await _eigenerKalender(api);
        final liste = await api.calendarList.list(minAccessRole: 'reader');
        final h = heute();
        final von = plusTage(h, -7).toUtc();
        final bis = plusTage(h, 60).toUtc();
        final neu = <Termin>[];

        for (final k in liste.items ?? const <gcal.CalendarListEntry>[]) {
          final id = k.id;
          if (id == null || id == eigenerKalender) continue;
          if (k.hidden == true) continue;
          if (k.selected != true && k.primary != true) continue;
          final name = k.summaryOverride ?? k.summary ?? 'Kalender';
          final farbe = _farbeAusHex(k.backgroundColor);

          String? seite;
          var runden = 0;
          do {
            final antwort = await api.events.list(
              id,
              timeMin: von,
              timeMax: bis,
              singleEvents: true,
              orderBy: 'startTime',
              maxResults: 250,
              pageToken: seite,
            );
            for (final e in antwort.items ?? const <gcal.Event>[]) {
              final t = _alsTermin(e, name, farbe);
              if (t != null) neu.add(t);
            }
            seite = antwort.nextPageToken;
            runden++;
          } while (seite != null && runden < 5);
        }
        neu.sort((a, b) => a.start.compareTo(b.start));
        _store.termineSetzen(neu);
      });
      if (verbunden) fehler = null;
    } catch (e) {
      fehler = _apiFehler(e);
    }
    laedt = false;
    notifyListeners();
    await synchronisieren();
  }

  /// Nur neu laden, wenn der letzte Stand älter als [alter] ist.
  Future<void> aktualisierenFallsAlt({Duration alter = const Duration(minutes: 2)}) async {
    final stand = _store.termineStand;
    if (stand != null && DateTime.now().difference(stand) < alter) return;
    await aktualisieren();
  }

  Termin? _alsTermin(gcal.Event e, String kalender, int? farbe) {
    if (e.status == 'cancelled') return null;
    final s = e.start;
    final startRoh = s?.dateTime ?? s?.date;
    if (s == null || startRoh == null) return null;
    final ganztaegig = s.dateTime == null;
    final start = startRoh.toLocal();
    final ende = (e.end?.dateTime ?? e.end?.date)?.toLocal() ?? start;
    return Termin(
      id: e.id ?? '',
      titel: (e.summary == null || e.summary!.isEmpty) ? '(Ohne Titel)' : e.summary!,
      start: ganztaegig ? nurDatum(start) : start,
      ende: ganztaegig ? nurDatum(ende) : ende,
      ganztaegig: ganztaegig,
      kalenderName: kalender,
      farbe: farbe,
      ort: e.location,
    );
  }

  int? _farbeAusHex(String? hex) {
    if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
    final wert = int.tryParse(hex.substring(1), radix: 16);
    return wert == null ? null : 0xFF000000 | wert;
  }

  // ------------------------------------------------------------ Schreiben

  Future<String> _eigenerKalender(gcal.CalendarApi api) async {
    final bekannt = _store.kalenderId;
    if (bekannt != null) return bekannt;

    final liste = await api.calendarList.list(minAccessRole: 'owner');
    for (final k in liste.items ?? const <gcal.CalendarListEntry>[]) {
      if (k.summary == ruhepolKalenderName && k.id != null) {
        _store.kalenderId = k.id;
        _store.kalenderDatenGeaendert();
        return k.id!;
      }
    }
    final neu = await api.calendars.insert(gcal.Calendar(
      summary: ruhepolKalenderName,
      description: 'Aufgaben aus der Ruhepol-App',
      timeZone: zeitzone,
    ));
    _store.kalenderId = neu.id;
    _store.kalenderDatenGeaendert();
    return neu.id!;
  }

  gcal.Event _alsEvent(Aufgabe a) {
    final f = a.faellig!;
    final u = a.uhrzeit!;
    final start = DateTime(f.year, f.month, f.day, u ~/ 60, u % 60);
    final ende = start.add(const Duration(minutes: standardDauerMinuten));
    return gcal.Event(
      summary: a.erledigt ? '✓ ${a.titel}' : a.titel,
      description: a.notiz.isEmpty
          ? 'Aufgabe aus Ruhepol'
          : '${a.notiz}\n\nAufgabe aus Ruhepol',
      start: gcal.EventDateTime(dateTime: start, timeZone: zeitzone),
      end: gcal.EventDateTime(dateTime: ende, timeZone: zeitzone),
    );
  }

  bool get _hatArbeit =>
      _store.zuLoeschendeTermine.isNotEmpty ||
      _store.aufgaben.any((a) => a.gehoertInKalender
          ? a.kalenderEventId == null || a.kalenderStand != a.kalenderFingerabdruck
          : a.kalenderEventId != null);

  void _storeGeaendert() {
    if (!verbunden || !_hatArbeit) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), synchronisieren);
  }

  /// Überträgt geänderte Aufgaben in den Kalender „Ruhepol“.
  Future<void> synchronisieren() async {
    if (!verbunden || !_hatArbeit) return;
    if (_syncLaeuft) {
      _nochmal = true;
      return;
    }
    _syncLaeuft = true;
    try {
      await _mitApi(_abgleichen);
      if (fehler != null && verbunden) {
        fehler = null;
        notifyListeners();
      }
    } catch (e) {
      fehler = _apiFehler(e);
      notifyListeners();
    } finally {
      _syncLaeuft = false;
    }
    if (_nochmal) {
      _nochmal = false;
      await synchronisieren();
    }
  }

  Future<void> _abgleichen(gcal.CalendarApi api) async {
    var kalender = await _eigenerKalender(api);
    var geaendert = false;

    Future<void> entfernen(String eventId) async {
      try {
        await api.events.delete(kalender, eventId);
      } on gcal.DetailedApiRequestError catch (e) {
        if (e.status != 404 && e.status != 410) rethrow;
      }
    }

    // 1. Einträge gelöschter Aufgaben entfernen
    for (final id in List<String>.of(_store.zuLoeschendeTermine)) {
      await entfernen(id);
      _store.zuLoeschendeTermine.remove(id);
      geaendert = true;
    }

    // 2. Aufgaben eintragen, ändern oder austragen
    for (final a in List<Aufgabe>.of(_store.aufgaben)) {
      if (!a.gehoertInKalender) {
        if (a.kalenderEventId != null) {
          await entfernen(a.kalenderEventId!);
          a.kalenderEventId = null;
          a.kalenderStand = null;
          geaendert = true;
        }
        continue;
      }
      final stand = a.kalenderFingerabdruck;
      if (a.kalenderEventId != null && a.kalenderStand == stand) continue;

      final event = _alsEvent(a);
      if (a.kalenderEventId != null) {
        try {
          await api.events.patch(event, kalender, a.kalenderEventId!);
        } on gcal.DetailedApiRequestError catch (e) {
          if (e.status != 404 && e.status != 410) rethrow;
          a.kalenderEventId = null; // Eintrag wurde bei Google gelöscht
        }
      }
      if (a.kalenderEventId == null) {
        gcal.Event neu;
        try {
          neu = await api.events.insert(event, kalender);
        } on gcal.DetailedApiRequestError catch (e) {
          if (e.status != 404) rethrow;
          // Kalender „Ruhepol“ gibt es nicht mehr: neu anlegen
          _store.kalenderId = null;
          kalender = await _eigenerKalender(api);
          neu = await api.events.insert(event, kalender);
        }
        a.kalenderEventId = neu.id;
      }
      a.kalenderStand = stand;
      geaendert = true;
    }

    if (geaendert) _store.kalenderDatenGeaendert();
  }

  // ------------------------------------------------------------ Fehlertexte

  String _anmeldeFehler(GoogleSignInException e) {
    if (e.code == GoogleSignInExceptionCode.clientConfigurationError) {
      return 'Die Google-Einrichtung passt nicht. Bitte Web-Client-ID, '
          'Paketname und SHA-1 in der Google Cloud prüfen.';
    }
    return 'Anmeldung fehlgeschlagen (${e.code.name})'
        '${e.description != null ? ': ${e.description}' : ''}';
  }

  String _apiFehler(Object e) {
    if (e is gcal.DetailedApiRequestError) {
      if (e.status == 403) {
        return 'Google verweigert den Zugriff (${e.message}). '
            'Ist die Google Calendar API im Projekt aktiviert?';
      }
      return 'Google-Fehler ${e.status}: ${e.message}';
    }
    if (e is SocketException || e.toString().contains('ClientException')) {
      return 'Keine Internetverbindung. Es werden die zuletzt geladenen Termine gezeigt.';
    }
    return 'Fehler beim Kalender-Abgleich: $e';
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
