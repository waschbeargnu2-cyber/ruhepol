import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'aufgaben_store.dart';
import 'design.dart';
import 'google_kalender.dart';
import 'seiten/heute_seite.dart';
import 'seiten/kalender_seite.dart';
import 'seiten/listen_seite.dart';
import 'seiten/mehr_seite.dart';
import 'speicher.dart';
import 'widgets/neue_aufgabe.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Aufbau der App
//   main.dart            Start, Farben, Navigationsleiste
//   aufgaben_store.dart  Gedächtnis der App (alle Änderungen laufen hier durch)
//   modelle.dart         Aufgabe, Liste, Wiederholung …
//   speicher.dart        Speichern auf dem Handy
//   eingabe_parser.dart  Erkennung von „morgen 15 Uhr #Liste !!“
//   google_kalender.dart Anmeldung bei Google, Termine lesen/schreiben
//   konfiguration.dart   Google-Client-ID und Kalender-Einstellungen
//   design.dart          Farben und Symbole
//   seiten/              Heute, Listen, Kalender, Mehr
//   widgets/             Bausteine (Aufgaben-Kachel, Fenster …)
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AufgabenStore(DateiSpeicher());
  await store.laden();
  final kalender = KalenderDienst(store);
  runApp(RuhepolApp(store: store, kalender: kalender));
  // Google im Hintergrund verbinden, damit der Start nicht wartet.
  unawaited(kalender.starten());
}

class RuhepolApp extends StatefulWidget {
  const RuhepolApp({super.key, required this.store, required this.kalender});

  final AufgabenStore store;
  final KalenderDienst kalender;

  @override
  State<RuhepolApp> createState() => _RuhepolAppState();
}

class _RuhepolAppState extends State<RuhepolApp> {
  late final AppLifecycleListener _lebenszyklus;

  @override
  void initState() {
    super.initState();
    // Speichert sofort, wenn die App in den Hintergrund geht.
    _lebenszyklus = AppLifecycleListener(
      onHide: widget.store.sofortSpeichern,
      onPause: widget.store.sofortSpeichern,
      // Beim Zurückkehren in die App Termine auffrischen (höchstens alle 2 Min.)
      onResume: () => widget.kalender.aktualisierenFallsAlt(),
    );
  }

  @override
  void dispose() {
    _lebenszyklus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return StoreScope(
      store: store,
      child: KalenderScope(
        dienst: widget.kalender,
        child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'Ruhepol',
          debugShowCheckedModeBanner: false,
          theme: ruhepolTheme(store.farbe, Brightness.light),
          darkTheme: ruhepolTheme(store.farbe, Brightness.dark),
          themeMode: store.themeMode,
          locale: const Locale('de'),
          supportedLocales: const [Locale('de')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Startseite(),
        ),
        ),
      ),
    );
  }
}

class Startseite extends StatefulWidget {
  const Startseite({super.key});

  @override
  State<Startseite> createState() => _StartseiteState();
}

class _StartseiteState extends State<Startseite> {
  int _tab = 0;

  static const _seiten = <Widget>[
    HeuteSeite(),
    ListenSeite(),
    KalenderSeite(),
    MehrSeite(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: _seiten)),
      floatingActionButton: _tab == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () => zeigeNeueAufgabe(context),
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
