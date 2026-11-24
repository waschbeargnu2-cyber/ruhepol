import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../eingabe_parser.dart';
import '../modelle.dart';
import 'hinweis.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Fenster „Neue Aufgabe“.
// Während du tippst, zeigt es an, was erkannt wurde (Datum, Uhrzeit, Liste …).
// Die Erkennung selbst steckt in eingabe_parser.dart.
// ---------------------------------------------------------------------------

Future<void> zeigeNeueAufgabe(
  BuildContext context, {
  String? listeId,
  DateTime? faellig,
}) {
  final store = StoreScope.lesen(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => NeueAufgabe(store: store, listeId: listeId, faellig: faellig),
  );
}

class NeueAufgabe extends StatefulWidget {
  const NeueAufgabe({
    super.key,
    required this.store,
    this.listeId,
    this.faellig,
  });

  final AufgabenStore store;
  final String? listeId;
  final DateTime? faellig;

  @override
  State<NeueAufgabe> createState() => _NeueAufgabeState();
}

class _NeueAufgabeState extends State<NeueAufgabe> {
  final _eingabe = TextEditingController();

  static const _beispiele = [
    'Zahnarzt morgen 15 Uhr #Gesundheit !!',
    'Müll rausbringen jeden Dienstag #Haushalt',
    'Steuererklärung abgeben bis 15.12. !!!',
    'Pflanzen gießen alle 4 Tage nach Erledigen',
  ];

  @override
  void initState() {
    super.initState();
    _eingabe.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _eingabe.dispose();
    super.dispose();
  }

  ParseErgebnis get _ergebnis =>
      analysiere(_eingabe.text, heute: heute(), listen: widget.store.listen);

  void _hinzufuegen() {
    final r = _ergebnis;
    if (r.titel.isEmpty) return;
    final store = widget.store;

    var listeId = r.listeId ?? widget.listeId ?? store.listen.first.id;
    if (r.listeId == null && r.listeName != null) {
      final name = r.listeName!;
      listeId = store
          .listeAnlegen(name[0].toUpperCase() + name.substring(1))
          .id;
    }

    final a = Aufgabe(
      titel: r.titel,
      listeId: listeId,
      faellig: r.faellig ?? widget.faellig,
      uhrzeit: r.uhrzeit,
      frist: r.frist,
      prioritaet: r.prioritaet,
      wiederholung: r.wiederholung,
    );
    store.hinzufuegen(a);

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final teile = [
      a.faellig != null ? relativ(a.faellig!) : 'Ohne Datum',
      if (a.uhrzeit != null) uhrzeitText(a.uhrzeit!),
      store.listeVon(a.listeId).name,
    ];
    zeigeHinweis(messenger, 'Hinzugefügt: ${teile.join(' · ')}', rueckgaengig: store);
  }

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = _ergebnis;
    final store = widget.store;

    final erkannt = <Widget>[
      if (r.faellig != null) _Erkannt(Icons.event, relativ(r.faellig!)),
      if (r.uhrzeit != null) _Erkannt(Icons.schedule, uhrzeitText(r.uhrzeit!)),
      if (r.listeName != null)
        _Erkannt(
          Icons.label_outline,
          r.listeId != null
              ? store.listeVon(r.listeId!).name
              : 'Neue Liste: ${r.listeName}',
        ),
      if (r.prioritaet != Prioritaet.keine)
        _Erkannt(Icons.priority_high, r.prioritaet.label),
      if (r.frist != null) _Erkannt(Icons.flag, 'Frist ${relativ(r.frist!)}'),
      if (r.wiederholung != null) _Erkannt(Icons.repeat, r.wiederholung!.label),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Neue Aufgabe', style: text.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _eingabe,
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _hinzufuegen(),
              decoration: InputDecoration(
                hintText: 'z. B. Zahnarzt morgen 15 Uhr #Gesundheit',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (erkannt.isEmpty)
              Text(
                'Erkannt werden z. B.: morgen, Freitag, 15.12., 15 Uhr, #Liste, '
                '! bis !!!, bis Freitag (Frist), täglich, jeden Montag.',
                style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
              )
            else
              Wrap(spacing: 6, runSpacing: 6, children: erkannt),
            const SizedBox(height: 16),
            Text('Beispiele', style: text.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in _beispiele)
                  ActionChip(
                    label: Text(b),
                    onPressed: () => _eingabe.value = TextEditingValue(
                      text: b,
                      selection: TextSelection.collapsed(offset: b.length),
                    ),
                  ),
              ],
            ),
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
                  onPressed: r.titel.isEmpty ? null : _hinzufuegen,
                  icon: const Icon(Icons.add),
                  label: const Text('Hinzufügen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Erkannt extends StatelessWidget {
  const _Erkannt(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: farben.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: farben.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: farben.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}
