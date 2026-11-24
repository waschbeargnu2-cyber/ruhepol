import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../modelle.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Auswahlfenster zum Verknüpfen von Notizen und Aufgaben.
// Eine Notiz kann zu beliebig vielen Aufgaben gehören und umgekehrt.
// ---------------------------------------------------------------------------

/// Mehrere Aufgaben auswählen. Gibt die neue Auswahl zurück (oder null).
Future<Set<String>?> waehleAufgaben(
  BuildContext context,
  AufgabenStore store, {
  Set<String> vorausgewaehlt = const {},
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AufgabenWahl(store: store, vorausgewaehlt: vorausgewaehlt),
  );
}

class _AufgabenWahl extends StatefulWidget {
  const _AufgabenWahl({required this.store, required this.vorausgewaehlt});

  final AufgabenStore store;
  final Set<String> vorausgewaehlt;

  @override
  State<_AufgabenWahl> createState() => _AufgabenWahlState();
}

class _AufgabenWahlState extends State<_AufgabenWahl> {
  late final Set<String> _auswahl = {...widget.vorausgewaehlt};
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final f = _filter.toLowerCase();
    final aufgaben = widget.store.aufgaben
        .where((a) =>
            (!a.erledigt || _auswahl.contains(a.id)) &&
            (f.isEmpty || a.titel.toLowerCase().contains(f)))
        .toList()
      ..sort(AufgabenStore.sortierung);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(child: Text('Aufgaben verknüpfen', style: text.titleLarge)),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_auswahl),
                  child: Text('Fertig (${_auswahl.length})'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Aufgabe suchen',
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: aufgaben.isEmpty
                ? Center(
                    child: Text(
                      'Keine offenen Aufgaben gefunden.',
                      style: TextStyle(color: farben.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: aufgaben.length,
                    itemBuilder: (context, i) {
                      final a = aufgaben[i];
                      final liste = widget.store.listeVon(a.listeId);
                      return CheckboxListTile(
                        value: _auswahl.contains(a.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _auswahl.add(a.id);
                          } else {
                            _auswahl.remove(a.id);
                          }
                        }),
                        title: Text(a.titel),
                        subtitle: Text([
                          liste.name,
                          if (a.faellig != null) relativ(a.faellig!),
                          if (a.erledigt) 'erledigt',
                        ].join(' · ')),
                        secondary: Icon(
                          iconFuer(liste.icon),
                          color: listenFarbe(liste.farbe, farben.brightness).vordergrund,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Eine Notiz auswählen. Gibt die ID zurück, 'neu' für eine neue Notiz,
/// oder null bei Abbruch. [ausser] = bereits verknüpfte Notizen.
Future<String?> waehleNotiz(
  BuildContext context,
  AufgabenStore store, {
  Set<String> ausser = const {},
}) {
  final farben = Theme.of(context).colorScheme;
  final notizen = store.notizen.where((n) => !ausser.contains(n.id)).toList()
    ..sort((a, b) => b.geaendert.compareTo(a.geaendert));
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: farben.primaryContainer,
              child: Icon(Icons.add, color: farben.onPrimaryContainer),
            ),
            title: const Text('Neue Notiz'),
            onTap: () => Navigator.of(context).pop('neu'),
          ),
          if (notizen.isNotEmpty) const Divider(),
          for (final n in notizen)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: listenFarbe(n.farbe, farben.brightness).hintergrund,
                child: Icon(
                  Icons.sticky_note_2_outlined,
                  color: listenFarbe(n.farbe, farben.brightness).vordergrund,
                ),
              ),
              title: Text(n.anzeigeTitel, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: n.inhalt.trim().isEmpty
                  ? null
                  : Text(n.inhalt.trim(), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).pop(n.id),
            ),
        ],
      ),
    ),
  );
}

/// Kleine Karte einer verknüpften Notiz (z. B. in den Aufgaben-Details).
class NotizChip extends StatelessWidget {
  const NotizChip({super.key, required this.notiz, required this.onTap, this.onLoesen});

  final Notiz notiz;
  final VoidCallback onTap;
  final VoidCallback? onLoesen;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final lf = listenFarbe(notiz.farbe, farben.brightness);
    return Material(
      color: lf.hintergrund,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 18, color: lf.vordergrund),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notiz.anzeigeTitel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: lf.vordergrund, fontWeight: FontWeight.w500),
                ),
              ),
              if (onLoesen != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Verknüpfung lösen',
                  onPressed: onLoesen,
                  icon: Icon(Icons.link_off, size: 18, color: lf.vordergrund),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
