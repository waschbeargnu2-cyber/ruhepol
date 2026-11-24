import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../design.dart';
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
          leading: Icon(Icons.event_available),
          title: Text('Google Kalender'),
          subtitle: Text('Termine anzeigen und Aufgaben eintragen'),
        ),
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
          subtitle: Text('0.2'),
        ),
      ],
    );
  }
}
