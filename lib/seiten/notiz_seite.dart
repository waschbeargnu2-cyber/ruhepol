import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../modelle.dart';
import '../widgets/aufgabe_details.dart';
import '../widgets/aufgabe_kachel.dart';
import '../widgets/hinweis.dart';
import '../widgets/neue_aufgabe.dart';
import '../widgets/verknuepfen.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Eine Notiz bearbeiten.
// Titel, Text, Checkliste, Farbe, Anheften und verknüpfte Aufgaben.
// Alles wird sofort gespeichert. Eine leere Notiz ohne Verknüpfung wird beim
// Verlassen automatisch entfernt.
// ---------------------------------------------------------------------------

Future<void> oeffneNotiz(BuildContext context, String id) {
  final store = StoreScope.lesen(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => NotizSeite(store: store, id: id)),
  );
}

class NotizSeite extends StatefulWidget {
  const NotizSeite({super.key, required this.store, required this.id});

  final AufgabenStore store;
  final String id;

  @override
  State<NotizSeite> createState() => _NotizSeiteState();
}

class _NotizSeiteState extends State<NotizSeite> {
  late final TextEditingController _titel;
  late final TextEditingController _inhalt;
  final _neuerPunkt = TextEditingController();

  AufgabenStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    final n = _store.notiz(widget.id);
    _titel = TextEditingController(text: n?.titel ?? '');
    _inhalt = TextEditingController(text: n?.inhalt ?? '');
  }

  @override
  void dispose() {
    _titel.dispose();
    _inhalt.dispose();
    _neuerPunkt.dispose();
    super.dispose();
  }

  void _punktHinzufuegen(Notiz n) {
    final t = _neuerPunkt.text.trim();
    if (t.isEmpty) return;
    n.checkliste.add(Unteraufgabe(titel: t));
    _neuerPunkt.clear();
    _store.notizGeaendert(n);
  }

  Future<void> _aufgabenWaehlen(Notiz n) async {
    final auswahl = await waehleAufgaben(context, _store, vorausgewaehlt: n.aufgabenIds.toSet());
    if (auswahl == null) return;
    n.aufgabenIds
      ..clear()
      ..addAll(auswahl);
    _store.notizGeaendert(n);
  }

  Future<void> _aufgabeErstellen(Notiz n) async {
    await zeigeNeueAufgabe(
      context,
      vorgabe: n.titel.trim().isEmpty ? null : n.titel.trim(),
      onErstellt: (a) => _store.verknuepfen(n.id, a.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _store.leereNotizEntfernen(widget.id);
      },
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final n = _store.notiz(widget.id);
          if (n == null) {
            return const Scaffold(body: Center(child: Text('Notiz gelöscht')));
          }
          return _inhaltBauen(context, n);
        },
      ),
    );
  }

  Widget _inhaltBauen(BuildContext context, Notiz n) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lf = listenFarbe(n.farbe, farben.brightness);
    final aufgaben = _store.aufgabenZu(n);

    return Scaffold(
      backgroundColor: Color.alphaBlend(lf.hintergrund.withValues(alpha: 0.35), farben.surface),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: n.angeheftet ? 'Lösen' : 'Anheften',
            onPressed: () {
              n.angeheftet = !n.angeheftet;
              _store.notizGeaendert(n);
            },
            icon: Icon(n.angeheftet ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          PopupMenuButton<int>(
            tooltip: 'Farbe',
            icon: const Icon(Icons.palette_outlined),
            onSelected: (i) {
              n.farbe = i;
              _store.notizGeaendert(n);
            },
            itemBuilder: (_) => [
              for (var i = 0; i < listenFarben.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: listenFarbe(i, farben.brightness).hintergrund,
                      ),
                      const SizedBox(width: 10),
                      Text(i == n.farbe ? 'Aktuelle Farbe' : 'Farbe ${i + 1}'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Löschen',
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              _store.notizLoeschen(n.id);
              zeigeHinweis(messenger, 'Notiz gelöscht', rueckgaengig: _store);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          TextField(
            controller: _titel,
            style: text.headlineSmall,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Titel'),
            onChanged: (v) {
              n.titel = v;
              _store.notizGeaendert(n);
            },
          ),
          TextField(
            controller: _inhalt,
            minLines: 4,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Notiz schreiben …',
            ),
            onChanged: (v) {
              n.inhalt = v;
              _store.notizGeaendert(n);
            },
          ),

          // Checkliste
          const Abschnitt('Checkliste'),
          for (var i = 0; i < n.checkliste.length; i++)
            Row(
              children: [
                Checkbox(
                  value: n.checkliste[i].erledigt,
                  onChanged: (v) {
                    n.checkliste[i].erledigt = v ?? false;
                    _store.notizGeaendert(n);
                  },
                ),
                Expanded(
                  child: Text(
                    n.checkliste[i].titel,
                    style: n.checkliste[i].erledigt
                        ? TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: farben.onSurfaceVariant,
                          )
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Entfernen',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    n.checkliste.removeAt(i);
                    _store.notizGeaendert(n);
                  },
                ),
              ],
            ),
          TextField(
            controller: _neuerPunkt,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.add),
              hintText: 'Punkt hinzufügen',
              border: InputBorder.none,
              suffixIcon: IconButton(
                tooltip: 'Hinzufügen',
                icon: const Icon(Icons.keyboard_return),
                onPressed: () => _punktHinzufuegen(n),
              ),
            ),
            onSubmitted: (_) => _punktHinzufuegen(n),
          ),

          // Verknüpfte Aufgaben
          Abschnitt('Verknüpfte Aufgaben', info: '${aufgaben.length}'),
          if (aufgaben.isEmpty)
            Text(
              'Verknüpfe diese Notiz mit einer oder mehreren Aufgaben. Sie erscheint '
              'dann auch in deren Details.',
              style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
            ),
          for (final a in aufgaben)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: farben.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => zeigeAufgabeDetails(context, a.id),
                  child: Row(
                    children: [
                      AbhakKreis(aufgabe: a),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.titel,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                decoration: a.erledigt ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              [
                                _store.listeVon(a.listeId).name,
                                if (a.faellig != null) relativ(a.faellig!),
                              ].join(' · '),
                              style: text.labelSmall?.copyWith(color: farben.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Verknüpfung lösen',
                        onPressed: () => _store.verknuepfungLoesen(n.id, a.id),
                        icon: const Icon(Icons.link_off, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _aufgabenWaehlen(n),
                icon: const Icon(Icons.link),
                label: const Text('Aufgaben verknüpfen'),
              ),
              OutlinedButton.icon(
                onPressed: () => _aufgabeErstellen(n),
                icon: const Icon(Icons.add_task),
                label: const Text('Neue Aufgabe dazu'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Zuletzt geändert: ${relativ(n.geaendert)}, '
            '${uhrzeitText(n.geaendert.hour * 60 + n.geaendert.minute)} Uhr',
            style: text.labelSmall?.copyWith(color: farben.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
