import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../modelle.dart';
import 'aufgabe_details.dart';
import 'hinweis.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Eine Aufgabe in einer Liste.
// Links der Abhak-Kreis (Farbe = Priorität), rechts Titel und kleine Infos.
// Antippen öffnet die Details.
// Nach RECHTS wischen: erledigen (bzw. wieder öffnen).
// Nach LINKS wischen: Auswahl „Auf morgen“, „Nächste Woche“, „Löschen“.
// ---------------------------------------------------------------------------

class AufgabeKachel extends StatelessWidget {
  const AufgabeKachel({
    super.key,
    required this.aufgabe,
    this.zeigeDatum = false,
    this.zeigeUhrzeit = true,
  });

  final Aufgabe aufgabe;
  final bool zeigeDatum;
  final bool zeigeUhrzeit;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final liste = store.listeVon(aufgabe.listeId);
    final lf = listenFarbe(liste.farbe, farben.brightness);
    final h = heute();
    final warnFarbe = prioFarbe(Prioritaet.hoch, farben);

    final infos = <Widget>[
      if (zeigeUhrzeit && aufgabe.uhrzeit != null)
        _Info(icon: Icons.schedule, text: uhrzeitText(aufgabe.uhrzeit!)),
      if (zeigeDatum && aufgabe.faellig != null)
        _Info(
          icon: Icons.event,
          text: relativ(aufgabe.faellig!),
          farbe: !aufgabe.erledigt && aufgabe.faellig!.isBefore(h) ? warnFarbe : null,
        ),
      _ListenChip(liste: liste, farbe: lf),
      if (aufgabe.frist != null)
        _Info(
          icon: Icons.flag,
          text: 'Frist ${relativ(aufgabe.frist!)}',
          farbe: !aufgabe.erledigt && tageZwischen(h, aufgabe.frist!) <= 1
              ? warnFarbe
              : null,
        ),
      if (aufgabe.unteraufgaben.isNotEmpty)
        _Info(
          icon: Icons.checklist,
          text: '${aufgabe.unteraufgaben.where((u) => u.erledigt).length}'
              '/${aufgabe.unteraufgaben.length}',
        ),
      if (aufgabe.wiederholung != null) const _Info(icon: Icons.repeat),
      if (aufgabe.notiz.isNotEmpty) const _Info(icon: Icons.notes),
      if (aufgabe.kalenderEventId != null) const _Info(icon: Icons.event_available),
      if (aufgabe.dauer != null)
        _Info(icon: Icons.timelapse, text: dauerText(aufgabe.dauer!)),
      if (store.notizenZu(aufgabe.id).isNotEmpty)
        _Info(
          icon: Icons.sticky_note_2_outlined,
          text: '${store.notizenZu(aufgabe.id).length}',
        ),
    ];

    return Dismissible(
      key: ValueKey('kachel-${aufgabe.id}'),
      // Rechts: erledigen
      background: _WischHintergrund(
        links: true,
        farbe: farben.primaryContainer,
        vorne: farben.onPrimaryContainer,
        icon: aufgabe.erledigt ? Icons.undo : Icons.check,
        text: aufgabe.erledigt ? 'Wieder öffnen' : 'Erledigt',
      ),
      // Links: Auswahl
      secondaryBackground: _WischHintergrund(
        links: false,
        farbe: farben.tertiaryContainer,
        vorne: farben.onTertiaryContainer,
        icon: Icons.more_time,
        text: 'Verschieben / Löschen',
      ),
      confirmDismiss: (richtung) async {
        final messenger = ScaffoldMessenger.of(context);
        if (richtung == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          final naechste = store.umschalten(aufgabe.id);
          if (aufgabe.erledigt) {
            zeigeHinweis(
              messenger,
              naechste?.faellig != null
                  ? 'Erledigt. Nächstes Mal: ${relativ(naechste!.faellig!)}'
                  : 'Erledigt',
              rueckgaengig: store,
            );
          }
          return false; // Kachel bleibt (wandert ggf. zu „Erledigt“)
        }
        final wahl = await _wischAuswahl(context, aufgabe);
        if (wahl == null) return false;
        if (wahl == 'loeschen') return true;
        final tage = wahl == 'morgen' ? 1 : 7;
        store.verschieben(aufgabe.id, plusTage(heute(), tage));
        zeigeHinweis(
          messenger,
          'Verschoben auf ${relativ(plusTage(heute(), tage))}',
          rueckgaengig: store,
        );
        return false;
      },
      onDismissed: (_) {
        final messenger = ScaffoldMessenger.of(context);
        final titel = aufgabe.titel;
        store.loeschen(aufgabe.id);
        zeigeHinweis(messenger, 'Gelöscht: $titel', rueckgaengig: store);
      },
      child: Opacity(
        opacity: aufgabe.erledigt ? 0.6 : 1,
        child: Material(
          color: farben.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => zeigeAufgabeDetails(context, aufgabe.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AbhakKreis(aufgabe: aufgabe),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aufgabe.titel,
                            style: text.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              decoration: aufgabe.erledigt
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: infos,
                          ),
                          if (aufgabe.unteraufgaben.isNotEmpty && !aufgabe.erledigt)
                            _Unteraufgaben(aufgabe: aufgabe, store: store),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AbhakKreis extends StatelessWidget {
  const AbhakKreis({super.key, required this.aufgabe});

  final Aufgabe aufgabe;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final farbe = prioFarbe(aufgabe.prioritaet, farben);
    return IconButton(
      tooltip: aufgabe.erledigt ? 'Wieder öffnen' : 'Erledigen',
      onPressed: () {
        final store = StoreScope.lesen(context);
        final messenger = ScaffoldMessenger.of(context);
        HapticFeedback.lightImpact();
        final naechste = store.umschalten(aufgabe.id);
        if (aufgabe.erledigt) {
          final text = naechste?.faellig != null
              ? 'Erledigt. Nächstes Mal: ${relativ(naechste!.faellig!)}'
              : 'Erledigt';
          zeigeHinweis(messenger, text, rueckgaengig: store);
        }
      },
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: farbe, width: 2),
          color: aufgabe.erledigt ? farbe : Colors.transparent,
        ),
        child: aufgabe.erledigt
            ? Icon(Icons.check, size: 16, color: farben.surface)
            : null,
      ),
    );
  }
}

