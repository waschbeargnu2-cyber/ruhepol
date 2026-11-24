import 'package:flutter/material.dart';

import 'aufgaben_store.dart';
import 'datum.dart';
import 'design.dart';
import 'konfiguration.dart';
import 'modelle.dart';
import 'widgets/hinweis.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: „Tag planen“.
// 1. Belegte Zeiten sammeln: Termine und Aufgaben, die schon eine Uhrzeit haben.
// 2. Kandidaten: offene Aufgaben ohne Uhrzeit, die an diesem Tag (oder früher)
//    fällig sind. Optional auch Aufgaben ohne Datum.
// 3. Reihenfolge: Priorität, dann nächste Frist, dann Fälligkeit.
// 4. Jede Aufgabe kommt in die erste freie Lücke, in die ihre Dauer passt
//    (ohne Dauer: 30 Min.), mit [planungsPuffer] Minuten Luft danach.
// Zeitfenster und Puffer: konfiguration.dart.
// ---------------------------------------------------------------------------

class PlanEintrag {
  const PlanEintrag(this.aufgabe, this.von, this.bis);

  final Aufgabe aufgabe;
  final int von;
  final int bis;
}

class Tagesplan {
  const Tagesplan(this.eintraege, this.keinPlatz);

  final List<PlanEintrag> eintraege;
  final List<Aufgabe> keinPlatz;
}

int _dauer(Aufgabe a) => a.dauer ?? standardDauerMinuten;

