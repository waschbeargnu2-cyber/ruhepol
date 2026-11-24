import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/neue_aufgabe.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Aktionen, mit denen die App geöffnet wird.
//   • „Teilen → Agenda“ aus einer anderen App: Text wird zur neuen Aufgabe
//   • Langer Druck auf das App-Symbol → „Neue Aufgabe“
//   • „+“ im Widget
// Android (MainActivity.kt) meldet die Aktion. Hier öffnet sich dann das
// Fenster „Neue Aufgabe“, beim Teilen schon mit dem geteilten Text.
// ---------------------------------------------------------------------------

class AppAktionen {
  AppAktionen(this._navigator, {MethodChannel? kanal})
      : _kanal = kanal ?? const MethodChannel('ruhepol/kalender');

  final GlobalKey<NavigatorState> _navigator;
  final MethodChannel _kanal;

  /// Einmal nach dem ersten Bild aufrufen.
  Future<void> starten() async {
    _kanal.setMethodCallHandler((call) async {
      if (call.method == 'aktion') {
        _ausfuehren(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return null;
    });
    try {
      final aktion = await _kanal.invokeMapMethod<Object?, Object?>('startAktion');
      if (aktion != null) _ausfuehren(aktion);
    } on MissingPluginException {
      // Kein Android
    }
  }

  void _ausfuehren(Map<Object?, Object?> aktion) {
    final kontext = _navigator.currentState?.overlay?.context;
    if (kontext == null) return;
    switch (aktion['aktion']) {
      case 'neu':
        zeigeNeueAufgabe(kontext);
      case 'teilen':
        final (vorgabe, notiz) = geteiltenTextAufteilen(
          aktion['text'] as String? ?? '',
          betreff: aktion['betreff'] as String?,
        );
        zeigeNeueAufgabe(kontext, vorgabe: vorgabe, notiz: notiz);
    }
  }
}

/// Macht aus geteiltem Text einen Titel (erste Zeile, max. 80 Zeichen)
/// und eine Notiz (der ganze Text, wenn er länger ist).
(String, String?) geteiltenTextAufteilen(String text, {String? betreff}) {
  final sauber = text.trim();
  final b = betreff?.trim();
  final ersteZeile = sauber.split('\n').map((z) => z.trim()).firstWhere(
        (z) => z.isNotEmpty,
        orElse: () => '',
      );
  var titel = (b != null && b.isNotEmpty) ? b : ersteZeile;
  if (titel.length > 80) titel = '${titel.substring(0, 77).trimRight()}…';
  final brauchtNotiz = sauber.isNotEmpty && sauber != titel;
  return (titel, brauchtNotiz ? sauber : null);
}
