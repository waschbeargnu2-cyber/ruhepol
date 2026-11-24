import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../modelle.dart';
import '../widgets/aufgabe_kachel.dart';
import '../widgets/hinweis.dart';
import '../widgets/neue_aufgabe.dart';
import 'matrix_ansicht.dart';
import 'notizen_ansicht.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Listen und smarte Filter.
// Ein smarter Filter ist keine eigene Liste, sondern eine Regel, welche
// Aufgaben er zeigt. Eigenen Filter ergänzen: einen Eintrag in `smarteFilter`
// hinzufügen.
// ---------------------------------------------------------------------------

class SmartFilter {
  const SmartFilter(this.titel, this.icon, this.passt);

  final String titel;
  final IconData icon;
  final bool Function(Aufgabe a, DateTime heute) passt;
}

final smarteFilter = <SmartFilter>[
  SmartFilter('Heute', Icons.wb_sunny_outlined,
      (a, h) => a.faellig != null && !a.faellig!.isAfter(h)),
  SmartFilter('Geplant', Icons.event, (a, h) => a.faellig != null && a.faellig!.isAfter(h)),
  SmartFilter('Wichtig', Icons.priority_high,
      (a, h) => a.prioritaet.index >= Prioritaet.mittel.index),
  SmartFilter('Ohne Datum', Icons.inbox_outlined, (a, h) => a.faellig == null),
];

class ListenSeite extends StatefulWidget {
  const ListenSeite({super.key});

  @override
  State<ListenSeite> createState() => _ListenSeiteState();
}

class _ListenSeiteState extends State<ListenSeite> {
  /// 0 = Listen, 1 = Matrix, 2 = Notizen
  int _ansicht = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final h = heute();
    final offen = store.aufgaben.where((a) => !a.erledigt).toList();

    final kopf = <Widget>[
      Text(
        'Ordnung',
        style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
      ),
      const SizedBox(height: 2),
      Text(['Listen', 'Matrix', 'Notizen'][_ansicht], style: text.headlineMedium),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.view_list), label: Text('Listen')),
            ButtonSegment(value: 1, icon: Icon(Icons.grid_view), label: Text('Matrix')),
            ButtonSegment(
              value: 2,
              icon: Icon(Icons.sticky_note_2_outlined),
              label: Text('Notizen'),
            ),
          ],
          selected: {_ansicht},
          onSelectionChanged: (s) => setState(() => _ansicht = s.first),
        ),
      ),
      const SizedBox(height: 16),
    ];

    if (_ansicht == 1) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [...kopf, const MatrixAnsicht()],
      );
    }
    if (_ansicht == 2) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [...kopf, const NotizenAnsicht()],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      children: [
        ...kopf,
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.75,
          children: [
            for (final f in smarteFilter)
              _FilterKarte(
                filter: f,
                anzahl: offen.where((a) => f.passt(a, h)).length,
              ),
          ],
        ),
        Abschnitt('Meine Listen', info: '${store.listen.length}'),
        for (final l in store.listen)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ListenKarte(liste: l),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => zeigeListenDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Neue Liste'),
        ),
      ],
    );
  }
}

class _FilterKarte extends StatelessWidget {
  const _FilterKarte({required this.filter, required this.anzahl});

