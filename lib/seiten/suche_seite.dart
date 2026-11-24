import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../modelle.dart';
import '../widgets/aufgabe_kachel.dart';
import '../widgets/hinweis.dart';
import '../widgets/verknuepfen.dart';
import 'notiz_seite.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Globale Suche über Aufgaben (Titel, Notiz, Unteraufgaben) und
// Notizen (Titel, Text, Checkliste). Offene Aufgaben stehen vor erledigten.
// Die reine Suchlogik steckt in `suchen()` (testbar).
// ---------------------------------------------------------------------------

class Treffer {
  const Treffer({this.aufgabe, this.notiz, this.wo});

  final Aufgabe? aufgabe;
  final Notiz? notiz;

  /// Wo der Begriff gefunden wurde, wenn nicht im Titel (z. B. „Unteraufgabe: …“).
  final String? wo;
}

({List<Treffer> aufgaben, List<Treffer> notizen}) suchen(AufgabenStore store, String begriff) {
  final b = begriff.trim().toLowerCase();
  if (b.isEmpty) return (aufgaben: const [], notizen: const []);
  bool hat(String s) => s.toLowerCase().contains(b);

  final aufgaben = <Treffer>[];
  final sortiert = store.aufgaben.toList()..sort(AufgabenStore.sortierung);
  for (final a in sortiert) {
    if (hat(a.titel)) {
      aufgaben.add(Treffer(aufgabe: a));
    } else if (hat(a.notiz)) {
      aufgaben.add(Treffer(aufgabe: a, wo: 'in der Notiz'));
    } else {
      final u = a.unteraufgaben.where((u) => hat(u.titel)).firstOrNull;
      if (u != null) aufgaben.add(Treffer(aufgabe: a, wo: 'Unteraufgabe: ${u.titel}'));
    }
  }

  final notizen = <Treffer>[];
  for (final n in store.notizen.toList()..sort((a, b) => b.geaendert.compareTo(a.geaendert))) {
    if (hat(n.titel) || hat(n.inhalt)) {
      notizen.add(Treffer(notiz: n));
    } else {
      final c = n.checkliste.where((c) => hat(c.titel)).firstOrNull;
      if (c != null) notizen.add(Treffer(notiz: n, wo: 'Checkliste: ${c.titel}'));
    }
  }
  return (aufgaben: aufgaben, notizen: notizen);
}

Future<void> oeffneSuche(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SucheSeite()),
    );

class SucheSeite extends StatefulWidget {
  const SucheSeite({super.key});

  @override
  State<SucheSeite> createState() => _SucheSeiteState();
}

class _SucheSeiteState extends State<SucheSeite> {
  final _eingabe = TextEditingController();

  @override
  void dispose() {
    _eingabe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = suchen(store, _eingabe.text);
    final leer = _eingabe.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _eingabe,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Aufgaben und Notizen durchsuchen',
            border: InputBorder.none,
            suffixIcon: leer
                ? null
                : IconButton(
                    tooltip: 'Leeren',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_eingabe.clear),
                  ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (leer)
            const LeerHinweis(
              'Suche in Titeln, Notizen, Unteraufgaben und Checklisten.',
              icon: Icons.search,
            )
          else if (t.aufgaben.isEmpty && t.notizen.isEmpty)
            const LeerHinweis('Nichts gefunden.', icon: Icons.search_off),
          if (t.aufgaben.isNotEmpty) ...[
            Abschnitt('Aufgaben', info: '${t.aufgaben.length}'),
            for (final x in t.aufgaben)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AufgabeKachel(aufgabe: x.aufgabe!, zeigeDatum: true),
                    if (x.wo != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                        child: Text(
                          'Gefunden ${x.wo}',
                          style: text.labelSmall?.copyWith(color: farben.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (t.notizen.isNotEmpty) ...[
            Abschnitt('Notizen', info: '${t.notizen.length}'),
            for (final x in t.notizen)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NotizChip(notiz: x.notiz!, onTap: () => oeffneNotiz(context, x.notiz!.id)),
                    if (x.wo != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                        child: Text(
                          x.wo!,
                          style: text.labelSmall?.copyWith(color: farben.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
