import 'package:flutter/material.dart';

import 'datum.dart';
import 'modelle.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Erfolge – ein bisschen Spiel, damit Abhaken Spaß macht.
//   Punkte (XP) je erledigter Aufgabe:
//     10 Grundpunkte + Priorität (niedrig 3, mittel 6, hoch 10)
//     + 5 Bonus, wenn pünktlich erledigt
//   Level: Level n braucht insgesamt 25·n·(n−1) Punkte (0, 50, 150, 300 …)
//   Serie: Tage am Stück mit mindestens einer erledigten Aufgabe
//   Abzeichen: siehe `alleAbzeichen()` – eigene einfach dort ergänzen.
// Alles wird aus dem Erledigt-Protokoll berechnet (aufgaben_store.dart).
// ---------------------------------------------------------------------------

int punkteFuer(ErledigtEintrag e) {
  final prio = switch (e.prioritaet) {
    Prioritaet.keine => 0,
    Prioritaet.niedrig => 3,
    Prioritaet.mittel => 6,
    Prioritaet.hoch => 10,
  };
  return 10 + prio + (e.puenktlich ? 5 : 0);
}

int punkteFuerLevel(int level) => 25 * level * (level - 1);

const _levelNamen = [
  'Neuling',
  'Anpacker',
  'Macher',
  'Abhak-Profi',
  'Organisationstalent',
  'Fristenbändiger',
  'Listen-Meister',
  'Produktivitäts-Ass',
  'Agenda-Legende',
];

String levelName(int level) => _levelNamen[(level - 1).clamp(0, _levelNamen.length - 1)];

class Abzeichen {
  const Abzeichen({
    required this.titel,
    required this.beschreibung,
    required this.icon,
    required this.stand,
    required this.ziel,
  });

  final String titel;
  final String beschreibung;
  final IconData icon;
  final int stand;
  final int ziel;

  bool get erreicht => stand >= ziel;
  double get fortschritt => ziel == 0 ? 1 : (stand / ziel).clamp(0, 1).toDouble();
}

class Erfolge {
  Erfolge._({
    required this.punkte,
    required this.level,
    required this.punkteImLevel,
    required this.punkteBisNaechstes,
    required this.gesamt,
    required this.heute,
    required this.dieseWoche,
    required this.serie,
    required this.laengsteSerie,
    required this.letzte7Tage,
    required this.besterTag,
    required this.abzeichen,
  });

  final int punkte;
  final int level;
  final int punkteImLevel;
  final int punkteBisNaechstes;
  final int gesamt;
  final int heute;
  final int dieseWoche;
  final int serie;
  final int laengsteSerie;

  /// Erledigte Aufgaben der letzten 7 Tage, ältester Tag zuerst.
  final List<int> letzte7Tage;
  final int besterTag;
  final List<Abzeichen> abzeichen;

  String get levelTitel => levelName(level);

  double get levelFortschritt {
    final spanne = punkteFuerLevel(level + 1) - punkteFuerLevel(level);
    return spanne == 0 ? 0 : (punkteImLevel / spanne).clamp(0, 1).toDouble();
  }

  factory Erfolge.berechnen(List<ErledigtEintrag> log, DateTime jetzt) {
    final h = nurDatum(jetzt);
    final punkte = log.fold<int>(0, (s, e) => s + punkteFuer(e));

    var level = 1;
    while (punkte >= punkteFuerLevel(level + 1)) {
      level++;
    }

    // Erledigte pro Tag
    final proTag = <DateTime, int>{};
    for (final e in log) {
      final t = nurDatum(e.zeit);
      proTag[t] = (proTag[t] ?? 0) + 1;
    }
    final letzte7 = [for (var i = 6; i >= 0; i--) proTag[plusTage(h, -i)] ?? 0];
    final montag = plusTage(h, -(h.weekday - 1));
    final dieseWoche = log.where((e) => !nurDatum(e.zeit).isBefore(montag)).length;

    // Serien
    var serie = 0;
    var tag = (proTag[h] ?? 0) > 0 ? h : plusTage(h, -1);
    while ((proTag[tag] ?? 0) > 0) {
      serie++;
      tag = plusTage(tag, -1);
    }
    final tage = proTag.keys.toList()..sort();
    var laengste = 0;
    var aktuell = 0;
    DateTime? vorher;
    for (final t in tage) {
      aktuell = (vorher != null && tageZwischen(vorher, t) == 1) ? aktuell + 1 : 1;
      if (aktuell > laengste) laengste = aktuell;
      vorher = t;
    }
    final besterTag = proTag.values.fold<int>(0, (m, v) => v > m ? v : m);

    return Erfolge._(
      punkte: punkte,
      level: level,
      punkteImLevel: punkte - punkteFuerLevel(level),
      punkteBisNaechstes: punkteFuerLevel(level + 1) - punkte,
      gesamt: log.length,
      heute: proTag[h] ?? 0,
      dieseWoche: dieseWoche,
      serie: serie,
      laengsteSerie: laengste,
      letzte7Tage: letzte7,
      besterTag: besterTag,
      abzeichen: alleAbzeichen(log, laengste, besterTag),
    );
  }
}

