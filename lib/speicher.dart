import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Speicherung
// Alle Daten liegen in EINER Datei (ruhepol_daten.json) im privaten Ordner der
// App auf dem Handy. Android sichert diesen Ordner automatisch mit, wenn die
// Google-Sicherung des Handys eingeschaltet ist.
// Geschrieben wird erst in eine .tmp-Datei und dann umbenannt. So bleibt die
// alte Datei heil, falls das Handy genau beim Speichern ausgeht.
// ---------------------------------------------------------------------------

abstract class Speicher {
  Future<Map<String, dynamic>?> laden();
  Future<void> speichern(Map<String, dynamic> daten);
}

class DateiSpeicher implements Speicher {
  Future<File> _datei() async {
    final ordner = await getApplicationSupportDirectory();
    return File('${ordner.path}${Platform.pathSeparator}ruhepol_daten.json');
  }

  @override
  Future<Map<String, dynamic>?> laden() async {
    final datei = await _datei();
    if (!await datei.exists()) return null;
    try {
      final inhalt = jsonDecode(await datei.readAsString());
      return Map<String, dynamic>.from(inhalt as Map);
    } catch (_) {
      // Datei kaputt: zur Sicherheit aufheben statt überschreiben.
      final stempel = DateTime.now().millisecondsSinceEpoch;
      await datei.rename('${datei.path}.defekt-$stempel');
      return null;
    }
  }

  @override
  Future<void> speichern(Map<String, dynamic> daten) async {
    final datei = await _datei();
    final tmp = File('${datei.path}.tmp');
    await tmp.writeAsString(jsonEncode(daten), flush: true);
    await tmp.rename(datei.path);
  }
}

/// Für Tests: speichert nur im Arbeitsspeicher.
class ArbeitsspeicherSpeicher implements Speicher {
  Map<String, dynamic>? daten;

  @override
  Future<Map<String, dynamic>?> laden() async => daten;

  @override
  Future<void> speichern(Map<String, dynamic> neu) async {
    daten = Map<String, dynamic>.from(jsonDecode(jsonEncode(neu)) as Map);
  }
}
