import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../google_kalender.dart';
import '../modelle.dart';
import '../widgets/aufgabe_kachel.dart';
import '../widgets/hinweis.dart';
import '../widgets/termin_kachel.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Kalender.
// Oben eine Wochenleiste, darunter der gewählte Tag mit Google-Terminen und
// Aufgaben. Smart: Die App sucht freie Zeitfenster (8–20 Uhr, mindestens
// 60 Minuten) und schlägt die wichtigste ungeplante Aufgabe dafür vor.
// Fenster anpassen: die Konstanten _tagBeginn/_tagEnde/_mindestLuecke.
// ---------------------------------------------------------------------------

const _tagBeginn = 8 * 60;
const _tagEnde = 20 * 60;
const _mindestLuecke = 60;

class KalenderSeite extends StatefulWidget {
  const KalenderSeite({super.key});

  @override
  State<KalenderSeite> createState() => _KalenderSeiteState();
}

class _KalenderSeiteState extends State<KalenderSeite> {
  DateTime _tag = heute();
  int _vorschlagIndex = 0;

  void _waehlen(DateTime tag) => setState(() {
        _tag = nurDatum(tag);
        _vorschlagIndex = 0;
      });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final kalender = KalenderScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final h = heute();
    final montag = plusTage(_tag, -(_tag.weekday - 1));

    final termine = store.termineAm(_tag);
    final ganztaegig = termine.where((t) => t.ganztaegig).toList();
    bool amTag(Aufgabe a) => a.faellig != null && tageZwischen(_tag, a.faellig!) == 0;
    final aufgabenMitZeit = store.aufgaben
        .where((a) => !a.erledigt && amTag(a) && a.uhrzeit != null)
        .toList();
    final aufgabenOhneZeit = store.aufgaben
        .where((a) => !a.erledigt && amTag(a) && a.uhrzeit == null)
        .toList()
      ..sort(AufgabenStore.sortierung);

