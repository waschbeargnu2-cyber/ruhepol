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
    this.erinnern = true,
    this.dauer,
  })  : id = id ?? neueId(),
        unteraufgaben = unteraufgaben ?? [],
        erstellt = erstellt ?? DateTime.now();

  /// Geschätzte Dauer in Minuten (null = keine Angabe, zählt als 30 Min.).
  int? dauer;

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

  /// ID des zugehörigen Eintrags im Handy-Kalender (falls eingetragen).
  String? kalenderEventId;

  /// Fingerabdruck des zuletzt übertragenen Stands. Ändert er sich, wird
  /// der Kalendereintrag aktualisiert.
  String? kalenderStand;

  /// Soll Agenda an diese Aufgabe erinnern?
  bool erinnern;

  /// Nur Aufgaben mit Datum UND Uhrzeit kommen in den Kalender.
  bool get gehoertInKalender => faellig != null && uhrzeit != null;

  String get kalenderFingerabdruck =>
      '$titel|$notiz|${faellig?.toIso8601String()}|$uhrzeit|$erledigt|$dauer';

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
        'erinnern': erinnern,
        'dauer': dauer,
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
        erinnern: j['erinnern'] as bool? ?? true,
        dauer: (j['dauer'] as num?)?.toInt(),
      );
}

/// Eine Notiz: Text und/oder Checkliste, mit beliebig vielen Aufgaben
/// verknüpfbar (die Verknüpfung steht in [aufgabenIds]).
class Notiz {
  Notiz({
    String? id,
    this.titel = '',
    this.inhalt = '',
    List<Unteraufgabe>? checkliste,
    this.farbe = 0,
    this.angeheftet = false,
    List<String>? aufgabenIds,
    DateTime? erstellt,
    DateTime? geaendert,
  })  : id = id ?? neueId(),
        checkliste = checkliste ?? [],
        aufgabenIds = aufgabenIds ?? [],
        erstellt = erstellt ?? DateTime.now(),
        geaendert = geaendert ?? DateTime.now();

  final String id;
  String titel;
  String inhalt;
  List<Unteraufgabe> checkliste;

  /// Index in `listenFarben` (design.dart).
  int farbe;
  bool angeheftet;
  List<String> aufgabenIds;
  final DateTime erstellt;
  DateTime geaendert;

  bool get istLeer =>
      titel.trim().isEmpty && inhalt.trim().isEmpty && checkliste.isEmpty;

  String get anzeigeTitel {
    if (titel.trim().isNotEmpty) return titel.trim();
    final erste = inhalt.trim().split('\n').first.trim();
    if (erste.isNotEmpty) return erste;
    if (checkliste.isNotEmpty) return checkliste.first.titel;
    return 'Leere Notiz';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titel': titel,
        'inhalt': inhalt,
        'checkliste': [for (final c in checkliste) c.toJson()],
        'farbe': farbe,
        'angeheftet': angeheftet,
        'aufgabenIds': aufgabenIds,
        'erstellt': erstellt.toIso8601String(),
        'geaendert': geaendert.toIso8601String(),
      };

  factory Notiz.fromJson(Map<String, dynamic> j) => Notiz(
        id: j['id'] as String?,
        titel: j['titel'] as String? ?? '',
        inhalt: j['inhalt'] as String? ?? '',
        checkliste: [
          for (final c in (j['checkliste'] as List? ?? const []))
            Unteraufgabe.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
        farbe: (j['farbe'] as num?)?.toInt() ?? 0,
        angeheftet: j['angeheftet'] as bool? ?? false,
        aufgabenIds: [for (final a in (j['aufgabenIds'] as List? ?? const [])) a as String],
        erstellt: _datum(j['erstellt']),
        geaendert: _datum(j['geaendert']),
      );
}

/// Eine gespeicherte Vorlage für wiederkehrende Aufgaben (z. B. „Wocheneinkauf“).
class Vorlage {
  Vorlage({
    String? id,
    required this.titel,
    required this.listeId,
    this.prioritaet = Prioritaet.keine,
    this.dauer,
    List<String>? unteraufgaben,
    this.notiz = '',
    this.wiederholung,
  })  : id = id ?? neueId(),
        unteraufgaben = unteraufgaben ?? [];

