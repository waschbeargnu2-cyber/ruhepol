import 'package:flutter/material.dart';

import '../datum.dart';
import '../modelle.dart';

/// Ein Kalender-Termin, sanft in der Farbe seines Kalenders eingefärbt.
class TerminKachel extends StatelessWidget {
  const TerminKachel({super.key, required this.termin, this.tag});

  final Termin termin;

  /// Tag, an dem die Kachel angezeigt wird (für mehrtägige Termine).
  final DateTime? tag;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dunkel = farben.brightness == Brightness.dark;
    final basis = termin.farbe != null ? Color(termin.farbe!) : farben.tertiary;
    final hintergrund =
        Color.alphaBlend(basis.withValues(alpha: dunkel ? 0.30 : 0.22), farben.surface);

    final zeit = termin.ganztaegig ? 'Ganztägig' : _zeitText();
    final zeile2 = [
      zeit,
      termin.kalenderName,
      if (termin.ort != null && termin.ort!.isNotEmpty) termin.ort!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: hintergrund,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.event, size: 20, color: farben.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  termin.titel,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  zeile2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(color: farben.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _zeitText() {
    String hm(DateTime d) => uhrzeitText(d.hour * 60 + d.minute);
    final t = tag;
    final beginntVorher = t != null && termin.start.isBefore(nurDatum(t));
    final endetSpaeter = t != null && !termin.ende.isBefore(plusTage(nurDatum(t), 1));
    if (beginntVorher && endetSpaeter) return 'Den ganzen Tag';
    if (beginntVorher) return 'bis ${hm(termin.ende)}';
    if (endetSpaeter) return 'ab ${hm(termin.start)}';
    return '${hm(termin.start)}–${hm(termin.ende)}';
  }
}

/// Minute des Tages, ab der ein Termin an [tag] beginnt (für die Sortierung).
int terminMinute(Termin t, DateTime tag) {
  if (t.start.isBefore(nurDatum(tag))) return 0;
  return t.start.hour * 60 + t.start.minute;
}
