import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../modelle.dart';
import '../widgets/aufgabe_details.dart';
import '../widgets/hinweis.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Eisenhower-Matrix.
// Offene Aufgaben in vier Feldern:
//   wichtig + dringend      → Sofort erledigen
//   wichtig, nicht dringend → Einplanen
//   dringend, nicht wichtig → Kurz halten
//   weder noch              → Später oder streichen
// „Wichtig“ und „dringend“ sind in aufgaben_store.dart festgelegt
// (istWichtig / istDringend). Gedrückt halten und in ein anderes Feld ziehen
// ändert Priorität bzw. Datum (rückgängig machbar).
// ---------------------------------------------------------------------------

class _Feld {
  const _Feld(this.titel, this.untertitel, this.icon, this.farbIndex, this.wichtig, this.dringend);

  final String titel;
  final String untertitel;
  final IconData icon;
  final int farbIndex;
  final bool wichtig;
  final bool dringend;
}

const _felder = [
  _Feld('Sofort erledigen', 'wichtig & dringend', Icons.local_fire_department, 5, true, true),
  _Feld('Einplanen', 'wichtig, nicht dringend', Icons.event_available, 0, true, false),
  _Feld('Kurz halten', 'dringend, nicht wichtig', Icons.timer_outlined, 4, false, true),
  _Feld('Später', 'weder noch – oder streichen', Icons.bedtime_outlined, 1, false, false),
];

class MatrixAnsicht extends StatelessWidget {
  const MatrixAnsicht({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final h = heute();
    final offen = store.aufgaben.where((a) => !a.erledigt).toList()
      ..sort(AufgabenStore.sortierung);

    List<Aufgabe> im(_Feld f) => offen
        .where((a) => istWichtig(a) == f.wichtig && istDringend(a, h) == f.dringend)
        .toList();

    Widget zeile(_Feld links, _Feld rechts) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Quadrant(feld: links, aufgaben: im(links))),
              const SizedBox(width: 8),
              Expanded(child: _Quadrant(feld: rechts, aufgaben: im(rechts))),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wichtig = Priorität Mittel oder Hoch. Dringend = fällig bis morgen oder '
          'Frist in 2 Tagen. Halte eine Aufgabe gedrückt und zieh sie in ein '
          'anderes Feld.',
          style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(width: 4),
            Expanded(child: _Achse('Dringend', farben)),
            const SizedBox(width: 8),
            Expanded(child: _Achse('Nicht dringend', farben)),
          ],
        ),
        const SizedBox(height: 6),
        zeile(_felder[0], _felder[1]),
        const SizedBox(height: 8),
        zeile(_felder[2], _felder[3]),
      ],
    );
  }
}

class _Achse extends StatelessWidget {
  const _Achse(this.text, this.farben);

  final String text;
  final ColorScheme farben;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: farben.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
      );
}

class _Quadrant extends StatelessWidget {
  const _Quadrant({required this.feld, required this.aufgaben});

  static const _maxSichtbar = 6;

  final _Feld feld;
  final List<Aufgabe> aufgaben;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.lesen(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lf = listenFarbe(feld.farbIndex, farben.brightness);

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) {
        final a = store.aufgabe(d.data);
        if (a == null) return false;
        return istWichtig(a) != feld.wichtig || istDringend(a, heute()) != feld.dringend;
      },
      onAcceptWithDetails: (d) {
        final messenger = ScaffoldMessenger.of(context);
        HapticFeedback.mediumImpact();
        store.matrixVerschieben(d.data, wichtig: feld.wichtig, dringend: feld.dringend);
        zeigeHinweis(messenger, 'Verschoben nach „${feld.titel}“', rueckgaengig: store);
      },
      builder: (context, kandidaten, _) {
        final aktiv = kandidaten.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          constraints: const BoxConstraints(minHeight: 150),
          decoration: BoxDecoration(
            color: lf.hintergrund,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: aktiv ? lf.vordergrund : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(feld.icon, size: 18, color: lf.vordergrund),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      feld.titel,
                      style: text.titleSmall?.copyWith(color: lf.vordergrund),
                    ),
                  ),
                  Text(
                    '${aufgaben.length}',
                    style: text.titleSmall?.copyWith(color: lf.vordergrund),
                  ),
                ],
              ),
              Text(
                feld.untertitel,
                style: text.labelSmall?.copyWith(
                  color: lf.vordergrund.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 8),
              if (aufgaben.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Leer',
                    style: text.bodySmall?.copyWith(
                      color: lf.vordergrund.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              for (final a in aufgaben.take(_maxSichtbar))
                _MatrixZeile(aufgabe: a, farbe: lf.vordergrund),
              if (aufgaben.length > _maxSichtbar)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${aufgaben.length - _maxSichtbar} weitere',
                    style: text.labelSmall?.copyWith(color: lf.vordergrund),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MatrixZeile extends StatelessWidget {
  const _MatrixZeile({required this.aufgabe, required this.farbe});

  final Aufgabe aufgabe;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ring = prioFarbe(aufgabe.prioritaet, farben);

    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final store = StoreScope.lesen(context);
              final messenger = ScaffoldMessenger.of(context);
              HapticFeedback.lightImpact();
              store.umschalten(aufgabe.id);
              zeigeHinweis(messenger, 'Erledigt', rueckgaengig: store);
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 1, right: 8),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              aufgabe.titel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: farbe, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    return LongPressDraggable<String>(
      data: aufgabe.id,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: farben.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(blurRadius: 12, color: Color(0x33000000), offset: Offset(0, 4)),
            ],
          ),
          child: Text(
            aufgabe.titel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: inhalt),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => zeigeAufgabeDetails(context, aufgabe.id),
        child: inhalt,
      ),
    );
  }
}
