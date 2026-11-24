import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../handy_kalender.dart';
import '../widgets/hinweis.dart';

class MehrSeite extends StatelessWidget {
  const MehrSeite({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final offen = store.aufgaben.where((a) => !a.erledigt).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Einstellungen',
          style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text('Mehr', style: text.headlineMedium),

        const Abschnitt('Kalender'),
        const _KalenderKarte(),

        const Abschnitt('Farbschema'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in Pastell.values)
              ChoiceChip(
                label: Text(p.label),
                avatar: CircleAvatar(backgroundColor: p.seed),
                showCheckmark: false,
                selected: p == store.farbe,
                onSelected: (_) => store.farbeSetzen(p),
              ),
          ],
        ),

        const Abschnitt('Hell oder dunkel'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('Automatisch'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('Hell'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('Dunkel'),
              ),
            ],
            selected: {store.themeMode},
            onSelectionChanged: (s) => store.themeModeSetzen(s.first),
          ),
        ),

        const Abschnitt('Deine Daten'),
        Card.filled(
          margin: EdgeInsets.zero,
          color: farben.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_android, color: farben.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$offen offene Aufgaben in ${store.listen.length} Listen, '
                        'nur auf diesem Handy gespeichert.',
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tipp: Schalte unter Einstellungen → Konten und Sicherung → '
                  'Google Drive die Sicherung ein. Dann sichert Android '
                  'Ruhepol automatisch mit.',
                  style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),

        const Abschnitt('Demnächst'),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.notifications_outlined),
          title: Text('Erinnerungen'),
          subtitle: Text('Vor Fristen und zur Uhrzeit'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('Version'),
          subtitle: Text('0.3'),
        ),
      ],
    );
  }
}

class _KalenderKarte extends StatelessWidget {
  const _KalenderKarte();

  @override
  Widget build(BuildContext context) {
    final dienst = KalenderScope.of(context);
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final inhalt = <Widget>[];
    if (dienst.verbunden) {
      final stand = store.termineStand;
      final ziel = dienst.zielKalender;
      inhalt.addAll([
        Row(
          children: [
            Icon(Icons.check_circle, color: farben.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Verbunden · ${store.termine.length} Termine'
                '${stand != null ? ' (Stand ${uhrzeitText(stand.hour * 60 + stand.minute)})' : ''}',
                style: text.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.edit_calendar),
          title: const Text('Aufgaben eintragen in'),
          subtitle: Text(
            ziel == null ? 'Ruhepol (nur auf diesem Handy)' : '${ziel.name} · ${ziel.herkunft}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _zielWaehlen(context, dienst),
        ),
        Text(
          'Nur Aufgaben mit Datum und Uhrzeit werden eingetragen. Deine anderen '
          'Termine liest Ruhepol nur.',
          style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: dienst.laedt ? null : dienst.aktualisieren,
              icon: const Icon(Icons.refresh),
              label: const Text('Aktualisieren'),
            ),
            TextButton(
              onPressed: dienst.ausschalten,
              child: const Text('Ausschalten'),
            ),
          ],
        ),
      ]);
    } else {
      final dauerhaft = dienst.status == KalenderStatus.dauerhaftVerweigert;
      inhalt.addAll([
        Text(
          'Verbinde den Kalender deines Handys: Termine aus Google- und '
          'Samsung-Kalender erscheinen dann in Ruhepol, und Aufgaben mit Uhrzeit '
          'werden dort eingetragen. Dafür braucht es kein Google-Konto in der App.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: dienst.status == KalenderStatus.verbinde
              ? null
              : dauerhaft
                  ? dienst.einstellungenOeffnen
                  : dienst.verbinden,
          icon: Icon(dauerhaft ? Icons.settings : Icons.event_available),
          label: Text(dauerhaft ? 'App-Einstellungen öffnen' : 'Kalender verbinden'),
        ),
        if (dauerhaft) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: dienst.verbinden,
            child: const Text('Erneut prüfen'),
          ),
        ],
      ]);
    }
    if (dienst.fehler != null) {
      inhalt.addAll([
        const SizedBox(height: 10),
        Text(dienst.fehler!, style: text.bodySmall?.copyWith(color: farben.error)),
      ]);
    }

    return Card.filled(
      margin: EdgeInsets.zero,
      color: farben.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: inhalt,
        ),
      ),
    );
  }

  Future<void> _zielWaehlen(BuildContext context, KalenderDienst dienst) async {
    final kalender = dienst.schreibbareKalender;
    final aktuell = dienst.zielKalender?.id;
    final wahl = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Wähle einen Google-Kalender, wenn die Aufgaben auch auf anderen '
                'Geräten erscheinen sollen.',
              ),
            ),
            for (final k in kalender)
              ListTile(
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor:
                      k.farbe != null ? Color((k.farbe! & 0xFFFFFF) | 0xFF000000) : null,
                ),
                title: Text(k.istEigener ? 'Ruhepol' : k.name),
                subtitle: Text(k.herkunft),
                trailing: k.id == aktuell ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(k.id),
              ),
          ],
        ),
      ),
    );
    if (wahl != null) await dienst.zielSetzen(wahl);
  }
}
