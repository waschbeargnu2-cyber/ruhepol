import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../modelle.dart';
import 'hinweis.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Detailansicht einer Aufgabe.
// Jede Änderung wird sofort übernommen und gespeichert, es gibt keinen
// „Speichern“-Knopf (wie bei Google Notizen).
// ---------------------------------------------------------------------------

Future<void> zeigeAufgabeDetails(BuildContext context, String id) {
  final store = StoreScope.lesen(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AufgabeDetails(store: store, id: id),
  );
}

const _wiederholungsVorlagen = <(String, Wiederholung?)>[
  ('Keine', null),
  ('Täglich', Wiederholung(art: Intervall.tage)),
  ('Wöchentlich', Wiederholung(art: Intervall.wochen)),
  ('Alle 2 Wochen', Wiederholung(art: Intervall.wochen, anzahl: 2)),
  ('Monatlich', Wiederholung(art: Intervall.monate)),
  ('Jährlich', Wiederholung(art: Intervall.monate, anzahl: 12)),
];

class AufgabeDetails extends StatefulWidget {
  const AufgabeDetails({super.key, required this.store, required this.id});

  final AufgabenStore store;
  final String id;

  @override
  State<AufgabeDetails> createState() => _AufgabeDetailsState();
}

class _AufgabeDetailsState extends State<AufgabeDetails> {
  late final TextEditingController _titel;
  late final TextEditingController _notiz;
  final _neueUnteraufgabe = TextEditingController();

  AufgabenStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    final a = _store.aufgabe(widget.id);
    _titel = TextEditingController(text: a?.titel ?? '');
    _notiz = TextEditingController(text: a?.notiz ?? '');
  }

  @override
  void dispose() {
    _titel.dispose();
    _notiz.dispose();
    _neueUnteraufgabe.dispose();
    super.dispose();
  }

  Future<void> _datumWaehlen(Aufgabe a, {required bool frist}) async {
    final start = (frist ? a.frist : a.faellig) ?? heute();
    final gewaehlt = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: frist ? 'Frist bis' : 'Fällig am',
    );
    if (gewaehlt == null) return;
    if (frist) {
      a.frist = nurDatum(gewaehlt);
    } else {
      a.faellig = nurDatum(gewaehlt);
    }
    _store.geaendert();
  }

  Future<void> _uhrzeitWaehlen(Aufgabe a) async {
    final u = a.uhrzeit;
    final gewaehlt = await showTimePicker(
      context: context,
      initialTime: u != null
          ? TimeOfDay(hour: u ~/ 60, minute: u % 60)
          : TimeOfDay.now(),
      helpText: 'Uhrzeit',
    );
    if (gewaehlt == null) return;
    a.uhrzeit = gewaehlt.hour * 60 + gewaehlt.minute;
    a.faellig ??= heute();
    _store.geaendert();
  }

  Future<void> _wiederholungWaehlen(Aufgabe a) async {
    final index = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Wiederholen'),
        children: [
          for (var i = 0; i < _wiederholungsVorlagen.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(_wiederholungsVorlagen[i].$1),
              ),
            ),
        ],
      ),
    );
    if (index == null) return;
    final vorlage = _wiederholungsVorlagen[index].$2;
    a.wiederholung = vorlage?.mitAbErledigung(a.wiederholung?.abErledigung ?? false);
    if (a.wiederholung != null) a.faellig ??= heute();
    _store.geaendert();
  }

  void _unteraufgabeHinzufuegen(Aufgabe a) {
    final t = _neueUnteraufgabe.text.trim();
    if (t.isEmpty) return;
    a.unteraufgaben.add(Unteraufgabe(titel: t));
    _neueUnteraufgabe.clear();
    _store.geaendert();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final a = _store.aufgabe(widget.id);
        if (a == null) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('Diese Aufgabe gibt es nicht mehr.')),
          );
        }
        return _inhalt(context, a);
      },
    );
  }

  Widget _inhalt(BuildContext context, Aufgabe a) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titel,
              style: text.titleLarge,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Titel',
              ),
              onChanged: (v) {
                a.titel = v;
                _store.geaendert();
              },
            ),
            const SizedBox(height: 8),

            // Liste
            Text('Liste', style: text.labelLarge),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final l in _store.listen)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(
                          iconFuer(l.icon),
                          size: 16,
                          color: listenFarbe(l.farbe, farben.brightness).vordergrund,
                        ),
                        label: Text(l.name),
                        showCheckmark: false,
                        selected: a.listeId == l.id,
                        onSelected: (_) {
                          a.listeId = l.id;
                          _store.geaendert();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Priorität
            Text('Priorität', style: text.labelLarge),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<Prioritaet>(
                showSelectedIcon: false,
                segments: [
                  for (final p in Prioritaet.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {a.prioritaet},
                onSelectionChanged: (s) {
                  a.prioritaet = s.first;
                  _store.geaendert();
                },
              ),
            ),
            const SizedBox(height: 12),

            // Termine
            _Zeile(
              icon: Icons.event,
              titel: 'Fällig',
              wert: a.faellig != null ? relativ(a.faellig!) : 'Kein Datum',
              onTap: () => _datumWaehlen(a, frist: false),
              onEntfernen: a.faellig == null
                  ? null
                  : () {
                      a.faellig = null;
                      a.uhrzeit = null;
                      _store.geaendert();
                    },
            ),
            _Zeile(
              icon: Icons.schedule,
              titel: 'Uhrzeit',
              wert: a.uhrzeit != null ? '${uhrzeitText(a.uhrzeit!)} Uhr' : 'Ohne Uhrzeit',
              onTap: () => _uhrzeitWaehlen(a),
              onEntfernen: a.uhrzeit == null
                  ? null
                  : () {
                      a.uhrzeit = null;
                      _store.geaendert();
                    },
            ),
            _Zeile(
              icon: Icons.flag,
              titel: 'Frist',
              wert: a.frist != null
                  ? '${relativ(a.frist!)} (${a.frist!.day}.${a.frist!.month}.${a.frist!.year})'
                  : 'Keine Frist',
              onTap: () => _datumWaehlen(a, frist: true),
              onEntfernen: a.frist == null
                  ? null
                  : () {
                      a.frist = null;
                      _store.geaendert();
                    },
            ),
            _Zeile(
              icon: Icons.repeat,
              titel: 'Wiederholen',
              wert: a.wiederholung?.label ?? 'Nicht wiederholen',
              onTap: () => _wiederholungWaehlen(a),
            ),
            if (a.wiederholung != null)
              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: 40),
                title: const Text('Erst ab dem Erledigen neu planen'),
                subtitle: const Text('z. B. „4 Tage nach dem letzten Gießen“'),
                value: a.wiederholung!.abErledigung,
                onChanged: (v) {
                  a.wiederholung = a.wiederholung!.mitAbErledigung(v);
                  _store.geaendert();
                },
              ),
            const SizedBox(height: 12),

            // Unteraufgaben
            Text('Unteraufgaben', style: text.labelLarge),
            for (var i = 0; i < a.unteraufgaben.length; i++)
              Row(
                children: [
                  Checkbox(
                    value: a.unteraufgaben[i].erledigt,
                    onChanged: (v) {
                      a.unteraufgaben[i].erledigt = v ?? false;
                      _store.geaendert();
                    },
                  ),
                  Expanded(
                    child: Text(
                      a.unteraufgaben[i].titel,
                      style: a.unteraufgaben[i].erledigt
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
                      a.unteraufgaben.removeAt(i);
                      _store.geaendert();
                    },
                  ),
                ],
              ),
            TextField(
              controller: _neueUnteraufgabe,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.add),
                hintText: 'Unteraufgabe hinzufügen',
                border: InputBorder.none,
                suffixIcon: IconButton(
                  tooltip: 'Hinzufügen',
                  icon: const Icon(Icons.keyboard_return),
                  onPressed: () => _unteraufgabeHinzufuegen(a),
                ),
              ),
              onSubmitted: (_) => _unteraufgabeHinzufuegen(a),
            ),
            const SizedBox(height: 8),

            // Notiz
            TextField(
              controller: _notiz,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Notiz',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) {
                a.notiz = v;
                _store.geaendert();
              },
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: farben.error),
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(context);
                    final titel = a.titel;
                    Navigator.of(context).pop();
                    _store.loeschen(a.id);
                    zeigeHinweis(messenger, 'Gelöscht: $titel', rueckgaengig: _store);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Löschen'),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(context).pop();
                    final naechste = _store.umschalten(a.id);
                    if (a.erledigt) {
                      zeigeHinweis(
                        messenger,
                        naechste?.faellig != null
                            ? 'Erledigt. Nächstes Mal: ${relativ(naechste!.faellig!)}'
                            : 'Erledigt',
                        rueckgaengig: _store,
                      );
                    }
                  },
                  icon: Icon(a.erledigt ? Icons.undo : Icons.check),
                  label: Text(a.erledigt ? 'Wieder öffnen' : 'Erledigt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.icon,
    required this.titel,
    required this.wert,
    required this.onTap,
    this.onEntfernen,
  });

  final IconData icon;
  final String titel;
  final String wert;
  final VoidCallback onTap;
  final VoidCallback? onEntfernen;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: farben.onSurfaceVariant),
      title: Text(wert),
      subtitle: Text(titel),
      onTap: onTap,
      trailing: onEntfernen == null
          ? null
          : IconButton(
              tooltip: '$titel entfernen',
              icon: const Icon(Icons.close),
              onPressed: onEntfernen,
            ),
    );
  }
}
