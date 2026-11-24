import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhepol/aufgaben_store.dart';
import 'package:ruhepol/datum.dart';
import 'package:ruhepol/erinnerungen.dart';
import 'package:ruhepol/modelle.dart';
import 'package:ruhepol/seiten/suche_seite.dart';
import 'package:ruhepol/speicher.dart';
import 'package:ruhepol/wochenrueckblick.dart';

Future<AufgabenStore> neuerStore() async {
  final s = AufgabenStore(ArbeitsspeicherSpeicher());
  await s.laden();
  return s;
}

void main() {
  test('Suche findet Titel, Unteraufgaben und Notizen', () async {
    final store = await neuerStore();
    store.hinzufuegen(Aufgabe(
      titel: 'Urlaub planen',
      listeId: 'privat',
      unteraufgaben: [Unteraufgabe(titel: 'Sonnencreme kaufen')],
    ));
    store.notizAnlegen(titel: 'Packliste')..checkliste.add(Unteraufgabe(titel: 'Sonnenbrille'));

    final t = suchen(store, 'sonne');
    expect(t.aufgaben.single.aufgabe!.titel, 'Urlaub planen');
    expect(t.aufgaben.single.wo, contains('Sonnencreme'));
    expect(t.notizen.single.notiz!.titel, 'Packliste');
    expect(suchen(store, '').aufgaben, isEmpty);
  });

  test('Wochenrückblick vergleicht mit der Vorwoche', () async {
    final store = await neuerStore();
    final jetzt = DateTime.now();
    ErledigtEintrag e(DateTime z) => ErledigtEintrag(
        aufgabeId: 'x', zeit: z, prioritaet: Prioritaet.keine, listeId: 'arbeit',
        puenktlich: true, mitFrist: false);
    store.erledigtLog
      ..add(e(jetzt))
      ..add(e(jetzt))
      ..add(e(plusTage(jetzt, -2)))
      ..add(e(plusTage(jetzt, -9)));
    final r = wochenRueckblick(store, jetzt);
    expect(r.erledigt, 3);
    expect(r.vorwoche, 1);
    expect(r.differenz, 2);
    expect(r.topListe, 'Arbeit');
    expect(r.besterTagAnzahl, 2);
    expect(r.puenktlichProzent, 100);
  });

  test('Sonntags-Erinnerung für den Rückblick', () {
    final r = planeErinnerungen(
      aufgaben: const [],
      listen: const [],
      termine: const [],
      e: ErinnerungsEinstellungen(aktiv: true, uebersicht: false),
      jetzt: DateTime(2026, 11, 24, 10), // Dienstag
    );
    expect(r.map((x) => x.zeit), [DateTime(2026, 11, 29, 18), DateTime(2026, 12, 6, 18)]);
    expect(r.first.titel, 'Dein Wochenrückblick');
  });

  test('Farbe vom Hintergrundbild ersetzt das Pastell-Schema', () async {
    final store = await neuerStore();
    final pastell = store.seedFarbe;
    store.systemFarbeSetzen(const Color(0xFF3366CC));
    expect(store.seedFarbe, pastell);
    store.farbeVomHintergrundSetzen(true);
    expect(store.seedFarbe, const Color(0xFF3366CC));
    store.farbeSetzen(store.farbe);
    expect(store.farbeVomHintergrund, isFalse);
  });
}
