import 'dart:math';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Datenmodelle
// Hier ist festgelegt, WAS die App sich merkt. Jede Klasse kann sich in JSON
// (Text) umwandeln (toJson) und daraus wiederherstellen (fromJson). So wird
// alles in einer Datei auf dem Handy gespeichert.
// Neues Feld ergänzen: Feld + Konstruktor + toJson + fromJson anpassen.
// ---------------------------------------------------------------------------

enum Prioritaet {
  keine('Keine'),
  niedrig('Niedrig'),
  mittel('Mittel'),
  hoch('Hoch');

  const Prioritaet(this.label);
  final String label;
}

enum Intervall { tage, wochen, monate }

class Wiederholung {
  const Wiederholung({
    required this.art,
    this.anzahl = 1,
    this.abErledigung = false,
  });

  final Intervall art;
  final int anzahl;

  /// true = nächster Termin wird ab dem Erledigen gerechnet
  /// (z. B. „Pflanzen gießen 4 Tage nach dem letzten Mal“).
  final bool abErledigung;

  String get label {
    final basis = switch (art) {
      Intervall.tage => anzahl == 1 ? 'Täglich' : 'Alle $anzahl Tage',
      Intervall.wochen => anzahl == 1 ? 'Wöchentlich' : 'Alle $anzahl Wochen',
      Intervall.monate => anzahl == 1
          ? 'Monatlich'
          : anzahl == 12
              ? 'Jährlich'
              : 'Alle $anzahl Monate',
    };
    return abErledigung ? '$basis (ab Erledigen)' : basis;
  }

  DateTime naechstes(DateTime von) {
    switch (art) {
      case Intervall.tage:
        return DateTime(von.year, von.month, von.day + anzahl);
      case Intervall.wochen:
        return DateTime(von.year, von.month, von.day + 7 * anzahl);
      case Intervall.monate:
        final ziel = DateTime(von.year, von.month + anzahl, 1);
        final letzterTag = DateTime(ziel.year, ziel.month + 1, 0).day;
        return DateTime(ziel.year, ziel.month, min(von.day, letzterTag));
    }
  }

  Wiederholung mitAbErledigung(bool wert) =>
      Wiederholung(art: art, anzahl: anzahl, abErledigung: wert);

  Map<String, dynamic> toJson() => {
        'art': art.name,
        'anzahl': anzahl,
        'abErledigung': abErledigung,
      };

