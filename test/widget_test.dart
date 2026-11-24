import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhepol/aufgaben_store.dart';
import 'package:ruhepol/erinnerungen.dart';
import 'package:ruhepol/handy_kalender.dart';
import 'package:ruhepol/main.dart';
import 'package:ruhepol/modelle.dart';
import 'package:ruhepol/speicher.dart';

Future<AufgabenStore> _store([ArbeitsspeicherSpeicher? speicher]) async {
  final store = AufgabenStore(speicher ?? ArbeitsspeicherSpeicher());
  await store.laden();
  return store;
}

void main() {
  testWidgets('App startet mit Begrüßungsaufgaben', (tester) async {
    final speicher = ArbeitsspeicherSpeicher();
    final store = await _store(speicher);

    await tester.pumpWidget(RuhepolApp(
      store: store,
      kalender: KalenderDienst(store),
      erinnerungen: ErinnerungsDienst(store),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Heute'), findsWidgets);
    expect(find.text('Tippe auf den Kreis, um mich abzuhaken'), findsOneWidget);
    expect(speicher.daten, isNotNull);
  });

  testWidgets('Abhaken verschiebt Aufgabe zu „Heute erledigt“', (tester) async {
    final store = await _store();

    await tester.pumpWidget(RuhepolApp(
      store: store,
      kalender: KalenderDienst(store),
      erinnerungen: ErinnerungsDienst(store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Erledigen').first);
    await tester.pumpAndSettle();

    expect(store.aufgaben.where((a) => a.erledigt).length, 1);
    await tester.scrollUntilVisible(
      find.text('Heute erledigt'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Heute erledigt'), findsOneWidget);

    // Speicher-Timer und Snackbar ablaufen lassen
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Google-Termine erscheinen im Zeitplan', (tester) async {
    final store = await _store();
    final jetzt = DateTime.now();
    final start = DateTime(jetzt.year, jetzt.month, jetzt.day, 12, 30);
    store.termineSetzen([
      Termin(
        id: 't1',
        titel: 'Mittagessen mit Jonas',
        start: start,
        ende: start.add(const Duration(hours: 1)),
        ganztaegig: false,
        kalenderName: 'Privat',
        farbe: 0xFF9FE1E7,
      ),
    ]);

    await tester.pumpWidget(RuhepolApp(
      store: store,
      kalender: KalenderDienst(store),
      erinnerungen: ErinnerungsDienst(store),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mittagessen mit Jonas'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  test('Gelöschte Aufgabe merkt sich ihren Kalendereintrag', () async {
    final store = await _store();
    final a = store.aufgaben.first..kalenderEventId = 'event123';
    store.loeschen(a.id);
    expect(store.zuLoeschendeTermine, contains('event123'));
  });

  test('Nur Aufgaben mit Datum und Uhrzeit gehören in den Kalender', () {
    final a = Aufgabe(titel: 'Test', listeId: 'privat', faellig: DateTime(2026, 12, 1));
    expect(a.gehoertInKalender, isFalse);
    a.uhrzeit = 600;
    expect(a.gehoertInKalender, isTrue);
  });

  test('Ganztägiger Termin liegt nur an seinem Tag', () {
    final t = Termin(
      id: 'x',
      titel: 'Urlaub',
      start: DateTime(2026, 12, 1),
      ende: DateTime(2026, 12, 2),
      ganztaegig: true,
      kalenderName: 'Privat',
    );
    expect(t.amTag(DateTime(2026, 12, 1)), isTrue);
    expect(t.amTag(DateTime(2026, 12, 2)), isFalse);
  });
}
