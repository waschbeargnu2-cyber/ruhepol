import 'package:flutter_test/flutter_test.dart';
import 'package:ruhepol/eingabe_parser.dart';
import 'package:ruhepol/modelle.dart';

void main() {
  // Dienstag, 24. November 2026
  final heute = DateTime(2026, 11, 24);
  final listen = [
    Liste(id: 'privat', name: 'Privat', farbe: 0, icon: 'herz'),
    Liste(id: 'gesundheit', name: 'Gesundheit', farbe: 3, icon: 'gesundheit'),
    Liste(id: 'haushalt', name: 'Haushalt', farbe: 2, icon: 'haus'),
  ];

  ParseErgebnis p(String s) => analysiere(s, heute: heute, listen: listen);

  test('Datum, Uhrzeit, Liste und Priorität', () {
    final r = p('Zahnarzt morgen 15 Uhr #Gesundheit !!');
    expect(r.titel, 'Zahnarzt');
    expect(r.faellig, DateTime(2026, 11, 25));
    expect(r.uhrzeit, 15 * 60);
    expect(r.listeId, 'gesundheit');
    expect(r.prioritaet, Prioritaet.mittel);
  });

  test('Uhrzeit mit Doppelpunkt setzt heute', () {
    final r = p('Mama anrufen 18:30');
    expect(r.titel, 'Mama anrufen');
    expect(r.faellig, heute);
    expect(r.uhrzeit, 18 * 60 + 30);
  });

  test('Wochentag ist immer der nächste', () {
    expect(p('Sport Freitag').faellig, DateTime(2026, 11, 27));
    expect(p('Sport Dienstag').faellig, DateTime(2026, 12, 1));
  });

  test('Frist mit Datum und drei Ausrufezeichen', () {
    final r = p('Steuererklärung abgeben bis 15.12. !!!');
    expect(r.titel, 'Steuererklärung abgeben');
    expect(r.frist, DateTime(2026, 12, 15));
    expect(r.prioritaet, Prioritaet.hoch);
    expect(r.faellig, isNull);
  });

  test('Datum in der Vergangenheit springt ins nächste Jahr', () {
    expect(p('Urlaub buchen 3.1.').faellig, DateTime(2027, 1, 3));
  });

  test('Jeden Dienstag beginnt heute', () {
    final r = p('Müll rausbringen jeden Dienstag #Haushalt');
    expect(r.titel, 'Müll rausbringen');
    expect(r.wiederholung, const Wiederholung(art: Intervall.wochen));
    expect(r.faellig, heute);
    expect(r.listeId, 'haushalt');
  });

  test('Alle 4 Tage nach Erledigen', () {
    final r = p('Pflanzen gießen alle 4 Tage nach Erledigen');
    expect(r.titel, 'Pflanzen gießen');
    expect(
      r.wiederholung,
      const Wiederholung(art: Intervall.tage, anzahl: 4, abErledigung: true),
    );
  });

  test('Unbekannte Liste wird gemerkt', () {
    final r = p('Vokabeln lernen #Schule');
    expect(r.listeId, isNull);
    expect(r.listeName, 'Schule');
  });

  test('Text ohne Angaben bleibt unverändert', () {
    final r = p('Einfach nur ein Gedanke');
    expect(r.titel, 'Einfach nur ein Gedanke');
    expect(r.faellig, isNull);
    expect(r.prioritaet, Prioritaet.keine);
  });

  test('Monatliche Wiederholung bleibt im Monat', () {
    const w = Wiederholung(art: Intervall.monate);
    expect(w.naechstes(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
  });
}
