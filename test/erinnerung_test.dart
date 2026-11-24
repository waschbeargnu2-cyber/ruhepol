import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhepol/aufgaben_store.dart';
import 'package:ruhepol/erinnerungen.dart';
import 'package:ruhepol/modelle.dart';
import 'package:ruhepol/speicher.dart';

void main() {
  // Dienstag, 24. November 2026, 10:00 Uhr
  final jetzt = DateTime(2026, 11, 24, 10);
  final listen = [Liste(id: 'privat', name: 'Privat', farbe: 0, icon: 'herz')];
  ErinnerungsEinstellungen ein({bool uebersicht = false}) =>
      ErinnerungsEinstellungen(aktiv: true, uebersicht: uebersicht, rueckblick: false);

  List<Erinnerung> plane(List<Aufgabe> aufgaben,
          {ErinnerungsEinstellungen? e, List<Termin> termine = const []}) =>
      planeErinnerungen(
        aufgaben: aufgaben,
        listen: listen,
        termine: termine,
        e: e ?? ein(),
        jetzt: jetzt,
      );

  test('Aufgabe mit Uhrzeit: 15 Minuten vorher', () {
    final r = plane([
      Aufgabe(titel: 'Zahnarzt', listeId: 'privat', faellig: DateTime(2026, 11, 25), uhrzeit: 15 * 60),
    ]);
    expect(r, hasLength(1));
    expect(r.first.zeit, DateTime(2026, 11, 25, 14, 45));
    expect(r.first.titel, 'Zahnarzt');
    expect(r.first.text, contains('15:00'));
    expect(r.first.aufgabeId, isNotNull);
  });

  test('Aufgabe ohne Uhrzeit: morgens um 8', () {
    final r = plane([
      Aufgabe(titel: 'Einkaufen', listeId: 'privat', faellig: DateTime(2026, 11, 26)),
    ]);
    expect(r.single.zeit, DateTime(2026, 11, 26, 8));
  });

  test('Vergangene Zeitpunkte werden übersprungen', () {
    final r = plane([
      // heute 8:00 ist schon vorbei
      Aufgabe(titel: 'Heute', listeId: 'privat', faellig: DateTime(2026, 11, 24)),
      Aufgabe(titel: 'Gleich', listeId: 'privat', faellig: DateTime(2026, 11, 24), uhrzeit: 9 * 60),
    ]);
    expect(r, isEmpty);
  });

  test('Frist: 3 Tage, 1 Tag vorher und am Tag selbst', () {
    final r = plane([
      Aufgabe(titel: 'Steuer', listeId: 'privat', frist: DateTime(2026, 12, 1)),
    ]);
    expect(r.map((e) => e.zeit), [
      DateTime(2026, 11, 28, 8),
      DateTime(2026, 11, 30, 8),
      DateTime(2026, 12, 1, 8),
    ]);
    expect(r.last.text, 'Frist ist heute!');
  });

  test('Gleicher Zeitpunkt wird zu einer Erinnerung zusammengefasst', () {
    final r = plane([
      Aufgabe(
        titel: 'Abgabe',
        listeId: 'privat',
        faellig: DateTime(2026, 11, 27),
        frist: DateTime(2026, 11, 27),
      ),
    ]);
    final amTag = r.where((e) => e.zeit == DateTime(2026, 11, 27, 8)).toList();
    expect(amTag, hasLength(1));
    expect(amTag.single.text, contains('Heute fällig'));
    expect(amTag.single.text, contains('Frist ist heute!'));
  });

  test('Erledigte und stummgeschaltete Aufgaben erinnern nicht', () {
    final r = plane([
      Aufgabe(titel: 'A', listeId: 'privat', faellig: DateTime(2026, 11, 25), erledigt: true),
      Aufgabe(titel: 'B', listeId: 'privat', faellig: DateTime(2026, 11, 25), erinnern: false),
    ]);
    expect(r, isEmpty);
  });

  test('Ausgeschaltet = keine Erinnerungen', () {
    final r = plane(
      [Aufgabe(titel: 'A', listeId: 'privat', faellig: DateTime(2026, 11, 25))],
      e: ErinnerungsEinstellungen(aktiv: false),
    );
    expect(r, isEmpty);
  });

  test('Morgen-Übersicht nennt Aufgaben und Termine', () {
    final r = plane(
      [
        Aufgabe(titel: 'Bericht', listeId: 'privat', faellig: DateTime(2026, 11, 25),
            prioritaet: Prioritaet.hoch),
        Aufgabe(titel: 'Blumen', listeId: 'privat', faellig: DateTime(2026, 11, 25)),
      ],
      e: ein(uebersicht: true),
      termine: [
        Termin(
          id: 't',
          titel: 'Meeting',
          start: DateTime(2026, 11, 25, 9),
          ende: DateTime(2026, 11, 25, 10),
          ganztaegig: false,
          kalenderName: 'Arbeit',
        ),
      ],
    );
    final uebersicht = r.where((e) => e.aufgabeId == null).toList();
    expect(uebersicht.first.zeit, DateTime(2026, 11, 25, 7, 30));
    expect(uebersicht.first.text, 'Heute: 2 Aufgaben, 1 Termin. Zuerst: Bericht');
  });

  test('IDs sind eindeutig und nach Zeit sortiert', () {
    final r = plane([
      Aufgabe(titel: 'Später', listeId: 'privat', faellig: DateTime(2026, 11, 30)),
      Aufgabe(titel: 'Früher', listeId: 'privat', faellig: DateTime(2026, 11, 25)),
    ]);
    expect(r.map((e) => e.titel), ['Früher', 'Später']);
    expect(r.map((e) => e.id).toSet(), hasLength(2));
  });

  group('Dienst', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const kanal = MethodChannel('ruhepol/kalender');
    final aufrufe = <MethodCall>[];
    var erledigt = <String>[];

    setUp(() {
      aufrufe.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, (call) async {
        aufrufe.add(call);
        switch (call.method) {
          case 'benachrichtigungStatus':
          case 'benachrichtigungAnfragen':
            return 'erteilt';
          case 'exakteWecker':
            return true;
          case 'erinnerungenPlanen':
            return ((call.arguments as Map)['liste'] as List).length;
          case 'erledigteAbholen':
            final r = erledigt;
            erledigt = [];
            return r;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null);
    });

    test('Einschalten plant Erinnerungen bei Android ein', () async {
      final store = AufgabenStore(ArbeitsspeicherSpeicher());
      await store.laden();
      final morgen = DateTime.now().add(const Duration(days: 1));
      store.hinzufuegen(Aufgabe(
        titel: 'Test',
        listeId: 'privat',
        faellig: DateTime(morgen.year, morgen.month, morgen.day),
        uhrzeit: 12 * 60,
      ));
      final dienst = ErinnerungsDienst(store, kanal: kanal);
      await dienst.einschalten();

      expect(dienst.aktiv, isTrue);
      expect(store.erinnerung.aktiv, isTrue);
      final plan = aufrufe.lastWhere((c) => c.method == 'erinnerungenPlanen');
      final liste = (plan.arguments as Map)['liste'] as List;
      expect(liste.any((e) => (e as Map)['titel'] == 'Test'), isTrue);
      dienst.dispose();
    });

    test('„Erledigt“ aus der Benachrichtigung hakt die Aufgabe ab', () async {
      final store = AufgabenStore(ArbeitsspeicherSpeicher());
      await store.laden();
      final a = store.aufgaben.first;
      erledigt = [a.id, 'gibt-es-nicht'];

      final dienst = ErinnerungsDienst(store, kanal: kanal);
      final anzahl = await dienst.abholen();

      expect(anzahl, 1);
      expect(store.aufgabe(a.id)!.erledigt, isTrue);
      dienst.dispose();
    });
  });
}
