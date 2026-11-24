import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../design.dart';
import '../modelle.dart';
import '../widgets/hinweis.dart';
import 'notiz_seite.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Übersicht aller Notizen (unter „Listen“ → „Notizen“).
// Pastell-Karten in zwei Spalten, angeheftete zuerst, dann die zuletzt
// geänderten. Suche durchsucht Titel, Text und Checklisten.
// ---------------------------------------------------------------------------

class NotizenAnsicht extends StatefulWidget {
  const NotizenAnsicht({super.key});

  @override
  State<NotizenAnsicht> createState() => _NotizenAnsichtState();
}

class _NotizenAnsichtState extends State<NotizenAnsicht> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final f = _filter.trim().toLowerCase();
    bool passt(Notiz n) =>
        f.isEmpty ||
        n.titel.toLowerCase().contains(f) ||
        n.inhalt.toLowerCase().contains(f) ||
        n.checkliste.any((c) => c.titel.toLowerCase().contains(f));

    final notizen = store.notizen.where(passt).toList()
      ..sort((a, b) {
        if (a.angeheftet != b.angeheftet) return a.angeheftet ? -1 : 1;
        return b.geaendert.compareTo(a.geaendert);
      });

    final links = <Widget>[];
    final rechts = <Widget>[];
    for (var i = 0; i < notizen.length; i++) {
      final karte = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _NotizKarte(notiz: notizen[i], store: store),
      );
      (i.isEven ? links : rechts).add(karte);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Notizen durchsuchen',
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () {
                final n = store.notizAnlegen();
                oeffneNotiz(context, n.id);
              },
              icon: const Icon(Icons.add),
              label: const Text('Notiz'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (notizen.isEmpty)
          LeerHinweis(
            store.notizen.isEmpty
                ? 'Halte Gedanken, Ideen und Checklisten fest und verknüpfe sie mit Aufgaben.'
                : 'Keine Notiz gefunden.',
            icon: Icons.sticky_note_2_outlined,
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: links)),
              const SizedBox(width: 8),
              Expanded(child: Column(children: rechts)),
            ],
          ),
      ],
    );
  }
}

class _NotizKarte extends StatelessWidget {
  const _NotizKarte({required this.notiz, required this.store});

  final Notiz notiz;
  final AufgabenStore store;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lf = listenFarbe(notiz.farbe, farben.brightness);
    final verknuepft = store.aufgabenZu(notiz).length;
    final erledigt = notiz.checkliste.where((c) => c.erledigt).length;

    return Material(
      color: lf.hintergrund,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => oeffneNotiz(context, notiz.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      notiz.anzeigeTitel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(color: lf.vordergrund),
                    ),
                  ),
                  if (notiz.angeheftet)
                    Icon(Icons.push_pin, size: 16, color: lf.vordergrund),
                ],
              ),
              if (notiz.inhalt.trim().isNotEmpty && notiz.titel.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  notiz.inhalt.trim(),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: lf.vordergrund.withValues(alpha: 0.85)),
                ),
              ],
              if (notiz.checkliste.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final c in notiz.checkliste.take(3))
                  Row(
                    children: [
                      Icon(
                        c.erledigt ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 14,
                        color: lf.vordergrund,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.titel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: lf.vordergrund,
                            decoration: c.erledigt ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (notiz.checkliste.length > 3)
                  Text(
                    '+ ${notiz.checkliste.length - 3} weitere',
                    style: text.labelSmall?.copyWith(color: lf.vordergrund),
                  ),
              ],
              if (verknuepft > 0 || notiz.checkliste.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (verknuepft > 0)
                      _Mini(Icons.link, '$verknuepft', lf.vordergrund),
                    if (notiz.checkliste.isNotEmpty)
                      _Mini(Icons.checklist, '$erledigt/${notiz.checkliste.length}', lf.vordergrund),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.icon, this.text, this.farbe);

  final IconData icon;
  final String text;
  final Color farbe;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: farbe),
          const SizedBox(width: 3),
          Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: farbe)),
        ],
      );
}
