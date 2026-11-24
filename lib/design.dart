import 'package:flutter/material.dart';

import 'modelle.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Farben und Symbole
// Material 3 erzeugt aus EINER Grundfarbe („seed“) automatisch eine ganze,
// abgestimmte Palette, hell und dunkel.
// Eigene App-Farbe: im enum Pastell eine Zeile ergänzen,
//   z. B.  rose('Rosé', Color(0xFFD99AAE)),
// Eigene Listenfarbe: in `listenFarben` eine Farbe ergänzen.
// Eigenes Listensymbol: in `listenIcons` einen Eintrag ergänzen
//   (Symbolnamen: https://fonts.google.com/icons).
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

const listenFarben = <Color>[
  Color(0xFF9C8FD6), // Lavendel
  Color(0xFF7FA6CC), // Himmel
  Color(0xFFE3C565), // Butter
  Color(0xFF7FA88C), // Salbei
  Color(0xFFE8A07E), // Pfirsich
  Color(0xFFD99AAE), // Rosé
  Color(0xFF7CC4C0), // Mint
  Color(0xFFB5A58F), // Sand
];

const listenIcons = <String, IconData>{
  'herz': Icons.favorite,
  'arbeit': Icons.work,
  'haus': Icons.home,
  'gesundheit': Icons.spa,
  'einkauf': Icons.shopping_basket,
  'schule': Icons.school,
  'sport': Icons.fitness_center,
  'reise': Icons.flight,
  'geld': Icons.savings,
  'idee': Icons.lightbulb,
  'familie': Icons.family_restroom,
  'liste': Icons.checklist,
};

IconData iconFuer(String schluessel) => listenIcons[schluessel] ?? Icons.checklist;

class ListenFarbe {
  const ListenFarbe(this.hintergrund, this.vordergrund);
  final Color hintergrund;
  final Color vordergrund;
}

final _farbCache = <(int, Brightness), ListenFarbe>{};

/// Pastell-Hintergrund und gut lesbare Schriftfarbe für eine Liste.
ListenFarbe listenFarbe(int index, Brightness helligkeit) {
  final i = index.abs() % listenFarben.length;
  return _farbCache.putIfAbsent((i, helligkeit), () {
    final s = ColorScheme.fromSeed(
      seedColor: listenFarben[i],
      brightness: helligkeit,
    );
    return ListenFarbe(s.primaryContainer, s.onPrimaryContainer);
  });
}

/// Farbe des Abhak-Kreises je nach Priorität.
Color prioFarbe(Prioritaet p, ColorScheme farben) {
  final dunkel = farben.brightness == Brightness.dark;
  return switch (p) {
    Prioritaet.hoch => dunkel ? const Color(0xFFF08CA2) : const Color(0xFFC24F69),
    Prioritaet.mittel => dunkel ? const Color(0xFFE5B462) : const Color(0xFFAE7316),
    Prioritaet.niedrig => farben.primary,
    Prioritaet.keine => farben.outline,
  };
}

ThemeData ruhepolTheme(Pastell farbe, Brightness helligkeit) {
  final schema = ColorScheme.fromSeed(
    seedColor: farbe.seed,
    brightness: helligkeit,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
