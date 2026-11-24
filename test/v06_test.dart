import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhepol/aufgaben_store.dart';
import 'package:ruhepol/datum.dart';
import 'package:ruhepol/eingabe_parser.dart';
import 'package:ruhepol/erinnerungen.dart';
import 'package:ruhepol/handy_kalender.dart';
import 'package:ruhepol/main.dart';
import 'package:ruhepol/modelle.dart';
import 'package:ruhepol/speicher.dart';
import 'package:ruhepol/tagesplanung.dart';

Future<AufgabenStore> neuerStore() async {
  final s = AufgabenStore(ArbeitsspeicherSpeicher());
  await s.laden();
  return s;
}

void main() {
  group('Dauer im Eingabetext', () {
    final heute = DateTime(2026, 11, 24);
    final listen = [Liste(id: 'privat', name: 'Privat', farbe: 0, icon: 'herz')];
    ParseErgebnis p(String s) => analysiere(s, heute: heute, listen: listen);

    test('Minuten, Stunden und Kommazahlen', () {
      expect(p('Joggen 30 min').dauer, 30);
      expect(p('Präsentation 2 Std.').dauer, 120);
      expect(p('Lernen 1,5h').dauer, 90);
      expect(p('Telefonat Dauer 20 Minuten').dauer, 20);
    });

    test('Dauer stört Uhrzeit und Titel nicht', () {
      final r = p('Meeting morgen 15 Uhr 45 min');
      expect(r.titel, 'Meeting');
      expect(r.uhrzeit, 15 * 60);
      expect(r.dauer, 45);
    });
  });

  group('Tag planen', () {
    final jetzt = DateTime(2026, 11, 24, 9, 5);
    final tag = DateTime(2026, 11, 24);

    test('Wichtigstes zuerst, um Termine herum, mit Puffer', () {
      final aufgaben = [
        Aufgabe(titel: 'Klein', listeId: 'p', faellig: tag, dauer: 30),
        Aufgabe(titel: 'Wichtig', listeId: 'p', faellig: tag, dauer: 60, prioritaet: Prioritaet.hoch),
      ];
      final termine = [
        Termin(
          id: 't',
          titel: 'Meeting',
          start: DateTime(2026, 11, 24, 10, 30),
          ende: DateTime(2026, 11, 24, 11, 30),
          ganztaegig: false,
          kalenderName: 'Arbeit',
        ),
      ];
      final plan = planeTag(aufgaben: aufgaben, termine: termine, tag: tag, jetzt: jetzt);
      // Start 9:15 (aufgerundet). „Wichtig“ (60 Min.) passt 9:15–10:15.
      // „Klein“ (30 Min.) passt nicht mehr vor das Meeting (10:25–10:55 > 10:30)
      // → nach dem Meeting + Puffer: 11:40.
      expect(plan.eintraege.map((e) => e.aufgabe.titel), ['Wichtig', 'Klein']);
      expect(plan.eintraege[0].von, 9 * 60 + 15);
      expect(plan.eintraege[1].von, 11 * 60 + 40);
      expect(plan.keinPlatz, isEmpty);
    });

    test('Ohne Datum nur auf Wunsch, zu Langes bekommt keinen Platz', () {
      final aufgaben = [
        Aufgabe(titel: 'Irgendwann', listeId: 'p'),
        Aufgabe(titel: 'Riesig', listeId: 'p', faellig: tag, dauer: 20 * 60),
      ];
      final ohne = planeTag(aufgaben: aufgaben, termine: const [], tag: tag, jetzt: jetzt);
      expect(ohne.eintraege, isEmpty);
      expect(ohne.keinPlatz.single.titel, 'Riesig');

      final mit = planeTag(
          aufgaben: aufgaben, termine: const [], tag: tag, jetzt: jetzt, ohneDatum: true);
      expect(mit.eintraege.single.aufgabe.titel, 'Irgendwann');
    });

    test('Übernehmen setzt Datum und Uhrzeit (rückgängig machbar)', () async {
      final store = await neuerStore();
      final a = store.aufgaben.first;
      store.tagesplanUebernehmen(heute(), {a.id: 600});
      expect(a.uhrzeit, 600);
      store.rueckgaengig();
      expect(store.aufgabe(a.id)!.uhrzeit, isNull);
    });
  });

  group('Vorlagen und Vorschläge', () {
    test('Häufige Einträge werden ab 2× vorgeschlagen', () async {
      final store = await neuerStore();
      for (var i = 0; i < 2; i++) {
        final a = Aufgabe(titel: 'Wocheneinkauf', listeId: 'einkauf');
        store.hinzufuegen(a);
        store.umschalten(a.id); // erledigt, damit nicht „offen“
      }
      expect(store.haeufigkeit('wocheneinkauf!'), 2);
      final v = store.vorschlaege();
      expect(v.haeufig.map((h) => h.titel), contains('Wocheneinkauf'));
      expect(store.vorschlaege(filter: 'woche').haeufig, isNotEmpty);
      expect(store.vorschlaege(filter: 'zahnarzt').haeufig, isEmpty);
    });

    test('Vorlage speichern ersetzt gleichnamige', () async {
      final store = await neuerStore();
      final a = Aufgabe(
        titel: 'Reise packen',
        listeId: 'privat',
        dauer: 45,
        unteraufgaben: [Unteraufgabe(titel: 'Ladekabel'), Unteraufgabe(titel: 'Pass')],
      );
      store.vorlageSpeichern(a);
      store.vorlageSpeichern(a);
      expect(store.vorlagen, hasLength(1));
      final v = store.vorlageFuer('reise packen')!;
      expect(v.unteraufgaben, ['Ladekabel', 'Pass']);
      expect(v.dauer, 45);
      expect(store.vorschlaege().vorlagen.single.titel, 'Reise packen');
    });
  });

  group('Notizen', () {
    test('Eine Notiz mit mehreren Aufgaben verknüpfen', () async {
      final store = await neuerStore();
      final a1 = store.aufgaben[0];
      final a2 = store.aufgaben[1];
      final n = store.notizAnlegen(aufgabeId: a1.id, titel: 'Packliste');
      store.verknuepfen(n.id, a2.id);
      expect(store.notizenZu(a1.id).single.id, n.id);
      expect(store.aufgabenZu(n).map((a) => a.id), [a1.id, a2.id]);

      store.verknuepfungLoesen(n.id, a1.id);
      expect(store.notizenZu(a1.id), isEmpty);
    });

    test('Gelöschte Aufgabe verschwindet aus der Notiz', () async {
      final store = await neuerStore();
      final a = store.aufgaben.first;
      final n = store.notizAnlegen(aufgabeId: a.id);
      store.loeschen(a.id);
      expect(n.aufgabenIds, isEmpty);
    });

    test('Leere Notiz ohne Verknüpfung wird entfernt', () async {
      final store = await neuerStore();
      final n = store.notizAnlegen();
      store.leereNotizEntfernen(n.id);
      expect(store.notizen, isEmpty);
    });

    test('Notizen überstehen Speichern und Laden', () async {
      final speicher = ArbeitsspeicherSpeicher();
      final store = AufgabenStore(speicher);
      await store.laden();
      store.notizAnlegen(titel: 'Ideen')..checkliste.add(Unteraufgabe(titel: 'Eins'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final neu = AufgabenStore(speicher);
      await neu.laden();
      expect(neu.notizen.single.titel, 'Ideen');
      expect(neu.notizen.single.checkliste.single.titel, 'Eins');
    });
  });

  testWidgets('Nach rechts wischen erledigt die Aufgabe', (tester) async {
    final store = await neuerStore();
    await tester.pumpWidget(RuhepolApp(
      store: store,
      kalender: KalenderDienst(store),
      erinnerungen: ErinnerungsDienst(store),
    ));
    await tester.pumpAndSettle();

    const titel = 'Tippe auf den Kreis, um mich abzuhaken';
    await tester.drag(find.text(titel), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(store.aufgaben.firstWhere((a) => a.titel == titel).erledigt, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Notizen-Ansicht öffnet sich unter Listen', (tester) async {
    final store = await neuerStore();
    store.notizAnlegen(titel: 'Geschenkideen');
    await tester.pumpWidget(RuhepolApp(
      store: store,
      kalender: KalenderDienst(store),
      erinnerungen: ErinnerungsDienst(store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SegmentedButton<int>, 'Notizen'));
    await tester.pumpAndSettle();
    expect(find.text('Geschenkideen'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
