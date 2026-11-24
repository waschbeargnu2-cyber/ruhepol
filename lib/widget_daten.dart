import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aufgaben_store.dart';
import 'datum.dart';
import 'design.dart';
import 'modelle.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Daten für das Homescreen-Widget.
// Nach jeder Änderung (1 Sekunde verzögert) bekommt das Widget eine kleine
// Zusammenfassung: Aufgaben bis morgen, Termine von heute und morgen,
// Anzahl heute erledigt und die Farben des aktuellen Farbschemas (hell und
// dunkel). Das Widget selbst steht in android/.../AgendaWidget.kt.
// ---------------------------------------------------------------------------

String tagSchluessel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, Object?> _palette(Color seed, Brightness helligkeit) {
  final s = ruhepolTheme(seed, helligkeit).colorScheme;
  final hell = helligkeit == Brightness.light;
  final hintergrund = Color.alphaBlend(
    s.primaryContainer.withValues(alpha: hell ? 0.55 : 0.40),
    s.surface,
  );
  return {
    'hintergrund': hintergrund.toARGB32(),
    'text': s.onSurface.toARGB32(),
    'text2': s.onSurfaceVariant.toARGB32(),
    'akzent': s.primary.toARGB32(),
    'akzentText': s.onPrimary.toARGB32(),
    'pill': s.surface.toARGB32(),
    'pillText': s.primary.toARGB32(),
    'prio': [for (final p in Prioritaet.values) prioFarbe(p, s).toARGB32()],
  };
}

/// Baut die Widget-Daten (reine Funktion, testbar).
Map<String, Object?> widgetDaten(AufgabenStore store, DateTime jetzt) {
  final h = nurDatum(jetzt);
  final morgen = plusTage(h, 1);

  final aufgaben = store.aufgaben
      .where((a) => !a.erledigt && a.faellig != null && !a.faellig!.isAfter(morgen))
      .toList()
    ..sort(AufgabenStore.sortierung);

  String info(Aufgabe a) {
    final teile = <String>[store.listeVon(a.listeId).name];
    if (a.frist != null) teile.add('Frist ${relativ(a.frist!, bezug: h)}');
    if (a.unteraufgaben.isNotEmpty) {
      teile.add('${a.unteraufgaben.where((u) => u.erledigt).length}/${a.unteraufgaben.length}');
    }
    return teile.join(' · ');
  }

  final termine = store.termine
      .where((t) => t.amTag(h) || t.amTag(morgen))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  final erledigtHeute =
      store.erledigtLog.where((e) => tageZwischen(h, e.zeit) == 0).length;

  return {
    'modus': switch (store.themeMode) {
      ThemeMode.light => 'hell',
      ThemeMode.dark => 'dunkel',
      _ => 'system',
    },
    'hell': _palette(store.seedFarbe, Brightness.light),
    'dunkel': _palette(store.seedFarbe, Brightness.dark),
    'aufgaben': [
      for (final a in aufgaben.take(30))
        {
          'id': a.id,
          'titel': a.titel,
          'faellig': tagSchluessel(a.faellig!),
          'uhrzeit': a.uhrzeit,
          'prio': a.prioritaet.index,
          'info': info(a),
        },
    ],
    'termine': [
      for (final t in termine.take(20))
        {
          'titel': t.titel,
          'start': t.start.millisecondsSinceEpoch,
          'ende': t.ende.millisecondsSinceEpoch,
          'ganztaegig': t.ganztaegig,
          'tag': tagSchluessel(t.start.isBefore(h) ? h : t.start),
        },
    ],
    'erledigtHeute': erledigtHeute,
    'erledigtAm': tagSchluessel(h),
  };
}

class WidgetDienst {
  WidgetDienst(this._store, {MethodChannel? kanal})
      : _kanal = kanal ?? const MethodChannel('ruhepol/kalender');

  final AufgabenStore _store;
  final MethodChannel _kanal;
  Timer? _timer;
  bool _aktiv = false;

  void starten() {
    if (_aktiv) return;
    _aktiv = true;
    _store.addListener(_geaendert);
    senden();
  }

  void _geaendert() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), senden);
  }

  Future<void> senden() async {
    try {
      final json = jsonEncode(widgetDaten(_store, DateTime.now()));
      await _kanal.invokeMethod<void>('widgetAktualisieren', {'json': json});
    } on MissingPluginException {
      // Kein Android
    } catch (e) {
      debugPrint('Widget konnte nicht aktualisiert werden: $e');
    }
  }
}