  factory Wiederholung.fromJson(Map<String, dynamic> j) => Wiederholung(
        art: Intervall.values.asNameMap()[j['art']] ?? Intervall.tage,
        anzahl: (j['anzahl'] as num?)?.toInt() ?? 1,
        abErledigung: j['abErledigung'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is Wiederholung &&
      other.art == art &&
      other.anzahl == anzahl &&
      other.abErledigung == abErledigung;

  @override
  int get hashCode => Object.hash(art, anzahl, abErledigung);
}

class Unteraufgabe {
  Unteraufgabe({required this.titel, this.erledigt = false});

  String titel;
  bool erledigt;

  Map<String, dynamic> toJson() => {'titel': titel, 'erledigt': erledigt};

  factory Unteraufgabe.fromJson(Map<String, dynamic> j) => Unteraufgabe(
        titel: j['titel'] as String? ?? '',
        erledigt: j['erledigt'] as bool? ?? false,
      );
}

class Aufgabe {
  Aufgabe({
    String? id,
    required this.titel,
    required this.listeId,
    this.notiz = '',
    this.faellig,
    this.uhrzeit,
    this.frist,
    this.prioritaet = Prioritaet.keine,
    List<Unteraufgabe>? unteraufgaben,
    this.wiederholung,
    this.erledigt = false,
    this.erledigtAm,
    DateTime? erstellt,
    this.kalenderEventId,
    this.kalenderStand,
  })  : id = id ?? neueId(),
        unteraufgaben = unteraufgaben ?? [],
        erstellt = erstellt ?? DateTime.now();

  final String id;
  String titel;
  String listeId;
  String notiz;

  /// Tag, an dem die Aufgabe erledigt werden soll (nur Datum, 00:00 Uhr).
  DateTime? faellig;

  /// Uhrzeit in Minuten seit Mitternacht (15:30 Uhr = 930).
  int? uhrzeit;

  /// Spätester Termin („bis spätestens“).
  DateTime? frist;

  Prioritaet prioritaet;
  List<Unteraufgabe> unteraufgaben;
  Wiederholung? wiederholung;
  bool erledigt;
  DateTime? erledigtAm;
  final DateTime erstellt;

  /// ID des zugehörigen Eintrags im Google Kalender (falls eingetragen).
  String? kalenderEventId;

  /// Fingerabdruck des zuletzt übertragenen Stands. Ändert er sich, wird
  /// der Kalendereintrag aktualisiert.
  String? kalenderStand;

  /// Nur Aufgaben mit Datum UND Uhrzeit kommen in den Kalender.
  bool get gehoertInKalender => faellig != null && uhrzeit != null;

  String get kalenderFingerabdruck =>
      '$titel|$notiz|${faellig?.toIso8601String()}|$uhrzeit|$erledigt';

  Map<String, dynamic> toJson() => {
        'id': id,
        'titel': titel,
        'listeId': listeId,
        'notiz': notiz,
        'faellig': faellig?.toIso8601String(),
        'uhrzeit': uhrzeit,
        'frist': frist?.toIso8601String(),
        'prioritaet': prioritaet.name,
        'unteraufgaben': [for (final u in unteraufgaben) u.toJson()],
        'wiederholung': wiederholung?.toJson(),
        'erledigt': erledigt,
        'erledigtAm': erledigtAm?.toIso8601String(),
        'erstellt': erstellt.toIso8601String(),
        'kalenderEventId': kalenderEventId,
        'kalenderStand': kalenderStand,
      };

  factory Aufgabe.fromJson(Map<String, dynamic> j) => Aufgabe(
        id: j['id'] as String?,
        titel: j['titel'] as String? ?? '',
        listeId: j['listeId'] as String? ?? 'privat',
        notiz: j['notiz'] as String? ?? '',
        faellig: _datum(j['faellig']),
        uhrzeit: (j['uhrzeit'] as num?)?.toInt(),
        frist: _datum(j['frist']),
        prioritaet:
            Prioritaet.values.asNameMap()[j['prioritaet']] ?? Prioritaet.keine,
        unteraufgaben: [
          for (final u in (j['unteraufgaben'] as List? ?? const []))
            Unteraufgabe.fromJson(Map<String, dynamic>.from(u as Map)),
        ],
        wiederholung: j['wiederholung'] == null
            ? null
            : Wiederholung.fromJson(
                Map<String, dynamic>.from(j['wiederholung'] as Map)),
        erledigt: j['erledigt'] as bool? ?? false,
        erledigtAm: _datum(j['erledigtAm']),
        erstellt: _datum(j['erstellt']),
        kalenderEventId: j['kalenderEventId'] as String?,
        kalenderStand: j['kalenderStand'] as String?,
      );
}

/// Ein Termin aus dem Google Kalender (nur zum Anzeigen).
class Termin {
  const Termin({
    required this.id,
    required this.titel,
    required this.start,
    required this.ende,
    required this.ganztaegig,
    required this.kalenderName,
    this.farbe,
    this.ort,
  });

  final String id;
  final String titel;
  final DateTime start;
  final DateTime ende;
  final bool ganztaegig;
  final String kalenderName;

  /// Farbe des Kalenders als 0xAARRGGBB (von Google).
  final int? farbe;
  final String? ort;

  /// Liegt der Termin (ganz oder teilweise) an diesem Tag?
  bool amTag(DateTime tag) {
    final anfang = DateTime(tag.year, tag.month, tag.day);
    final naechster = DateTime(tag.year, tag.month, tag.day + 1);
    final effektivesEnde = ende.isAfter(start) ? ende : start.add(const Duration(minutes: 1));
    return start.isBefore(naechster) && effektivesEnde.isAfter(anfang);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titel': titel,
        'start': start.toIso8601String(),
        'ende': ende.toIso8601String(),
        'ganztaegig': ganztaegig,
        'kalenderName': kalenderName,
        'farbe': farbe,
        'ort': ort,
      };

  factory Termin.fromJson(Map<String, dynamic> j) => Termin(
        id: j['id'] as String? ?? '',
        titel: j['titel'] as String? ?? '',
        start: _datum(j['start']) ?? DateTime.now(),
        ende: _datum(j['ende']) ?? DateTime.now(),
        ganztaegig: j['ganztaegig'] as bool? ?? false,
        kalenderName: j['kalenderName'] as String? ?? '',
        farbe: (j['farbe'] as num?)?.toInt(),
        ort: j['ort'] as String?,
      );
}

class Liste {
  Liste({
    String? id,
    required this.name,
    required this.farbe,
    required this.icon,
  }) : id = id ?? neueId();

  final String id;
  String name;

  /// Index in `listenFarben` (design.dart).
  int farbe;

  /// Schlüssel in `listenIcons` (design.dart).
  String icon;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'farbe': farbe, 'icon': icon};

  factory Liste.fromJson(Map<String, dynamic> j) => Liste(
        id: j['id'] as String?,
        name: j['name'] as String? ?? 'Liste',
        farbe: (j['farbe'] as num?)?.toInt() ?? 0,
        icon: j['icon'] as String? ?? 'liste',
      );
}

DateTime? _datum(Object? wert) =>
    wert is String ? DateTime.tryParse(wert) : null;

final _zufall = Random();

String neueId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    _zufall.nextInt(1 << 20).toRadixString(36);
