import 'package:flutter/material.dart';

void main() => runApp(const RuhepolApp());

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Farbschema
// Material 3 erzeugt aus EINER Grundfarbe ("seed") automatisch eine ganze,
// aufeinander abgestimmte Palette (Hintergründe, Buttons, Chips …) – für den
// hellen und den dunklen Modus.
// Eigene Farbe ergänzen: einfach eine weitere Zeile im enum hinzufügen,
// z. B.  rose('Rosé', Color(0xFFD99AAE)),
// ---------------------------------------------------------------------------
enum Pastell {
  salbei('Salbei', Color(0xFF7FA88C)),
  lavendel('Lavendel', Color(0xFF9C8FD6)),
  pfirsich('Pfirsich', Color(0xFFE8A07E)),
  himmel('Himmel', Color(0xFF7FA6CC));

  const Pastell(this.label, this.seed);
  final String label;
  final Color seed;
}

class RuhepolApp extends StatefulWidget {
  const RuhepolApp({super.key});

  @override
  State<RuhepolApp> createState() => _RuhepolAppState();
}

class _RuhepolAppState extends State<RuhepolApp> {
  Pastell _farbe = Pastell.salbei;

  ThemeData _theme(Brightness helligkeit) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _farbe.seed,
          brightness: helligkeit,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruhepol',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      // ThemeMode.system = folgt dem Hell/Dunkel-Modus deines Handys.
      themeMode: ThemeMode.system,
      home: Startseite(
        farbe: _farbe,
        onFarbeGeaendert: (f) => setState(() => _farbe = f),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Grundgerüst mit Navigationsleiste unten (wie in Googles Apps).
// Jede Seite ist ein eigenes Widget. Eine neue Seite ergänzen:
//   1. Widget schreiben, 2. in "seiten" eintragen, 3. NavigationDestination
//   in derselben Reihenfolge hinzufügen.
// ---------------------------------------------------------------------------
class Startseite extends StatefulWidget {
  const Startseite({
    super.key,
    required this.farbe,
    required this.onFarbeGeaendert,
  });

  final Pastell farbe;
  final ValueChanged<Pastell> onFarbeGeaendert;

  @override
  State<Startseite> createState() => _StartseiteState();
}

class _StartseiteState extends State<Startseite> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final seiten = <Widget>[
      const HeuteSeite(),
      const _Platzhalter(
        icon: Icons.checklist,
        titel: 'Listen',
        text: 'Hier erscheinen bald deine Listen und smarten Filter.',
      ),
      const _Platzhalter(
        icon: Icons.calendar_month,
        titel: 'Kalender',
        text: 'Hier erscheinen bald deine Google-Termine und freie Zeitfenster.',
      ),
      MehrSeite(farbe: widget.farbe, onFarbeGeaendert: widget.onFarbeGeaendert),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: seiten)),
      floatingActionButton: _tab == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aufgaben anlegen kommt in Version 0.2'),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Aufgabe'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Heute',
          ),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Listen'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Kalender',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Mehr'),
        ],
      ),
    );
  }
}

const _wochentage = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag',
];
const _monate = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

class HeuteSeite extends StatelessWidget {
  const HeuteSeite({super.key});

  @override
  Widget build(BuildContext context) {
    final jetzt = DateTime.now();
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final gruss = jetzt.hour < 11
        ? 'Guten Morgen'
        : jetzt.hour < 17
            ? 'Hallo'
            : 'Guten Abend';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          '${_wochentage[jetzt.weekday - 1]}, ${jetzt.day}. ${_monate[jetzt.month - 1]}',
          style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(gruss, style: text.headlineMedium),
        const SizedBox(height: 20),
        Card.filled(
          color: farben.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.spa, size: 40, color: farben.onPrimaryContainer),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Ruhepol läuft! Das ist Version 0.1 aus dem Cloud-Build.',
                    style: text.titleMedium
                        ?.copyWith(color: farben.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MehrSeite extends StatelessWidget {
  const MehrSeite({
    super.key,
    required this.farbe,
    required this.onFarbeGeaendert,
  });

  final Pastell farbe;
  final ValueChanged<Pastell> onFarbeGeaendert;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('Mehr', style: text.headlineMedium),
        const SizedBox(height: 24),
        Text('Farbschema', style: text.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in Pastell.values)
              ChoiceChip(
                label: Text(p.label),
                avatar: CircleAvatar(backgroundColor: p.seed),
                showCheckmark: false,
                selected: p == farbe,
                onSelected: (_) => onFarbeGeaendert(p),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('Version'),
          subtitle: Text('0.1 – Grundgerüst'),
        ),
      ],
    );
  }
}

class _Platzhalter extends StatelessWidget {
  const _Platzhalter({
    required this.icon,
    required this.titel,
    required this.text,
  });

  final IconData icon;
  final String titel;
  final String text;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: farben.primary),
            const SizedBox(height: 16),
            Text(titel, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: farben.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