  factory Vorlage.aus(Aufgabe a) => Vorlage(
        titel: a.titel.trim(),
        listeId: a.listeId,
        prioritaet: a.prioritaet,
        dauer: a.dauer,
        unteraufgaben: [for (final u in a.unteraufgaben) u.titel],
        notiz: a.notiz,
        wiederholung: a.wiederholung,
      );

  final String id;
  String titel;
  String listeId;
  Prioritaet prioritaet;
  int? dauer;
  List<String> unteraufgaben;
  String notiz;
  Wiederholung? wiederholung;

  Map<String, dynamic> toJson() => {
        'id': id,
        'titel': titel,
        'listeId': listeId,
        'prioritaet': prioritaet.name,
        'dauer': dauer,
        'unteraufgaben': unteraufgaben,
        'notiz': notiz,
        'wiederholung': wiederholung?.toJson(),
      };

  factory Vorlage.fromJson(Map<String, dynamic> j) => Vorlage(
        id: j['id'] as String?,
        titel: j['titel'] as String? ?? '',
        listeId: j['listeId'] as String? ?? 'privat',
        prioritaet:
            Prioritaet.values.asNameMap()[j['prioritaet']] ?? Prioritaet.keine,
        dauer: (j['dauer'] as num?)?.toInt(),
        unteraufgaben: [for (final u in (j['unteraufgaben'] as List? ?? const [])) u as String],
        notiz: j['notiz'] as String? ?? '',
        wiederholung: j['wiederholung'] == null
            ? null
            : Wiederholung.fromJson(Map<String, dynamic>.from(j['wiederholung'] as Map)),
      );
}

/// Wie oft ein Aufgaben-Titel schon eingetragen wurde (für Vorschläge).
class Haeufig {
  Haeufig({
    required this.titel,
    required this.listeId,
    this.anzahl = 1,
    this.prioritaet = Prioritaet.keine,
    this.dauer,
    DateTime? zuletzt,
  }) : zuletzt = zuletzt ?? DateTime.now();

  final String titel;
  final String listeId;
  final int anzahl;
  final Prioritaet prioritaet;
  final int? dauer;
  final DateTime zuletzt;

  Map<String, dynamic> toJson() => {
        'titel': titel,
        'listeId': listeId,
        'anzahl': anzahl,
        'prioritaet': prioritaet.name,
        'dauer': dauer,
        'zuletzt': zuletzt.toIso8601String(),
      };

  factory Haeufig.fromJson(Map<String, dynamic> j) => Haeufig(
        titel: j['titel'] as String? ?? '',
        listeId: j['listeId'] as String? ?? 'privat',
        anzahl: (j['anzahl'] as num?)?.toInt() ?? 1,
        prioritaet:
            Prioritaet.values.asNameMap()[j['prioritaet']] ?? Prioritaet.keine,
        dauer: (j['dauer'] as num?)?.toInt(),
        zuletzt: _datum(j['zuletzt']),
      );
}

/// Vergleichsschlüssel für Titel: klein, ohne doppelte Leerzeichen und
/// ohne Satzzeichen am Ende („Wocheneinkauf!“ = „wocheneinkauf“).
String titelSchluessel(String titel) => titel
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[.!?…]+$'), '')
    .replaceAll(RegExp(r'\s+'), ' ');

/// Ein Eintrag „Aufgabe erledigt“ für Statistik, Punkte und Abzeichen.
class ErledigtEintrag {
  const ErledigtEintrag({
    required this.aufgabeId,
    required this.zeit,
    required this.prioritaet,
    required this.listeId,
    required this.puenktlich,
    required this.mitFrist,
  });