    final zeitplan = <(int, Widget)>[
      for (final t in termine.where((t) => !t.ganztaegig))
        (terminMinute(t, _tag), TerminKachel(termin: t, tag: _tag)),
      for (final a in aufgabenMitZeit)
        (a.uhrzeit!, AufgabeKachel(aufgabe: a, zeigeUhrzeit: false)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final luecken = _freieZeiten(termine, aufgabenMitZeit);
    final kandidaten = store.aufgaben
        .where((a) =>
            !a.erledigt &&
            a.uhrzeit == null &&
            (a.faellig == null || !a.faellig!.isAfter(_tag)))
        .toList()
      ..sort((a, b) {
        if (a.prioritaet != b.prioritaet) {
          return b.prioritaet.index.compareTo(a.prioritaet.index);
        }
        final fa = a.frist, fb = b.frist;
        if (fa != null && fb != null) return fa.compareTo(fb);
        if (fa != null) return -1;
        if (fb != null) return 1;
        return a.erstellt.compareTo(b.erstellt);
      });

    final inhalt = <Widget>[
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${monate[_tag.month - 1]} ${_tag.year}',
                  style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text('Kalender', style: text.headlineMedium),
              ],
            ),
          ),
          if (kalender.verbunden)
            kalender.laedt
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Termine neu laden',
                    onPressed: kalender.aktualisieren,
                    icon: const Icon(Icons.refresh),
                  ),
        ],
      ),
      const SizedBox(height: 12),
      _Wochenleiste(
        montag: montag,
        gewaehlt: _tag,
        heute: h,
        onTag: _waehlen,
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Text(
              '${relativ(_tag)} · ${langesDatum(_tag)}',
              style: text.titleMedium,
            ),
          ),
          if (tageZwischen(h, _tag) != 0)
            TextButton(onPressed: () => _waehlen(h), child: const Text('Heute')),
        ],
      ),
      if (!kalender.verbunden) ...[
        const SizedBox(height: 8),
        _VerbindenHinweis(dienst: kalender),
      ],
      if (kalender.fehler != null) ...[
        const SizedBox(height: 8),
        Text(kalender.fehler!, style: text.bodySmall?.copyWith(color: farben.error)),
      ],
      if (luecken.isNotEmpty && kandidaten.isNotEmpty) ...[
        const SizedBox(height: 12),
        _Vorschlag(
          luecke: luecken.first,
          aufgabe: kandidaten[_vorschlagIndex % kandidaten.length],
          tag: _tag,
          mehrere: kandidaten.length > 1,
          onAndere: () => setState(() => _vorschlagIndex++),
        ),
      ],
      for (final t in ganztaegig)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TerminKachel(termin: t, tag: _tag),
        ),
      if (zeitplan.isNotEmpty) const Abschnitt('Zeitplan'),
      for (final (minute, kachel) in zeitplan)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    uhrzeitText(minute),
                    style: text.labelLarge?.copyWith(
                      color: farben.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              Expanded(child: kachel),
            ],
          ),
        ),
      if (aufgabenOhneZeit.isNotEmpty) ...[
        Abschnitt('Aufgaben ohne Uhrzeit', info: '${aufgabenOhneZeit.length}'),
        for (final a in aufgabenOhneZeit)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AufgabeKachel(aufgabe: a),
          ),
      ],
      if (ganztaegig.isEmpty && zeitplan.isEmpty && aufgabenOhneZeit.isEmpty) ...[
        const SizedBox(height: 16),
        const LeerHinweis('An diesem Tag ist nichts geplant.', icon: Icons.event_note),
      ],
    ];

    return RefreshIndicator(
      onRefresh: kalender.verbunden ? kalender.aktualisieren : () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: inhalt,
      ),
    );
  }

  /// Freie Zeitfenster am gewählten Tag (Minuten von–bis).
  List<(int, int)> _freieZeiten(
    List<Termin> termine,
    List<Aufgabe> aufgabenMitZeit,
  ) {
    final h = heute();
    if (_tag.isBefore(h)) return const [];

    final belegt = <(int, int)>[
      for (final t in termine.where((t) => !t.ganztaegig))
        (
          terminMinute(t, _tag),
          t.ende.isBefore(plusTage(_tag, 1)) ? t.ende.hour * 60 + t.ende.minute : 24 * 60,
        ),
      for (final a in aufgabenMitZeit) (a.uhrzeit!, a.uhrzeit! + 30),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    var frei = _tagBeginn;
    if (tageZwischen(h, _tag) == 0) {
      final jetzt = DateTime.now();
      final minute = jetzt.hour * 60 + jetzt.minute;
      final aufgerundet = ((minute + 29) ~/ 30) * 30;
      if (aufgerundet > frei) frei = aufgerundet;
    }

    final luecken = <(int, int)>[];
    for (final (von, bis) in belegt) {
      if (von - frei >= _mindestLuecke && frei < _tagEnde) {
        luecken.add((frei, von < _tagEnde ? von : _tagEnde));
      }
      if (bis > frei) frei = bis;
    }
    if (_tagEnde - frei >= _mindestLuecke) luecken.add((frei, _tagEnde));
    return luecken.where((l) => l.$2 - l.$1 >= _mindestLuecke).toList();
  }
}

class _Wochenleiste extends StatelessWidget {
  const _Wochenleiste({
    required this.montag,
    required this.gewaehlt,
    required this.heute,
    required this.onTag,
  });