  final SmartFilter filter;
  final int anzahl;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: farben.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ListeDetailSeite(filter: filter)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: farben.primaryContainer,
                    foregroundColor: farben.onPrimaryContainer,
                    child: Icon(filter.icon, size: 20),
                  ),
                  const Spacer(),
                  Text('$anzahl', style: text.headlineSmall),
                ],
              ),
              Text(
                filter.titel,
                style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListenKarte extends StatelessWidget {
  const _ListenKarte({required this.liste});

  final Liste liste;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lf = listenFarbe(liste.farbe, farben.brightness);
    final alle = store.aufgaben.where((a) => a.listeId == liste.id).toList();
    final erledigt = alle.where((a) => a.erledigt).length;
    final offen = alle.length - erledigt;

    return Material(
      color: farben.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ListeDetailSeite(listeId: liste.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: lf.hintergrund,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconFuer(liste.icon), color: lf.vordergrund),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(liste.name, style: text.titleMedium),
                    Text(
                      erledigt > 0 ? '$offen offen · $erledigt erledigt' : '$offen offen',
                      style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: alle.isEmpty ? 0 : erledigt / alle.length,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                      color: lf.vordergrund,
                      backgroundColor: lf.hintergrund,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('$offen', style: text.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zeigt eine Liste ODER einen smarten Filter.
class ListeDetailSeite extends StatelessWidget {
  const ListeDetailSeite({super.key, this.listeId, this.filter})
      : assert(listeId != null || filter != null);

  final String? listeId;
  final SmartFilter? filter;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final h = heute();

    final Liste? liste = listeId == null
        ? null
        : store.listen.where((l) => l.id == listeId).firstOrNull;
    if (listeId != null && liste == null) {
      return const Scaffold(body: Center(child: Text('Liste gelöscht')));
    }

    final titel = liste?.name ?? filter!.titel;
    final icon = liste != null ? iconFuer(liste.icon) : filter!.icon;
    final lf = liste != null ? listenFarbe(liste.farbe, farben.brightness) : null;

    final aufgaben = store.aufgaben.where((a) {
      if (liste != null) return a.listeId == liste.id;
      return !a.erledigt && filter!.passt(a, h);
    }).toList()
      ..sort(AufgabenStore.sortierung);
    final offen = aufgaben.where((a) => !a.erledigt).toList();
    final erledigt = aufgaben.where((a) => a.erledigt).toList();

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (liste != null)
            PopupMenuButton<String>(
              onSelected: (wahl) async {
                if (wahl == 'bearbeiten') {
                  await zeigeListenDialog(context, liste: liste);
                } else if (wahl == 'loeschen') {
                  await _listeLoeschen(context, store, liste);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'bearbeiten', child: Text('Bearbeiten')),
                if (store.listen.length > 1)
                  const PopupMenuItem(value: 'loeschen', child: Text('Liste löschen')),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => zeigeNeueAufgabe(
          context,
          listeId: liste?.id,
          faellig: filter?.titel == 'Heute' ? h : null,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Aufgabe'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: lf?.hintergrund ?? farben.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(icon, size: 30, color: lf?.vordergrund ?? farben.onPrimaryContainer),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titel,
                        style: text.headlineSmall?.copyWith(
                          color: lf?.vordergrund ?? farben.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '${offen.length} offen',
                        style: text.bodyMedium?.copyWith(
                          color: lf?.vordergrund ?? farben.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (offen.isEmpty)
            const LeerHinweis('Hier ist gerade nichts offen.', icon: Icons.check_circle_outline),
          for (final a in offen)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AufgabeKachel(aufgabe: a, zeigeDatum: true),
            ),
          if (erledigt.isNotEmpty) ...[
            Abschnitt('Erledigt', info: '${erledigt.length}'),
            for (final a in erledigt)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AufgabeKachel(aufgabe: a, zeigeDatum: true),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _listeLoeschen(
    BuildContext context,
    AufgabenStore store,
    Liste liste,
  ) async {
    final anzahl = store.aufgaben.where((a) => a.listeId == liste.id).length;
    final ersatz = store.listen.firstWhere((l) => l.id != liste.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${liste.name}“ löschen?'),
        content: Text(
          anzahl == 0
              ? 'Die Liste ist leer.'
              : 'Die $anzahl Aufgaben werden nach „${ersatz.name}“ verschoben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    store.listeLoeschen(liste.id);
    zeigeHinweis(messenger, 'Liste gelöscht', rueckgaengig: store);
  }
}

/// Dialog zum Anlegen oder Bearbeiten einer Liste.
Future<void> zeigeListenDialog(BuildContext context, {Liste? liste}) {
  final store = StoreScope.lesen(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _ListenDialog(store: store, liste: liste),
  );
}

class _ListenDialog extends StatefulWidget {
  const _ListenDialog({required this.store, this.liste});

  final AufgabenStore store;
  final Liste? liste;

  @override
  State<_ListenDialog> createState() => _ListenDialogState();
}

class _ListenDialogState extends State<_ListenDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.liste?.name ?? '');
  late int _farbe = widget.liste?.farbe ?? widget.store.listen.length;
  late String _icon = widget.liste?.icon ?? 'liste';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _speichern() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final l = widget.liste;
    if (l == null) {
      widget.store.listeAnlegen(name, farbe: _farbe, icon: _icon);
    } else {
      l
        ..name = name
        ..farbe = _farbe
        ..icon = _icon;
      widget.store.geaendert();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final gewaehlteFarbe = _farbe.abs() % listenFarben.length;

    return AlertDialog(
      title: Text(widget.liste == null ? 'Neue Liste' : 'Liste bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.liste == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (_) => _speichern(),
            ),
            const SizedBox(height: 20),
            Text('Farbe', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < listenFarben.length; i++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _farbe = i),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: listenFarbe(i, farben.brightness).hintergrund,
                        border: Border.all(
                          color: i == gewaehlteFarbe ? farben.onSurface : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: i == gewaehlteFarbe
                          ? Icon(Icons.check, size: 18,
                              color: listenFarbe(i, farben.brightness).vordergrund)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Symbol', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in listenIcons.entries)
                  IconButton(
                    isSelected: e.key == _icon,
                    style: IconButton.styleFrom(
                      backgroundColor: e.key == _icon ? farben.secondaryContainer : null,
                    ),
                    onPressed: () => setState(() => _icon = e.key),
                    icon: Icon(e.value),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _speichern, child: const Text('Speichern')),
      ],
    );
  }
}
