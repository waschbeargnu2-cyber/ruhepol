import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhepol/app_aktionen.dart';
import 'package:ruhepol/aufgaben_store.dart';
import 'package:ruhepol/datum.dart';
import 'package:ruhepol/erfolge.dart';
import 'package:ruhepol/erinnerungen.dart';
import 'package:ruhepol/handy_kalender.dart';
import 'package:ruhepol/main.dart';
import 'package:ruhepol/modelle.dart';
import 'package:ruhepol/speicher.dart';
import 'package:ruhepol/widget_daten.dart';

ErledigtEintrag eintrag(DateTime zeit,
        {Prioritaet prio = Prioritaet.keine, bool puenktlich = true, String liste = 'privat'}) =>
    ErledigtEintrag(
      aufgabeId: 'x${zeit.millisecondsSinceEpoch}',
      zeit: zeit,
      prioritaet: prio,
      listeId: liste,
      puenktlich: puenktlich,
      mitFrist: false,
    );

void main() {
  group('Erfolge', () {
    final jetzt = DateTime(2026, 11, 24, 18);

    test('Punkte: Grundpunkte, Priorität und Pünktlichkeit', () {
      expect(punkteFuer(eintrag(jetzt, puenktlich: false)), 10);
      expect(punkteFuer(eintrag(jetzt)), 15);
      expect(punkteFuer(eintrag(jetzt, prio: Prioritaet.hoch)), 25);
    });

    test('Level-Schwellen 0, 50, 150, 300', () {
      expect(punkteFuerLevel(1), 0);
      expect(punkteFuerLevel(2), 50);
      expect(punkteFuerLevel(3), 150);
      expect(punkteFuerLevel(4), 300);
      final e = Erfolge.berechnen([for (var i = 0; i < 4; i++) eintrag(jetzt)], jetzt);
      expect(e.punkte, 60);
      expect(e.level, 2);
      expect(e.punkteBisNaechstes, 90);
    });

    test('Serie zählt Tage am Stück bis heute', () {
      final log = [
        eintrag(DateTime(2026, 11, 20, 9)),
        eintrag(DateTime(2026, 11, 22, 9)),
        eintrag(DateTime(2026, 11, 23, 9)),
        eintrag(DateTime(2026, 11, 24, 9)),
        eintrag(DateTime(2026, 11, 24, 10)),
      ];
      final e = Erfolge.berechnen(log, jetzt);
      expect(e.serie, 3);
      expect(e.laengsteSerie, 3);
      expect(e.heute, 2);
      expect(e.besterTag, 2);
      expect(e.letzte7Tage, [0, 0, 1, 0, 1, 1, 2]);
    });

    test('Serie bleibt bestehen, wenn heute noch nichts erledigt ist', () {
      final e = Erfolge.berechnen([eintrag(DateTime(2026, 11, 23, 9))], jetzt);
      expect(e.serie, 1);
    });

    test('Abzeichen werden freigeschaltet', () {
      final e = Erfolge.berechnen([eintrag(DateTime(2026, 11, 24, 7))], jetzt);
      final erreicht = e.abzeichen.where((a) => a.erreicht).map((a) => a.titel);
      expect(erreicht, containsAll(['Erster Haken', 'Frühaufsteher']));
      expect(erreicht, isNot(contains('Zehnerpack')));
    });
  });

  group('Store', () {
    test('Abhaken schreibt ins Protokoll, Wiederöffnen entfernt es', () async {
      final store = AufgabenStore(ArbeitsspeicherSpeicher());
      await store.laden();
      final id = store.aufgaben.first.id;
      store.umschalten(id);
      expect(store.erledigtLog, hasLength(1));
      store.umschalten(id);
      expect(store.erledigtLog, isEmpty);
    });

    test('Alte Daten ohne Protokoll werden übernommen', () async {
      final speicher = ArbeitsspeicherSpeicher();
      speicher.daten = {
        'aufgaben': [
          Aufgabe(
            titel: 'Alt',
            listeId: 'privat',
            erledigt: true,
            erledigtAm: DateTime(2026, 11, 1, 12),
          ).toJson(),
        ],
      };
      final store = AufgabenStore(speicher);
      await store.laden();
      expect(store.erledigtLog, hasLength(1));
    });

    test('Matrix: verschieben ändert Priorität und Datum', () async {
      final store = AufgabenStore(ArbeitsspeicherSpeicher());
      await store.laden();
      final a = Aufgabe(titel: 'M', listeId: 'privat');
      store.hinzufuegen(a);
      final h = heute();
      expect(istWichtig(a), isFalse);
      expect(istDringend(a, h), isFalse);

      store.matrixVerschieben(a.id, wichtig: true, dringend: true);
      expect(istWichtig(a), isTrue);
      expect(istDringend(a, h), isTrue);

      store.matrixVerschieben(a.id, wichtig: false, dringend: false);
      expect(a.prioritaet, Prioritaet.niedrig);
      expect(a.faellig, isNull);
    });
  });

  test('Geteilter Text: erste Zeile wird Titel, Rest Notiz', () {
    final (titel, notiz) = geteiltenTextAufteilen('Milch kaufen\nund Brot nicht vergessen');
    expect(titel, 'Milch kaufen');
    expect(notiz, 'Milch kaufen\nund Brot nicht vergessen');

    final (t2, n2) = geteiltenTextAufteilen('Kurz');
    expect(t2, 'Kurz');
    expect(n2, isNull);

    final (t3, _) = geteiltenTextAufteilen('https://example.com', betreff: 'Artikel lesen');
    expect(t3, 'Artikel lesen');
  });

  test('Widget-Daten enthalten heutige Aufgaben und Farben', () async {
    final store = AufgabenStore(ArbeitsspeicherSpeicher());
    await store.laden();
    final d = widgetDaten(store, DateTime.now());
    final aufgaben = d['aufgaben'] as List;
    expect(aufgaben, isNotEmpty);
    expect((aufgaben.first as Map)['faellig'], tagSchluessel(heute()));
    expect((d['hell'] as Map)['prio'], hasLength(4));
    expect(d['modus'], 'system');
  });

  testWidgets('Unteraufgaben stehen direkt unter der Aufgabe', (tester) async {
    final store = AufgabenStore(ArbeitsspeicherSpeicher());
    await store.laden();
    await tester.pumpWidget(RuhepolApp(
      store: store,
      kalender: KalenderDienst(store),
      erinnerungen: ErinnerungsDienst(store),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Unteraufgaben abhaken'), findsOneWidget);
    await tester.tap(find.text('Unteraufgaben abhaken'));
    await tester.pumpAndSettle();
    final a = store.aufgaben.firstWhere((a) => a.unteraufgaben.isNotEmpty);
    expect(a.unteraufgaben.first.erledigt, isTrue);

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Erfolge-Seite und Matrix lassen sich öffnen', (tester) async {
    final store = AufgabenStore(ArbeitsspeicherSpeicher());
    await store.laden();
    await tester.pumpWidget(RuhepolApp(
      store: store,
      kalender: KalenderDienst(store),
      erinnerungen: ErinnerungsDienst(store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erfolge'));
    await tester.pumpAndSettle();
    expect(find.text('Abzeichen'), findsOneWidget);
    expect(find.text('Neuling'), findsOneWidget);

    await tester.tap(find.text('Listen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SegmentedButton<bool>, 'Matrix'));
    await tester.pumpAndSettle();
    expect(find.text('Sofort erledigen'), findsOneWidget);
    expect(find.text('Einplanen'), findsOneWidget);
  });
}
