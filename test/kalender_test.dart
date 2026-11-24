import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhepol/aufgaben_store.dart';
import 'package:ruhepol/datum.dart';
import 'package:ruhepol/handy_kalender.dart';
import 'package:ruhepol/modelle.dart';
import 'package:ruhepol/speicher.dart';

/// Nachgebauter Android-Kalender für Tests.
class FakeKalender {
  final aufrufe = <MethodCall>[];
  final eintraege = <String, Map<dynamic, dynamic>>{};
  var naechsteId = 100;

  Future<Object?> behandeln(MethodCall call) async {
    aufrufe.add(call);
    final args = (call.arguments as Map?) ?? const {};
    switch (call.method) {
      case 'status':
      case 'berechtigungAnfragen':
        return 'erteilt';
      case 'kalender':
        return [
          {
            'id': '1',
            'name': 'Privat',
            'konto': 'ich@example.com',
            'kontoTyp': 'com.google',
            'farbe': 0xFF9FE1E7,
            'schreibbar': true,
            'sichtbar': true,
          },
          {
            'id': '7',
            'name': 'Ruhepol',
            'konto': 'Ruhepol',
            'kontoTyp': 'LOCAL',
            'farbe': 0xFF7FA88C,
            'schreibbar': true,
            'sichtbar': true,
          },
        ];
      case 'eigenerKalender':
        return '7';
      case 'termine':
        final h = heute();
        final start = DateTime(h.year, h.month, h.day, 12, 30);
        return [
          {
            'eventId': '55',
            'titel': 'Mittagessen',
            'start': start.millisecondsSinceEpoch,
            'ende': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            'ganztaegig': false,
            'kalenderId': '1',
            'ort': null,
            'farbe': 0xFF9FE1E7,
            'kalenderName': 'Privat',
          },
          for (final e in eintraege.entries)
            {
              'eventId': e.key,
              'titel': e.value['titel'],
              'start': e.value['start'],
              'ende': e.value['ende'],
              'ganztaegig': false,
              'kalenderId': e.value['kalenderId'],
              'ort': null,
              'farbe': 0xFF7FA88C,
              'kalenderName': 'Ruhepol',
            },
        ];
      case 'eintragSpeichern':
        final id = args['id'] as String? ?? '${naechsteId++}';
        eintraege[id] = Map<dynamic, dynamic>.from(args);
        return id;
      case 'eintragLoeschen':
        return eintraege.remove(args['id']) == null ? 0 : 1;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kanal = MethodChannel('ruhepol/kalender');
  late FakeKalender fake;

  setUp(() {
    fake = FakeKalender();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kanal, fake.behandeln);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kanal, null);
  });

  test('Verbinden liest Termine und trägt Aufgaben mit Uhrzeit ein', () async {
    final store = AufgabenStore(ArbeitsspeicherSpeicher());
    await store.laden();
    final aufgabe = Aufgabe(
      titel: 'Zahnarzt',
      listeId: 'gesundheit',
      faellig: plusTage(heute(), 1),
      uhrzeit: 15 * 60,
    );
    store.hinzufuegen(aufgabe);

    final dienst = KalenderDienst(store, kanal: kanal);
    await dienst.verbinden();

    expect(dienst.verbunden, isTrue);
    expect(store.kalenderAktiv, isTrue);
    expect(store.termine.map((t) => t.titel), contains('Mittagessen'));

    // Aufgabe landet im eigenen Kalender „Ruhepol“ (ID 7)
    expect(aufgabe.kalenderEventId, isNotNull);
    final eintrag = fake.eintraege[aufgabe.kalenderEventId]!;
    expect(eintrag['titel'], 'Zahnarzt');
    expect(eintrag['kalenderId'], '7');

    // Erledigen setzt ein ✓ vor den Titel
    store.umschalten(aufgabe.id);
    await dienst.synchronisieren();
    expect(fake.eintraege[aufgabe.kalenderEventId]!['titel'], '✓ Zahnarzt');

    // Löschen entfernt den Eintrag
    final eventId = aufgabe.kalenderEventId!;
    store.loeschen(aufgabe.id);
    await dienst.synchronisieren();
    expect(fake.eintraege.containsKey(eventId), isFalse);
    expect(store.zuLoeschendeTermine, isEmpty);

    dienst.dispose();
  });

  test('Aufgaben ohne Uhrzeit kommen nicht in den Kalender', () async {
    final store = AufgabenStore(ArbeitsspeicherSpeicher());
    await store.laden();
    final dienst = KalenderDienst(store, kanal: kanal);
    await dienst.verbinden();

    // Die Startaufgaben haben keine Uhrzeit
    expect(fake.eintraege, isEmpty);
    expect(fake.aufrufe.where((c) => c.method == 'eintragSpeichern'), isEmpty);
    dienst.dispose();
  });

  test('Eigene Einträge erscheinen nicht doppelt als Termin', () async {
    final store = AufgabenStore(ArbeitsspeicherSpeicher());
    await store.laden();
    store.hinzufuegen(Aufgabe(
      titel: 'Sport',
      listeId: 'privat',
      faellig: heute(),
      uhrzeit: 18 * 60,
    ));
    final dienst = KalenderDienst(store, kanal: kanal);
    await dienst.verbinden();
    await dienst.aktualisieren();

    expect(store.termine.where((t) => t.titel == 'Sport'), isEmpty);
    expect(store.termine.where((t) => t.titel == 'Mittagessen'), hasLength(1));
    dienst.dispose();
  });

  test('Kalenderwechsel trägt Aufgaben im neuen Kalender ein', () async {
    final store = AufgabenStore(ArbeitsspeicherSpeicher());
    await store.laden();
    final aufgabe = Aufgabe(
      titel: 'Meeting',
      listeId: 'arbeit',
      faellig: heute(),
      uhrzeit: 10 * 60,
    );
    store.hinzufuegen(aufgabe);
    final dienst = KalenderDienst(store, kanal: kanal);
    await dienst.verbinden();
    final alteId = aufgabe.kalenderEventId!;

    await dienst.zielSetzen('1');

    expect(store.kalenderId, '1');
    expect(fake.eintraege.containsKey(alteId), isFalse);
    expect(fake.eintraege[aufgabe.kalenderEventId]!['kalenderId'], '1');
    dienst.dispose();
  });
}
