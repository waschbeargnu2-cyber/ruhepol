import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../modelle.dart';
import '../widgets/aufgabe_kachel.dart';
import '../widgets/hinweis.dart';
import '../widgets/termin_kachel.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Startseite „Heute“.
// Oben: Fortschritt des Tages. Darunter: Überfälliges, dann der Zeitplan
// (Aufgaben mit Uhrzeit), Aufgaben ohne Uhrzeit, kommende Fristen und
// heute Erledigtes. Termine aus dem Handy-Kalender stehen im Zeitplan.
// ---------------------------------------------------------------------------

class HeuteSeite extends StatelessWidget {
  const HeuteSeite({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final h = heute();
    final stunde = DateTime.now().hour;
    final gruss = stunde < 11
        ? 'Guten Morgen'
        : stunde < 17
            ? 'Hallo'
            : 'Guten Abend';

    bool istHeute(DateTime? d) => d != null && tageZwischen(h, d) == 0;

    final offenHeute =
        store.aufgaben.where((a) => !a.erledigt && istHeute(a.faellig)).toList();
    final ueberfaellig = store.aufgaben
        .where((a) => !a.erledigt && a.faellig != null && a.faellig!.isBefore(h))
        .toList();
    final erledigtHeute =
        store.aufgaben.where((a) => a.erledigt && istHeute(a.erledigtAm)).toList();

    final mitZeit = offenHeute.where((a) => a.uhrzeit != null).toList()
      ..sort((a, b) => a.uhrzeit!.compareTo(b.uhrzeit!));
    final ohneZeit = offenHeute.where((a) => a.uhrzeit == null).toList()
      ..sort(AufgabenStore.sortierung);
    final fristen = store.aufgaben.where((a) {
      if (a.erledigt || a.frist == null || istHeute(a.faellig)) return false;
      final rest = tageZwischen(h, a.frist!);
      return rest >= 0 && rest <= 7;
    }).toList()
      ..sort((a, b) => a.frist!.compareTo(b.frist!));

    // Kalender-Termine von heute: ganztägige oben, die anderen im Zeitplan
    final termine = store.termineAm(h);
    final ganztaegig = termine.where((t) => t.ganztaegig).toList();
    final zeitplan = <(int, Widget)>[
      for (final t in termine.where((t) => !t.ganztaegig))
        (terminMinute(t, h), TerminKachel(termin: t, tag: h)),
      for (final a in mitZeit)
        (a.uhrzeit!, AufgabeKachel(aufgabe: a, zeigeUhrzeit: false)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final gesamt = offenHeute.length + erledigtHeute.length;
    final fortschritt = gesamt == 0 ? 0.0 : erledigtHeute.length / gesamt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      children: [
        Text(
          langesDatum(h),
          style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(gruss, style: text.headlineMedium),
        const SizedBox(height: 16),
        _TagesKarte(
          fortschritt: fortschritt,
          erledigt: erledigtHeute.length,
          gesamt: gesamt,
        ),
        if (ueberfaellig.isNotEmpty) ...[
          const SizedBox(height: 10),
          _UeberfaelligKarte(aufgaben: ueberfaellig),
        ],
        if (ganztaegig.isNotEmpty || zeitplan.isNotEmpty)
          Abschnitt(
            'Zeitplan',
            info: termine.isEmpty
                ? 'mit Uhrzeit'
                : '${termine.length} ${termine.length == 1 ? 'Termin' : 'Termine'}',
          ),
        for (final t in ganztaegig)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TerminKachel(termin: t, tag: h),
          ),
        for (final (minute, kachel) in zeitplan)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      uhrzeitText(minute),
                      style: text.labelLarge?.copyWith(
                        color: farben.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                Expanded(child: kachel),
              ],
            ),
          ),
        Abschnitt('Heute erledigen', info: '${ohneZeit.length} offen'),
        if (ohneZeit.isEmpty)
          const LeerHinweis('Nichts mehr offen für heute. Genieß den Tag!')
        else
          for (final a in ohneZeit)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AufgabeKachel(aufgabe: a),
            ),
        if (fristen.isNotEmpty) ...[
          Abschnitt('Fristen in den nächsten 7 Tagen', info: '${fristen.length}'),
          for (final a in fristen)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AufgabeKachel(aufgabe: a, zeigeDatum: true),
            ),
        ],
        if (erledigtHeute.isNotEmpty) ...[
          Abschnitt('Heute erledigt', info: '${erledigtHeute.length}'),
          for (final a in erledigtHeute)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AufgabeKachel(aufgabe: a),
            ),
        ],
      ],
    );
  }
}

class _TagesKarte extends StatelessWidget {
  const _TagesKarte({
    required this.fortschritt,
    required this.erledigt,
    required this.gesamt,
  });

  final double fortschritt;
  final int erledigt;
  final int gesamt;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final offen = gesamt - erledigt;
    final zeile2 = gesamt == 0
        ? 'Für heute ist noch nichts geplant.'
        : offen == 0
            ? 'Alles geschafft!'
            : 'Noch $offen offen';

    return Card.filled(
      margin: EdgeInsets.zero,
      color: farben.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: fortschritt,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    color: farben.primary,
                    backgroundColor:
                        farben.onPrimaryContainer.withValues(alpha: 0.12),
                  ),
                  Center(
                    child: Text(
                      '${(fortschritt * 100).round()}%',
                      style: text.labelLarge
                          ?.copyWith(color: farben.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$erledigt von $gesamt Aufgaben erledigt',
                    style: text.titleMedium
                        ?.copyWith(color: farben.onPrimaryContainer),
                  ),
                  Text(
                    zeile2,
                    style: text.bodyMedium?.copyWith(
                      color: farben.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UeberfaelligKarte extends StatelessWidget {
  const _UeberfaelligKarte({required this.aufgaben});

  final List<Aufgabe> aufgaben;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final warn = prioFarbe(Prioritaet.hoch, farben);
    final n = aufgaben.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(warn.withValues(alpha: 0.14), farben.surface),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: warn),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$n ${n == 1 ? 'Aufgabe' : 'Aufgaben'} überfällig',
                  style: text.titleSmall,
                ),
                Text(
                  aufgaben.map((a) => a.titel).join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () {
              final store = StoreScope.lesen(context);
              final messenger = ScaffoldMessenger.of(context);
              final anzahl = store.ueberfaelligeAufHeute();
              zeigeHinweis(
                messenger,
                '$anzahl auf heute verschoben',
                rueckgaengig: store,
              );
            },
            child: const Text('Auf heute'),
          ),
        ],
      ),
    );
  }
}
