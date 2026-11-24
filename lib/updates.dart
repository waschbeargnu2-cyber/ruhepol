import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Updates direkt in der App.
// Beim Start (höchstens alle 6 Stunden) fragt die App bei GitHub nach dem
// neuesten Build. Ist er neuer als die installierte Version, erscheint auf
// „Heute“ ein Hinweis. „Aktualisieren“ lädt die APK und öffnet den Installer.
// Der Android-Teil steht in Aktualisierung.kt.
// ---------------------------------------------------------------------------

class UpdateInfo {
  const UpdateInfo({
    required this.build,
    required this.name,
    required this.notiz,
    required this.url,
    required this.groesse,
  });

  final int build;
  final String name;
  final String notiz;
  final String url;
  final int groesse;

  String get groesseText => '${(groesse / 1048576).toStringAsFixed(1).replaceAll('.', ',')} MB';
}

enum UpdateStatus { unbekannt, pruefe, aktuell, verfuegbar, laedt, fehler }

class UpdateDienst extends ChangeNotifier {
  UpdateDienst({MethodChannel? kanal})
      : _kanal = kanal ?? const MethodChannel('ruhepol/kalender');

  final MethodChannel _kanal;

  String? version;
  int? build;
  UpdateInfo? neu;
  UpdateStatus status = UpdateStatus.unbekannt;
  String? fehler;
  DateTime? _geprueft;

  bool get verfuegbar => neu != null && build != null && neu!.build > build!;

  String get versionText =>
      version == null ? 'unbekannt' : '$version${build != null ? ' (Build $build)' : ''}';

  Future<void> starten() async {
    try {
      final v = await _kanal.invokeMapMethod<String, Object?>('appVersion');
      version = v?['name'] as String?;
      build = (v?['build'] as num?)?.toInt();
    } on MissingPluginException {
      return; // kein Android (z. B. in Tests)
    } catch (_) {
      // Version unbekannt: Updates trotzdem prüfen
    }
    notifyListeners();
    await pruefen(still: true);
  }

  /// [still]: beim automatischen Prüfen keine Fehlermeldung zeigen und
  /// höchstens alle 6 Stunden nachfragen.
  Future<void> pruefen({bool still = false}) async {
    final zuletzt = _geprueft;
    if (still && zuletzt != null && DateTime.now().difference(zuletzt) < const Duration(hours: 6)) {
      return;
    }
    status = UpdateStatus.pruefe;
    fehler = null;
    notifyListeners();
    try {
      final m = await _kanal.invokeMapMethod<String, Object?>('updatePruefen');
      if (m != null) {
        neu = UpdateInfo(
          build: (m['build'] as num?)?.toInt() ?? 0,
          name: m['name'] as String? ?? '',
          notiz: m['notiz'] as String? ?? '',
          url: m['url'] as String? ?? '',
          groesse: (m['groesse'] as num?)?.toInt() ?? 0,
        );
      }
      _geprueft = DateTime.now();
      status = verfuegbar ? UpdateStatus.verfuegbar : UpdateStatus.aktuell;
    } on MissingPluginException {
      status = UpdateStatus.unbekannt;
    } on PlatformException catch (e) {
      status = UpdateStatus.fehler;
      fehler = still ? null : 'Keine Verbindung zu GitHub (${e.message ?? e.code}).';
    }
    notifyListeners();
  }

  Future<void> installieren() async {
    final n = neu;
    if (n == null || n.url.isEmpty) return;
    status = UpdateStatus.laedt;
    fehler = null;
    notifyListeners();
    try {
      final r = await _kanal.invokeMethod<String>('updateInstallieren', {'url': n.url});
      if (r == 'erlaubnis') {
        fehler = 'Erlaube „Agenda“ einmalig, Apps zu installieren (Schalter im '
            'geöffneten Fenster), komm zurück und tippe erneut auf „Aktualisieren“.';
      }
    } on PlatformException catch (e) {
      fehler = 'Download fehlgeschlagen (${e.message ?? e.code}).';
    }
    status = UpdateStatus.verfuegbar;
    notifyListeners();
  }
}

class UpdateScope extends InheritedNotifier<UpdateDienst> {
  const UpdateScope({
    super.key,
    required UpdateDienst dienst,
    required super.child,
  }) : super(notifier: dienst);

  static UpdateDienst of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UpdateScope>()!.notifier!;
}
