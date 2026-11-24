import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_aktionen.dart';
import 'aufgaben_store.dart';
import 'design.dart';
import 'erinnerungen.dart';
import 'handy_kalender.dart';
import 'seiten/erfolge_seite.dart';
import 'seiten/heute_seite.dart';
import 'seiten/kalender_seite.dart';
import 'seiten/listen_seite.dart';
import 'seiten/mehr_seite.dart';
import 'speicher.dart';
import 'updates.dart';
import 'widget_daten.dart';
import 'widgets/neue_aufgabe.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Aufbau der App „Agenda“
//   main.dart            Start, Farben, Navigationsleiste
//   aufgaben_store.dart  Gedächtnis der App (alle Änderungen laufen hier durch)
//   modelle.dart         Aufgabe, Liste, Wiederholung, Erledigt-Protokoll …
//   speicher.dart        Speichern auf dem Handy
//   eingabe_parser.dart  Erkennung von „morgen 15 Uhr #Liste !!“
//   handy_kalender.dart  Kalender des Handys lesen/schreiben (Google, Samsung …)
//   erinnerungen.dart    Wann woran erinnert wird (Android stellt die Wecker)
//   erfolge.dart         Punkte, Level, Serien und Abzeichen
//   widget_daten.dart    Daten für das Homescreen-Widget
//   updates.dart         Neue Versionen von GitHub holen
//   app_aktionen.dart    Teilen, Kurzbefehl und Widget-„+“
//   konfiguration.dart   Kalender-Einstellungen (Name, Farbe, Dauer)
//   design.dart          Farben und Symbole
//   seiten/              Heute, Listen (+ Matrix), Kalender, Erfolge, Mehr
//   widgets/             Bausteine (Aufgaben-Kachel, Fenster …)
// Android-Teile: android/app/src/main/kotlin/app/ruhepol/ruhepol/
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AufgabenStore(DateiSpeicher());
  await store.laden();
  final kalender = KalenderDienst(store);
  final erinnerungen = ErinnerungsDienst(store);
  final updates = UpdateDienst();
  runApp(RuhepolApp(
    store: store,
    kalender: kalender,
    erinnerungen: erinnerungen,
    updates: updates,
    plattform: true,
  ));
  // Alles Weitere im Hintergrund, damit der Start nicht wartet.
  unawaited(systemFarbeLaden(store));
  unawaited(kalender.starten());
  unawaited(erinnerungen.starten());
  unawaited(updates.starten());
  WidgetDienst(store).starten();
}

/// Material You: Akzentfarbe des Hintergrundbilds abfragen (ab Android 12).
Future<void> systemFarbeLaden(AufgabenStore store) async {
  try {
    final wert = await const MethodChannel('ruhepol/kalender').invokeMethod<int>('systemFarbe');
    store.systemFarbeSetzen(wert == null ? null : Color(wert & 0xFFFFFFFF));
  } catch (_) {
    // Kein Android oder zu alt: Pastell-Schema bleibt.
  }
}

class RuhepolApp extends StatefulWidget {
  const RuhepolApp({
    super.key,
    required this.store,
    required this.kalender,
    required this.erinnerungen,
    this.updates,
    this.plattform = false,
  });

  final AufgabenStore store;
  final KalenderDienst kalender;
  final ErinnerungsDienst erinnerungen;
  final UpdateDienst? updates;

  /// true = echte App auf Android (in Tests false).
  final bool plattform;

  @override
  State<RuhepolApp> createState() => _RuhepolAppState();
}

class _RuhepolAppState extends State<RuhepolApp> {
  late final AppLifecycleListener _lebenszyklus;
  late final UpdateDienst _updates = widget.updates ?? UpdateDienst();
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _lebenszyklus = AppLifecycleListener(
      // Speichert sofort, wenn die App in den Hintergrund geht.
      onHide: widget.store.sofortSpeichern,
      onPause: widget.store.sofortSpeichern,
      // Beim Zurückkehren: Termine auffrischen, per Benachrichtigung oder
      // Widget erledigte Aufgaben übernehmen, nach Updates schauen.
      onResume: () {
        widget.kalender.aktualisierenFallsAlt();
        widget.erinnerungen.starten();
        _updates.pruefen(still: true);
        if (widget.plattform) systemFarbeLaden(widget.store);
      },
    );
    if (widget.plattform) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppAktionen(_navigator).starten();
      });
    }
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
        child: ErinnerungsScope(
          dienst: widget.erinnerungen,
          child: UpdateScope(
            dienst: _updates,
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => MaterialApp(
                title: 'Agenda',
                navigatorKey: _navigator,
                debugShowCheckedModeBanner: false,
                theme: ruhepolTheme(store.seedFarbe, Brightness.light),
                darkTheme: ruhepolTheme(store.seedFarbe, Brightness.dark),
                themeMode: store.themeMode,
                locale: const Locale('de'),
                supportedLocales: const [Locale('de')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: const Startseite(),
              ),
            ),
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
    ErfolgeSeite(),
    MehrSeite(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: _seiten)),
      floatingActionButton: _tab >= 3
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
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Erfolge',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Mehr'),
        ],
      ),
    );
  }
}