Tagesplan planeTag({
  required List<Aufgabe> aufgaben,
  required List<Termin> termine,
  required DateTime tag,
  required DateTime jetzt,
  bool ohneDatum = false,
  int beginn = tagBeginn,
  int ende = tagEnde,
  int puffer = planungsPuffer,
}) {
  final t = nurDatum(tag);
  var start = beginn;
  if (tageZwischen(jetzt, t) == 0) {
    final minute = jetzt.hour * 60 + jetzt.minute;
    final aufgerundet = ((minute + 14) ~/ 15) * 15;
    if (aufgerundet > start) start = aufgerundet;
  }
  if (tageZwischen(jetzt, t) < 0 || start >= ende) return const Tagesplan([], []);

  // 1. Belegte Zeiten
  final belegt = <(int, int)>[
    for (final x in termine.where((x) => !x.ganztaegig && x.amTag(t)))
      (
        x.start.isBefore(t) ? 0 : x.start.hour * 60 + x.start.minute,
        x.ende.isBefore(plusTage(t, 1)) ? x.ende.hour * 60 + x.ende.minute : 24 * 60,
      ),
    for (final a in aufgaben.where((a) =>
        !a.erledigt && a.uhrzeit != null && a.faellig != null && tageZwischen(t, a.faellig!) == 0))
      (a.uhrzeit!, a.uhrzeit! + _dauer(a)),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  // Freie Lücken
  final frei = <List<int>>[];
  var cursor = start;
  for (final (von, bis) in belegt) {
    if (von > cursor) frei.add([cursor, von < ende ? von : ende]);
    if (bis + puffer > cursor) cursor = bis + puffer;
    if (cursor >= ende) break;
  }
  if (cursor < ende) frei.add([cursor, ende]);

  // 2./3. Kandidaten
  final kandidaten = aufgaben
      .where((a) =>
          !a.erledigt &&
          a.uhrzeit == null &&
          ((a.faellig != null && !a.faellig!.isAfter(t)) || (ohneDatum && a.faellig == null)))
      .toList()
    ..sort((a, b) {
      if (a.prioritaet != b.prioritaet) {
        return b.prioritaet.index.compareTo(a.prioritaet.index);
      }
      final fa = a.frist, fb = b.frist;
      if (fa != fb) {
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fa.compareTo(fb);
      }
      final da = a.faellig, db = b.faellig;
      if (da != db) {
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      }
      return a.erstellt.compareTo(b.erstellt);
    });

  // 4. Einsortieren (erste passende Lücke)
  final eintraege = <PlanEintrag>[];
  final keinPlatz = <Aufgabe>[];
  for (final a in kandidaten) {
    final d = _dauer(a);
    final luecke = frei.where((l) => l[1] - l[0] >= d).firstOrNull;
    if (luecke == null) {
      keinPlatz.add(a);
      continue;
    }
    eintraege.add(PlanEintrag(a, luecke[0], luecke[0] + d));
    luecke[0] = luecke[0] + d + puffer;
  }
  eintraege.sort((a, b) => a.von.compareTo(b.von));
  return Tagesplan(eintraege, keinPlatz);
}

/// Öffnet die Vorschau „Tag planen“ für [tag] (Standard: heute).
Future<void> zeigeTagPlanen(BuildContext context, {DateTime? tag}) {
  final store = StoreScope.lesen(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _TagPlanen(store: store, tag: nurDatum(tag ?? DateTime.now())),
  );
}

class _TagPlanen extends StatefulWidget {
  const _TagPlanen({required this.store, required this.tag});

  final AufgabenStore store;
  final DateTime tag;

  @override
  State<_TagPlanen> createState() => _TagPlanenState();
}

class _TagPlanenState extends State<_TagPlanen> {
  bool _ohneDatum = false;
  final _abgewaehlt = <String>{};

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final plan = planeTag(
      aufgaben: widget.store.aufgaben,
      termine: widget.store.termine,
      tag: widget.tag,
      jetzt: DateTime.now(),
      ohneDatum: _ohneDatum,
    );
    final gewaehlt = plan.eintraege.where((e) => !_abgewaehlt.contains(e.aufgabe.id)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: farben.primary),
              const SizedBox(width: 8),
              Text('${relativ(widget.tag)} planen', style: text.titleLarge),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Agenda verteilt deine offenen Aufgaben nach Wichtigkeit auf die freien '
            'Zeiten zwischen deinen Terminen. Abwählen, was nicht passt.',
            style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auch Aufgaben ohne Datum'),
            value: _ohneDatum,
            onChanged: (v) => setState(() => _ohneDatum = v),
          ),
          if (plan.eintraege.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LeerHinweis(
                'Nichts zu planen: Es gibt keine offenen Aufgaben ohne Uhrzeit '
                'oder keine freie Zeit mehr.',
                icon: Icons.event_available,
              ),
            ),
          for (final e in plan.eintraege)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: !_abgewaehlt.contains(e.aufgabe.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _abgewaehlt.remove(e.aufgabe.id);
                } else {
                  _abgewaehlt.add(e.aufgabe.id);
                }
              }),
              title: Text(e.aufgabe.titel),
              subtitle: Text(
                '${uhrzeitText(e.von)}–${uhrzeitText(e.bis)} · ${dauerText(e.bis - e.von)}'
                '${e.aufgabe.dauer == null ? ' (geschätzt)' : ''}',
              ),
              secondary: Icon(
                Icons.circle,
                size: 12,
                color: prioFarbe(e.aufgabe.prioritaet, farben),
              ),
            ),
          if (plan.keinPlatz.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Kein Platz mehr für: ${plan.keinPlatz.map((a) => a.titel).join(', ')}',
              style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: gewaehlt.isEmpty
                    ? null
                    : () {
                        final messenger = ScaffoldMessenger.of(context);
                        widget.store.tagesplanUebernehmen(
                          widget.tag,
                          {for (final e in gewaehlt) e.aufgabe.id: e.von},
                        );
                        Navigator.of(context).pop();
                        zeigeHinweis(
                          messenger,
                          '${gewaehlt.length} Aufgaben eingeplant',
                          rueckgaengig: widget.store,
                        );
                      },
                icon: const Icon(Icons.check),
                label: Text('Übernehmen (${gewaehlt.length})'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
