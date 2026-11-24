import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../widgets/aufgabe_kachel.dart';
import '../widgets/hinweis.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Vorschau der nächsten 14 Tage.
// In Version 0.3 kommen hier die Google-Termine und freien Zeitfenster dazu.
// ---------------------------------------------------------------------------

class KalenderSeite extends StatelessWidget {
  const KalenderSeite({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final h = heute();

    final tage = <Widget>[];
    for (var i = 0; i < 14; i++) {
      final tag = plusTage(h, i);
      final aufgaben = store.aufgaben
          .where((a) => !a.erledigt && a.faellig != null && tageZwischen(tag, a.faellig!) == 0)
          .toList()
        ..sort(AufgabenStore.sortierung);
      if (aufgaben.isEmpty) continue;
      tage.add(Abschnitt(
        i < 3 ? '${relativ(tag)} · ${langesDatum(tag)}' : langesDatum(tag),
        info: '${aufgaben.length}',
      ));
      for (final a in aufgaben) {
        tage.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AufgabeKachel(aufgabe: a),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      children: [
        Text(
          '${monate[h.month - 1]} ${h.year}',
          style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text('Kalender', style: text.headlineMedium),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: farben.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.event_available, color: farben.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Google Kalender kommt in Version 0.3. Bis dahin siehst du hier '
                  'deine geplanten Aufgaben der nächsten 14 Tage.',
                  style: text.bodyMedium?.copyWith(color: farben.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
        if (tage.isEmpty) ...[
          const SizedBox(height: 16),
          const LeerHinweis(
            'In den nächsten 14 Tagen ist nichts geplant.',
            icon: Icons.event_note,
          ),
        ] else
          ...tage,
      ],
    );
  }
}