  final String aufgabeId;
  final DateTime zeit;
  final Prioritaet prioritaet;
  final String listeId;

  /// Vor oder am Fälligkeits- bzw. Frist-Tag erledigt.
  final bool puenktlich;

  /// Hatte die Aufgabe eine Frist?
  final bool mitFrist;

  factory ErledigtEintrag.aus(Aufgabe a, DateTime zeit) {
    final tag = DateTime(zeit.year, zeit.month, zeit.day);
    final zuSpaet = (a.faellig != null && tag.isAfter(a.faellig!)) ||
        (a.frist != null && tag.isAfter(a.frist!));
    return ErledigtEintrag(
      aufgabeId: a.id,
      zeit: zeit,
      prioritaet: a.prioritaet,
      listeId: a.listeId,
      puenktlich: !zuSpaet,
      mitFrist: a.frist != null,
    );
  }

  Map<String, dynamic> toJson() => {
        'aufgabeId': aufgabeId,
        'zeit': zeit.toIso8601String(),
        'prioritaet': prioritaet.name,
        'listeId': listeId,
        'puenktlich': puenktlich,
        'mitFrist': mitFrist,
      };

  factory ErledigtEintrag.fromJson(Map<String, dynamic> j) => ErledigtEintrag(
        aufgabeId: j['aufgabeId'] as String? ?? '',
        zeit: _datum(j['zeit']) ?? DateTime.now(),
        prioritaet:
            Prioritaet.values.asNameMap()[j['prioritaet']] ?? Prioritaet.keine,
        listeId: j['listeId'] as String? ?? '',
        puenktlich: j['puenktlich'] as bool? ?? true,
        mitFrist: j['mitFrist'] as bool? ?? false,
      );
}

/// Einstellungen für Erinnerungen (Zeiten in Minuten seit Mitternacht).
class ErinnerungsEinstellungen {
  ErinnerungsEinstellungen({
    this.aktiv = false,
    this.vorlauf = 15,
    this.morgens = 8 * 60,
    this.fristen = true,
    this.uebersicht = true,
    this.uebersichtUm = 7 * 60 + 30,
    this.rueckblick = true,
  });

  /// Sonntags um 18 Uhr an den Wochenrückblick erinnern.
  bool rueckblick;

  bool aktiv;

  /// So viele Minuten vor der Uhrzeit einer Aufgabe wird erinnert.
  int vorlauf;

  /// Uhrzeit für Aufgaben ohne Uhrzeit und für Fristen.
  int morgens;

  /// An Fristen erinnern (3 Tage, 1 Tag vorher und am Tag selbst).
  bool fristen;

  /// Morgendliche Tagesübersicht.
  bool uebersicht;
  int uebersichtUm;

  Map<String, dynamic> toJson() => {
        'aktiv': aktiv,
        'vorlauf': vorlauf,
        'morgens': morgens,
        'fristen': fristen,
        'uebersicht': uebersicht,
        'uebersichtUm': uebersichtUm,
        'rueckblick': rueckblick,
      };

  factory ErinnerungsEinstellungen.fromJson(Map<String, dynamic> j) =>
      ErinnerungsEinstellungen(
        aktiv: j['aktiv'] as bool? ?? false,
        vorlauf: (j['vorlauf'] as num?)?.toInt() ?? 15,
        morgens: (j['morgens'] as num?)?.toInt() ?? 8 * 60,
        fristen: j['fristen'] as bool? ?? true,
        uebersicht: j['uebersicht'] as bool? ?? true,
        uebersichtUm: (j['uebersichtUm'] as num?)?.toInt() ?? 7 * 60 + 30,
        rueckblick: j['rueckblick'] as bool? ?? true,
      );
}

/// Ein Termin aus dem Kalender des Handys (nur zum Anzeigen).
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
