import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../eingabe_parser.dart';
import '../modelle.dart';
import 'hinweis.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Fenster „Neue Aufgabe“.
// Während du tippst, zeigt es an, was erkannt wurde (Datum, Uhrzeit, Dauer,
// Liste …). Die Erkennung steckt in eingabe_parser.dart.
// Darunter stehen Vorschläge:
//   • Vorlagen (Lesezeichen-Symbol): übernehmen Liste, Priorität, Dauer,
//     Unteraufgaben und Notiz. Datum/Uhrzeit aus deinem Text haben Vorrang.
//   • Häufige Einträge (Uhr-Symbol): alles, was du mindestens 2× eingetragen
//     hast. Ab dem 3. Mal bietet die App an, daraus eine Vorlage zu machen.
// ---------------------------------------------------------------------------

/// Ab so vielen gleichen Einträgen wird „Als Vorlage speichern?“ angeboten.
const _vorlageAb = 3;

Future<void> zeigeNeueAufgabe(
  BuildContext context, {
  String? listeId,
  DateTime? faellig,
  String? vorgabe,
  String? notiz,
  void Function(Aufgabe a)? onErstellt,
}) {
  final store = StoreScope.lesen(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => NeueAufgabe(
      store: store,
      listeId: listeId,
      faellig: faellig,
      vorgabe: vorgabe,
      notiz: notiz,
      onErstellt: onErstellt,
    ),
  );
}

class NeueAufgabe extends StatefulWidget {
  const NeueAufgabe({
    super.key,
    required this.store,
    this.listeId,
    this.faellig,
    this.vorgabe,
    this.notiz,
    this.onErstellt,
  });

  final AufgabenStore store;
  final String? listeId;
  final DateTime? faellig;

  /// Vorbelegter Text (z. B. beim Teilen aus einer anderen App).
  final String? vorgabe;

  /// Notiz, die an die neue Aufgabe angehängt wird (z. B. geteilter Text).
  final String? notiz;

  /// Wird nach dem Anlegen aufgerufen (z. B. um sie mit einer Notiz zu verknüpfen).
  final void Function(Aufgabe a)? onErstellt;

  @override
  State<NeueAufgabe> createState() => _NeueAufgabeState();
}

class _NeueAufgabeState extends State<NeueAufgabe> {
  final _eingabe = TextEditingController();

  /// Gewählte Vorlage oder gewählter häufiger Eintrag.
  Vorlage? _vorlage;
  Haeufig? _haeufig;

  /// Vorlage bewusst entfernt: auch bei gleichem Titel nicht automatisch anwenden.
  bool _ohneVorlage = false;

  /// Gewählte Vorlage, sonst eine Vorlage mit genau diesem Titel.
  Vorlage? _aktiveVorlage(String titel) =>
      _vorlage ?? (_ohneVorlage || _haeufig != null ? null : widget.store.vorlageFuer(titel));

  static const _beispiele = [
    'Zahnarzt morgen 15 Uhr #Gesundheit !!',
    'Präsentation vorbereiten Freitag 2 Std. !!!',
    'Müll rausbringen jeden Dienstag #Haushalt',
    'Pflanzen gießen alle 4 Tage nach Erledigen',
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.vorgabe;
    if (v != null && v.isNotEmpty) _setzeText(v);
    _eingabe.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _eingabe.dispose();
    super.dispose();
  }

