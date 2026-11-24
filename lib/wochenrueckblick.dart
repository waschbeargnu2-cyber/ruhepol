import 'package:flutter/material.dart';

import 'aufgaben_store.dart';
import 'datum.dart';
import 'design.dart';
import 'erfolge.dart';
import 'modelle.dart';
import 'widgets/aufgabe_kachel.dart';
import 'widgets/hinweis.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Wochenrückblick.
// Betrachtet die letzten 7 Tage (inkl. heute) und vergleicht mit den 7 Tagen
// davor. Sonntags um 18 Uhr erinnert Agenda daran (siehe erinnerungen.dart,
// abschaltbar unter Mehr → Erinnerungen).
// ---------------------------------------------------------------------------

class Rueckblick {
  const Rueckblick({
    required this.von,
    required this.bis,
    required this.erledigt,
    required this.vorwoche,
    required this.punkte,
    required this.besterTag,
    required this.besterTagAnzahl,
    required this.topListe,
    required this.topListeAnzahl,
    required this.puenktlichProzent,
    required this.highlights,
    required this.liegenGeblieben,
    required this.naechsteWoche,
    required this.fristenNaechsteWoche,
  });

  final DateTime von;
  final DateTime bis;
  final int erledigt;
  final int vorwoche;
  final int punkte;
  final DateTime? besterTag;
  final int besterTagAnzahl;
  final String? topListe;
  final int topListeAnzahl;
  final int? puenktlichProzent;

  /// Die wichtigsten erledigten Aufgaben (höchste Priorität zuerst).
  final List<Aufgabe> highlights;

  /// Überfällige offene Aufgaben.
  final List<Aufgabe> liegenGeblieben;
  final int naechsteWoche;
  final int fristenNaechsteWoche;

  int get differenz => erledigt - vorwoche;
}

Rueckblick wochenRueckblick(AufgabenStore store, DateTime jetzt) {
  final h = nurDatum(jetzt);
  final von = plusTage(h, -6);
  final vorVon = plusTage(h, -13);
  bool inWoche(DateTime z) => !nurDatum(z).isBefore(von) && !nurDatum(z).isAfter(h);
  bool inVorwoche(DateTime z) => !nurDatum(z).isBefore(vorVon) && nurDatum(z).isBefore(von);

  final log = store.erledigtLog.where((e) => inWoche(e.zeit)).toList();
  final vorwoche = store.erledigtLog.where((e) => inVorwoche(e.zeit)).length;

  final proTag = <DateTime, int>{};
  final proListe = <String, int>{};
  for (final e in log) {
    final t = nurDatum(e.zeit);
    proTag[t] = (proTag[t] ?? 0) + 1;
    proListe[e.listeId] = (proListe[e.listeId] ?? 0) + 1;
  }
  final besterTag = proTag.entries.fold<MapEntry<DateTime, int>?>(
      null, (m, e) => m == null || e.value > m.value ? e : m);
  final topListe = proListe.entries.fold<MapEntry<String, int>?>(
      null, (m, e) => m == null || e.value > m.value ? e : m);

  final highlights = store.aufgaben
      .where((a) => a.erledigt && a.erledigtAm != null && inWoche(a.erledigtAm!))
      .toList()
    ..sort((a, b) {
      final p = b.prioritaet.index.compareTo(a.prioritaet.index);
      return p != 0 ? p : b.erledigtAm!.compareTo(a.erledigtAm!);
    });

  final offen = store.aufgaben.where((a) => !a.erledigt).toList();
  final naechsteBis = plusTage(h, 7);
  bool naechste(DateTime? d) => d != null && d.isAfter(h) && !d.isAfter(naechsteBis);

  return Rueckblick(
    von: von,
    bis: h,
    erledigt: log.length,
    vorwoche: vorwoche,
    punkte: log.fold(0, (s, e) => s + punkteFuer(e)),
    besterTag: besterTag?.key,
    besterTagAnzahl: besterTag?.value ?? 0,
    topListe: topListe == null ? null : store.listeVon(topListe.key).name,
    topListeAnzahl: topListe?.value ?? 0,
    puenktlichProzent:
        log.isEmpty ? null : (100 * log.where((e) => e.puenktlich).length / log.length).round(),
    highlights: highlights.take(5).toList(),
    liegenGeblieben: offen.where((a) => a.faellig != null && a.faellig!.isBefore(h)).toList()
      ..sort(AufgabenStore.sortierung),
    naechsteWoche: offen.where((a) => naechste(a.faellig)).length,
    fristenNaechsteWoche: offen.where((a) => naechste(a.frist)).length,
  );
}

