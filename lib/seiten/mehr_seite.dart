import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../google_kalender.dart';
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

        const Abschnitt('Google Kalender'),
        const _GoogleKarte(),

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

class _GoogleKarte extends StatelessWidget {
  const _GoogleKarte();

  @override
  Widget build(BuildContext context) {
    final dienst = KalenderScope.of(context);
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final inhalt = <Widget>[];
    switch (dienst.status) {
      case KalenderStatus.nichtEingerichtet:
        inhalt.add(Text(
          'Noch nicht eingerichtet. Die Anleitung steht im Projekt unter '
          'docs/GOOGLE_EINRICHTUNG.md.',
          style: text.bodyMedium,
        ));
      case KalenderStatus.getrennt:
      case KalenderStatus.verbinde:
        inhalt
          ..add(Text(
            'Verbinde dein Google-Konto: Deine Termine erscheinen dann in Ruhepol, '
            'und Aufgaben mit Datum und Uhrzeit landen im Kalender „Ruhepol“.',
            style: text.bodyMedium,
          ))
          ..add(const SizedBox(height: 12))
          ..add(FilledButton.icon(
            onPressed: dienst.status == KalenderStatus.verbinde ? null : dienst.verbinden,
            icon: dienst.status == KalenderStatus.verbinde
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Mit Google verbinden'),
          ));
      case KalenderStatus.verbunden:
        final stand = store.termineStand;
        inhalt
          ..add(Row(
            children: [
              Icon(Icons.check_circle, color: farben.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(dienst.email ?? 'Verbunden', style: text.titleSmall),
              ),
            ],
          ))
          ..add(const SizedBox(height: 8))
          ..add(Text(
            '${store.termine.length} Termine geladen'
            '${stand != null ? ' (Stand ${uhrzeitText(stand.hour * 60 + stand.minute)} Uhr)' : ''}. '
            'Aufgaben mit Datum und Uhrzeit landen im Kalender „Ruhepol“. '
            'Deine anderen Kalender werden nur gelesen.',
            style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
          ))
          ..add(const SizedBox(height: 12))
          ..add(Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: dienst.laedt ? null : dienst.aktualisieren,
                icon: const Icon(Icons.refresh),
                label: const Text('Aktualisieren'),
              ),
              TextButton(
                onPressed: dienst.trennen,
                child: const Text('Trennen'),
              ),
            ],
          ));
    }
    if (dienst.fehler != null) {
      inhalt
        ..add(const SizedBox(height: 10))
        ..add(Text(dienst.fehler!, style: text.bodySmall?.copyWith(color: farben.error)));
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
}