Future<String?> _wischAuswahl(BuildContext context, Aufgabe a) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              a.titel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wb_twilight),
            title: const Text('Auf morgen'),
            onTap: () => Navigator.of(context).pop('morgen'),
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Auf nächste Woche'),
            onTap: () => Navigator.of(context).pop('woche'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: const Text('Löschen'),
            onTap: () => Navigator.of(context).pop('loeschen'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _WischHintergrund extends StatelessWidget {
  const _WischHintergrund({
    required this.links,
    required this.farbe,
    required this.vorne,
    required this.icon,
    required this.text,
  });

  final bool links;
  final Color farbe;
  final Color vorne;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final inhalt = [
      Icon(icon, color: vorne),
      const SizedBox(width: 8),
      Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: vorne)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(color: farbe, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: links ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: links ? inhalt : inhalt.reversed.toList(),
      ),
    );
  }
}

/// Unteraufgaben klein unter dem Titel, direkt abhakbar.
/// Anzahl anpassen: `_maxSichtbar`.
class _Unteraufgaben extends StatelessWidget {
  const _Unteraufgaben({required this.aufgabe, required this.store});

  static const _maxSichtbar = 4;

  final Aufgabe aufgabe;
  final AufgabenStore store;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final alle = aufgabe.unteraufgaben;
    // Offene zuerst, damit das Wichtige sichtbar bleibt
    final sortiert = [...alle.where((u) => !u.erledigt), ...alle.where((u) => u.erledigt)];
    final sichtbar = sortiert.take(_maxSichtbar).toList();
    final rest = alle.length - sichtbar.length;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final u in sichtbar)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                u.erledigt = !u.erledigt;
                store.geaendert();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      u.erledigt ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 16,
                      color: u.erledigt ? farben.primary : farben.outline,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        u.titel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: u.erledigt ? farben.onSurfaceVariant : farben.onSurface,
                          decoration: u.erledigt ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (rest > 0)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                '+ $rest weitere',
                style: text.labelSmall?.copyWith(color: farben.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, this.text, this.farbe});

  final IconData icon;
  final String? text;
  final Color? farbe;

  @override
  Widget build(BuildContext context) {
    final c = farbe ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        if (text != null) ...[
          const SizedBox(width: 3),
          Text(
            text!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c),
          ),
        ],
      ],
    );
  }
}

class _ListenChip extends StatelessWidget {
  const _ListenChip({required this.liste, required this.farbe});

  final Liste liste;
  final ListenFarbe farbe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 9, 2),
      decoration: BoxDecoration(
        color: farbe.hintergrund,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFuer(liste.icon), size: 14, color: farbe.vordergrund),
          const SizedBox(width: 3),
          Text(
            liste.name,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: farbe.vordergrund),
          ),
        ],
      ),
    );
  }
}