  final DateTime montag;
  final DateTime gewaehlt;
  final DateTime heute;
  final ValueChanged<DateTime> onTag;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: farben.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Vorige Woche',
            onPressed: () => onTag(plusTage(gewaehlt, -7)),
            icon: const Icon(Icons.chevron_left),
          ),
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(builder: (context) {
                final tag = plusTage(montag, i);
                final istGewaehlt = tageZwischen(gewaehlt, tag) == 0;
                final istHeute = tageZwischen(heute, tag) == 0;
                final hatTermine = store.termine.any((t) => t.amTag(tag));
                final hatAufgaben = store.aufgaben.any((a) =>
                    !a.erledigt && a.faellig != null && tageZwischen(tag, a.faellig!) == 0);
                final vorne = istGewaehlt ? farben.onPrimaryContainer : farben.onSurface;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTag(tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: istGewaehlt ? farben.primaryContainer : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          wochentageKurz[i],
                          style: text.labelSmall?.copyWith(
                            color: istGewaehlt ? vorne : farben.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tag.day}',
                          style: text.titleMedium?.copyWith(
                            color: istHeute && !istGewaehlt ? farben.primary : vorne,
                            fontWeight: istHeute ? FontWeight.w700 : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Punkt(sichtbar: hatTermine, farbe: farben.onSurfaceVariant),
                            const SizedBox(width: 3),
                            _Punkt(sichtbar: hatAufgaben, farbe: farben.primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Nächste Woche',
            onPressed: () => onTag(plusTage(gewaehlt, 7)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _Punkt extends StatelessWidget {
  const _Punkt({required this.sichtbar, required this.farbe});

  final bool sichtbar;
  final Color farbe;

  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: sichtbar ? farbe : Colors.transparent,
        ),
      );
}

class _Vorschlag extends StatelessWidget {
  const _Vorschlag({
    required this.luecke,
    required this.aufgabe,
    required this.tag,
    required this.mehrere,
    required this.onAndere,
  });

  final (int, int) luecke;
  final Aufgabe aufgabe;
  final DateTime tag;
  final bool mehrere;
  final VoidCallback onAndere;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (von, bis) = luecke;
    final dauer = (bis - von) / 60;
    final dauerText = dauer == dauer.roundToDouble()
        ? '${dauer.round()} Std.'
        : '${dauer.toStringAsFixed(1).replaceAll('.', ',')} Std.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: farben.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: farben.primary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: farben.primary),
              const SizedBox(width: 8),
              Text(
                'Freies Zeitfenster',
                style: text.labelLarge?.copyWith(color: farben.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${uhrzeitText(von)}–${uhrzeitText(bis)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' ($dauerText) passt für '),
                TextSpan(
                  text: '„${aufgabe.titel}“',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (aufgabe.frist != null)
                  TextSpan(text: ' (Frist: ${relativ(aufgabe.frist!)})'),
                const TextSpan(text: '.'),
              ],
            ),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  final store = StoreScope.lesen(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final verbunden = KalenderScope.of(context).verbunden;
                  aufgabe
                    ..faellig = nurDatum(tag)
                    ..uhrzeit = von;
                  store.geaendert();
                  zeigeHinweis(
                    messenger,
                    '„${aufgabe.titel}“ eingeplant: ${relativ(tag)}, ${uhrzeitText(von)}'
                    '${verbunden ? ' · kommt in den Google Kalender' : ''}',
                  );
                },
                icon: const Icon(Icons.event_available),
                label: const Text('Einplanen'),
              ),
              if (mehrere)
                TextButton(onPressed: onAndere, child: const Text('Andere Aufgabe')),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerbindenHinweis extends StatelessWidget {
  const _VerbindenHinweis({required this.dienst});

  final KalenderDienst dienst;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final eingerichtet = dienst.status != KalenderStatus.nichtEingerichtet;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: farben.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available, color: farben.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              eingerichtet
                  ? 'Verbinde Google, um hier deine Termine zu sehen.'
                  : 'Google Kalender ist noch nicht eingerichtet.',
              style: text.bodyMedium?.copyWith(color: farben.onSecondaryContainer),
            ),
          ),
          if (eingerichtet)
            FilledButton.tonal(
              onPressed: dienst.status == KalenderStatus.verbinde ? null : dienst.verbinden,
              child: const Text('Verbinden'),
            ),
        ],
      ),
    );
  }
}