  void _setzeText(String t) {
    _eingabe.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  ParseErgebnis get _ergebnis =>
      analysiere(_eingabe.text, heute: heute(), listen: widget.store.listen);

  void _hinzufuegen() {
    final r = _ergebnis;
    if (r.titel.isEmpty) return;
    final store = widget.store;
    final v = _aktiveVorlage(r.titel);
    final hf = _haeufig;

    var listeId = r.listeId ?? v?.listeId ?? hf?.listeId ?? widget.listeId ?? store.listen.first.id;
    if (r.listeId == null && r.listeName != null) {
      final name = r.listeName!;
      listeId = store.listeAnlegen(name[0].toUpperCase() + name.substring(1)).id;
    }
    if (!store.listen.any((l) => l.id == listeId)) listeId = store.listen.first.id;

    final a = Aufgabe(
      titel: r.titel,
      listeId: listeId,
      faellig: r.faellig ?? widget.faellig,
      uhrzeit: r.uhrzeit,
      frist: r.frist,
      prioritaet: r.prioritaet != Prioritaet.keine
          ? r.prioritaet
          : (v?.prioritaet ?? hf?.prioritaet ?? Prioritaet.keine),
      wiederholung: r.wiederholung ?? v?.wiederholung,
      dauer: r.dauer ?? v?.dauer ?? hf?.dauer,
      unteraufgaben: [for (final u in v?.unteraufgaben ?? const <String>[]) Unteraufgabe(titel: u)],
      notiz: widget.notiz ?? v?.notiz ?? '',
    );
    store.hinzufuegen(a);
    widget.onErstellt?.call(a);

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final teile = [
      a.faellig != null ? relativ(a.faellig!) : 'Ohne Datum',
      if (a.uhrzeit != null) uhrzeitText(a.uhrzeit!),
      store.listeVon(a.listeId).name,
    ];

    // Schon oft eingetragen und noch keine Vorlage? Dann anbieten.
    final anzahl = store.haeufigkeit(a.titel);
    if (anzahl >= _vorlageAb && store.vorlageFuer(a.titel) == null) {
      zeigeHinweis(
        messenger,
        'Schon $anzahl× eingetragen. Als Vorlage speichern?',
        aktion: (
          'Vorlage',
          () {
            store.vorlageSpeichern(a);
            zeigeHinweis(messenger, 'Vorlage „${a.titel}“ gespeichert');
          },
        ),
      );
    } else {
      zeigeHinweis(messenger, 'Hinzugefügt: ${teile.join(' · ')}', rueckgaengig: store);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = _ergebnis;
    final store = widget.store;
    final v = _aktiveVorlage(r.titel);

    final erkannt = <Widget>[
      if (r.faellig != null) _Erkannt(Icons.event, relativ(r.faellig!)),
      if (r.uhrzeit != null) _Erkannt(Icons.schedule, uhrzeitText(r.uhrzeit!)),
      if (r.dauer != null) _Erkannt(Icons.timelapse, dauerText(r.dauer!)),
      if (r.listeName != null)
        _Erkannt(
          Icons.label_outline,
          r.listeId != null ? store.listeVon(r.listeId!).name : 'Neue Liste: ${r.listeName}',
        ),
      if (r.prioritaet != Prioritaet.keine) _Erkannt(Icons.priority_high, r.prioritaet.label),
      if (r.frist != null) _Erkannt(Icons.flag, 'Frist ${relativ(r.frist!)}'),
      if (r.wiederholung != null) _Erkannt(Icons.repeat, r.wiederholung!.label),
    ];

    // Vorschläge passend zum bisher getippten Titel
    final vorschlaege = store.vorschlaege(filter: v == null && _haeufig == null ? r.titel : '');
    final hatVorschlaege = vorschlaege.vorlagen.isNotEmpty || vorschlaege.haeufig.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Neue Aufgabe', style: text.titleLarge),
            if (widget.notiz != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.attach_file, size: 16, color: farben.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Der geteilte Text wird als Notiz angehängt.',
                      style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
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

            // Aktive Vorlage
            if (v != null || _haeufig != null) ...[
              InputChip(
                avatar: Icon(v != null ? Icons.bookmark : Icons.history, size: 18),
                label: Text(
                  v != null
                      ? 'Vorlage: ${v.titel}'
                          '${v.unteraufgaben.isNotEmpty ? ' · ${v.unteraufgaben.length} Unteraufgaben' : ''}'
                      : 'Wie zuletzt: ${store.listeVon(_haeufig!.listeId).name}',
                ),
                onDeleted: () => setState(() {
                  _vorlage = null;
                  _haeufig = null;
                  _ohneVorlage = true;
                }),
              ),
              const SizedBox(height: 8),
            ],

            if (erkannt.isEmpty)
              Text(
                'Erkannt werden z. B.: morgen, Freitag, 15.12., 15 Uhr, 30 min, 2 Std., '
                '#Liste, ! bis !!!, bis Freitag (Frist), täglich, jeden Montag.',
                style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
              )
            else
              Wrap(spacing: 6, runSpacing: 6, children: erkannt),
            const SizedBox(height: 16),

            if (hatVorschlaege && v == null && _haeufig == null) ...[
              Text('Vorschläge', style: text.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final x in vorschlaege.vorlagen)
                    ActionChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 18),
                      label: Text(x.titel),
                      onPressed: () => setState(() {
                        _vorlage = x;
                        _haeufig = null;
                        _ohneVorlage = false;
                        _setzeText(x.titel);
                      }),
                    ),
                  for (final x in vorschlaege.haeufig)
                    ActionChip(
                      avatar: const Icon(Icons.history, size: 18),
                      label: Text('${x.titel}  ${x.anzahl}×'),
                      onPressed: () => setState(() {
                        _haeufig = x;
                        _vorlage = null;
                        _setzeText(x.titel);
                      }),
                    ),
                ],
              ),
            ] else if (store.vorlagen.isEmpty && store.haeufig.length < 3) ...[
              Text('Beispiele', style: text.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in _beispiele)
                    ActionChip(label: Text(b), onPressed: () => _setzeText(b)),
                ],
              ),
            ],
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: farben.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}