Future<void> oeffneWochenrueckblick(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WochenrueckblickSeite()),
    );

class WochenrueckblickSeite extends StatelessWidget {
  const WochenrueckblickSeite({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = wochenRueckblick(store, DateTime.now());

    final vergleich = r.vorwoche == 0 && r.erledigt == 0
        ? 'Eine ruhige Woche.'
        : r.differenz > 0
            ? '${r.differenz} mehr als in der Woche davor. Stark!'
            : r.differenz < 0
                ? '${-r.differenz} weniger als in der Woche davor.'
                : 'Genauso viel wie in der Woche davor.';

    return Scaffold(
      appBar: AppBar(title: const Text('Wochenrückblick')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            '${r.von.day}.${r.von.month}. – ${r.bis.day}.${r.bis.month}.${r.bis.year}',
            style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: farben.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.erledigt}',
                  style: text.displayMedium?.copyWith(
                    color: farben.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  r.erledigt == 1 ? 'Aufgabe erledigt' : 'Aufgaben erledigt',
                  style: text.titleMedium?.copyWith(color: farben.onPrimaryContainer),
                ),
                const SizedBox(height: 6),
                Text(
                  '$vergleich  +${r.punkte} Punkte',
                  style: text.bodyMedium?.copyWith(color: farben.onPrimaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (r.besterTag != null)
                _Fakt(
                  Icons.bolt,
                  'Bester Tag',
                  '${wochentage[r.besterTag!.weekday - 1]} (${r.besterTagAnzahl})',
                ),
              if (r.topListe != null)
                _Fakt(Icons.label_outline, 'Fleißigste Liste', '${r.topListe} (${r.topListeAnzahl})'),
              if (r.puenktlichProzent != null)
                _Fakt(Icons.flag_outlined, 'Pünktlich', '${r.puenktlichProzent} %'),
              _Fakt(Icons.event, 'Nächste Woche', '${r.naechsteWoche} geplant'),
              if (r.fristenNaechsteWoche > 0)
                _Fakt(Icons.flag, 'Fristen', '${r.fristenNaechsteWoche} stehen an'),
            ],
          ),
          if (r.highlights.isNotEmpty) ...[
            const Abschnitt('Highlights der Woche'),
            for (final a in r.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20, color: prioFarbe(a.prioritaet, farben)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(a.titel)),
                  ],
                ),
              ),
          ],
          Abschnitt('Liegen geblieben', info: '${r.liegenGeblieben.length}'),
          if (r.liegenGeblieben.isEmpty)
            const LeerHinweis('Nichts überfällig. Du bist auf dem Laufenden!',
                icon: Icons.celebration_outlined)
          else ...[
            Text(
              'Tipp: Nach links wischen → „Auf morgen“ oder „Nächste Woche“, oder '
              'auf „Heute“ den Tag planen lassen.',
              style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final a in r.liegenGeblieben.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AufgabeKachel(aufgabe: a, zeigeDatum: true),
              ),
          ],
        ],
      ),
    );
  }
}

class _Fakt extends StatelessWidget {
  const _Fakt(this.icon, this.titel, this.wert);

  final IconData icon;
  final String titel;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: farben.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: farben.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titel, style: text.labelSmall?.copyWith(color: farben.onSurfaceVariant)),
              Text(wert, style: text.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}