/// Alle Abzeichen mit aktuellem Stand.
List<Abzeichen> alleAbzeichen(List<ErledigtEintrag> log, int laengsteSerie, int besterTag) {
  final n = log.length;
  final frueh = log.where((e) => e.zeit.hour < 8).length;
  final spaet = log.where((e) => e.zeit.hour >= 22).length;
  final fristen = log.where((e) => e.mitFrist && e.puenktlich).length;
  final wichtig = log.where((e) => e.prioritaet == Prioritaet.hoch).length;
  final listen = log.map((e) => e.listeId).toSet().length;
  final wochenende = log.where((e) => e.zeit.weekday >= 6).length;

  return [
    Abzeichen(titel: 'Erster Haken', beschreibung: 'Die erste Aufgabe erledigt',
        icon: Icons.check_circle, stand: n, ziel: 1),
    Abzeichen(titel: 'Zehnerpack', beschreibung: '10 Aufgaben erledigt',
        icon: Icons.filter_9_plus, stand: n, ziel: 10),
    Abzeichen(titel: 'Halbes Hundert', beschreibung: '50 Aufgaben erledigt',
        icon: Icons.military_tech, stand: n, ziel: 50),
    Abzeichen(titel: 'Hunderter', beschreibung: '100 Aufgaben erledigt',
        icon: Icons.emoji_events, stand: n, ziel: 100),
    Abzeichen(titel: 'Drei am Stück', beschreibung: '3 Tage in Folge etwas geschafft',
        icon: Icons.local_fire_department, stand: laengsteSerie, ziel: 3),
    Abzeichen(titel: 'Wochenserie', beschreibung: '7 Tage in Folge etwas geschafft',
        icon: Icons.whatshot, stand: laengsteSerie, ziel: 7),
    Abzeichen(titel: 'Produktiver Tag', beschreibung: '10 Aufgaben an einem Tag',
        icon: Icons.bolt, stand: besterTag, ziel: 10),
    Abzeichen(titel: 'Fristenheld', beschreibung: '5 Aufgaben vor der Frist erledigt',
        icon: Icons.flag, stand: fristen, ziel: 5),
    Abzeichen(titel: 'Wichtiges zuerst', beschreibung: '10 Aufgaben mit hoher Priorität',
        icon: Icons.priority_high, stand: wichtig, ziel: 10),
    Abzeichen(titel: 'Frühaufsteher', beschreibung: 'Vor 8 Uhr etwas abgehakt',
        icon: Icons.wb_twilight, stand: frueh, ziel: 1),
    Abzeichen(titel: 'Nachteule', beschreibung: 'Nach 22 Uhr etwas abgehakt',
        icon: Icons.nightlight_round, stand: spaet, ziel: 1),
    Abzeichen(titel: 'Vielseitig', beschreibung: 'In 5 verschiedenen Listen erledigt',
        icon: Icons.dashboard_customize, stand: listen, ziel: 5),
    Abzeichen(titel: 'Wochenend-Held', beschreibung: '10 Aufgaben am Wochenende',
        icon: Icons.weekend, stand: wochenende, ziel: 10),
  ];
}
