import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../erfolge.dart';
import '../modelle.dart';
import '../widgets/aufgabe_kachel.dart';
import '../widgets/hinweis.dart';

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Seite „Erfolge“: Level, Serie, Wochenstatistik, Abzeichen und
// das Archiv aller erledigten Aufgaben (mit Suche). Erledigte Aufgaben lassen
// sich hier über den Kreis wieder öffnen. Die Regeln stehen in erfolge.dart.
// ---------------------------------------------------------------------------

class ErfolgeSeite extends StatefulWidget {
  const ErfolgeSeite({super.key});

  @override
  State<ErfolgeSeite> createState() => _ErfolgeSeiteState();
}

class _ErfolgeSeiteState extends State<ErfolgeSeite> {
  final _suche = TextEditingController();
  int _anzeigen = 30;

  @override
  void dispose() {
    _suche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final e = Erfolge.berechnen(store.erledigtLog, DateTime.now());

    final begriff = _suche.text.trim().toLowerCase();
    final archiv = store.aufgaben
        .where((a) => a.erledigt && (begriff.isEmpty || a.titel.toLowerCase().contains(begriff)))
        .toList()
      ..sort((a, b) => (b.erledigtAm ?? b.erstellt).compareTo(a.erledigtAm ?? a.erstellt));

    final archivZeilen = <Widget>[];
    DateTime? letzterTag;
    for (final a in archiv.take(_anzeigen)) {
      final tag = nurDatum(a.erledigtAm ?? a.erstellt);
      if (letzterTag == null || tageZwischen(tag, letzterTag) != 0) {
        archivZeilen.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(
            '${relativ(tag)} · ${tag.day}.${tag.month}.${tag.year}',
            style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
          ),
        ));
        letzterTag = tag;
      }
      archivZeilen.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AufgabeKachel(aufgabe: a),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Was du geschafft hast',
          style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text('Erfolge', style: text.headlineMedium),
        const SizedBox(height: 16),
        _LevelKarte(e: e),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Kachel(
                icon: Icons.local_fire_department,
                wert: '${e.serie}',
                einheit: e.serie == 1 ? 'Tag Serie' : 'Tage Serie',
                farbe: prioFarbe(Prioritaet.mittel, farben),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Kachel(
                icon: Icons.date_range,
                wert: '${e.dieseWoche}',
                einheit: 'diese Woche',
                farbe: farben.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Kachel(
                icon: Icons.task_alt,
                wert: '${e.gesamt}',
                einheit: 'insgesamt',
                farbe: farben.tertiary,
              ),
            ),
          ],
        ),
        Abschnitt('Letzte 7 Tage', info: 'Rekord: ${e.besterTag} an einem Tag'),
        _Wochendiagramm(werte: e.letzte7Tage),
        Abschnitt(
          'Abzeichen',
          info: '${e.abzeichen.where((a) => a.erreicht).length} von ${e.abzeichen.length}',
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: [for (final a in e.abzeichen) _AbzeichenKachel(a: a)],
        ),
        Abschnitt('Archiv', info: '${store.aufgaben.where((a) => a.erledigt).length} erledigt'),
        TextField(
          controller: _suche,
          onChanged: (_) => setState(() => _anzeigen = 30),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Erledigte Aufgaben durchsuchen',
            filled: true,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (archiv.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LeerHinweis(
              'Hier landen alle erledigten Aufgaben. Über den Kreis kannst du sie wieder öffnen.',
              icon: Icons.inventory_2_outlined,
            ),
          ),
        ...archivZeilen,
        if (archiv.length > _anzeigen)
          TextButton(
            onPressed: () => setState(() => _anzeigen += 30),
            child: Text('${archiv.length - _anzeigen} weitere anzeigen'),
          ),
      ],
    );
  }
}

class _LevelKarte extends StatelessWidget {
  const _LevelKarte({required this.e});

  final Erfolge e;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final vorne = farben.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: farben.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: e.levelFortschritt,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  color: farben.primary,
                  backgroundColor: vorne.withValues(alpha: 0.12),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Level', style: text.labelSmall?.copyWith(color: vorne)),
                      Text(
                        '${e.level}',
                        style: text.headlineSmall?.copyWith(
                          color: vorne,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.levelTitel, style: text.titleLarge?.copyWith(color: vorne)),
                const SizedBox(height: 2),
                Text(
                  '${e.punkte} Punkte · noch ${e.punkteBisNaechstes} bis Level ${e.level + 1}',
                  style: text.bodySmall?.copyWith(color: vorne.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 8),
                Text(
                  e.heute == 0
                      ? 'Heute noch nichts abgehakt, los geht’s!'
                      : 'Heute schon ${e.heute} erledigt. Weiter so!',
                  style: text.labelLarge?.copyWith(color: vorne),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kachel extends StatelessWidget {
  const _Kachel({
    required this.icon,
    required this.wert,
    required this.einheit,
    required this.farbe,
  });

  final IconData icon;
  final String wert;
  final String einheit;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: farben.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: farbe),
          const SizedBox(height: 8),
          Text(wert, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text(
            einheit,
            style: text.labelMedium?.copyWith(color: farben.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Wochendiagramm extends StatelessWidget {
  const _Wochendiagramm({required this.werte});

  final List<int> werte;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final h = heute();
    final maximum = werte.fold<int>(1, (m, v) => v > m ? v : m);
    const hoehe = 110.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: farben.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < werte.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    werte[i] == 0 ? '' : '${werte[i]}',
                    style: text.labelSmall?.copyWith(color: farben.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: werte[i] == 0 ? 4 : 4 + (hoehe - 4) * werte[i] / maximum,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: i == werte.length - 1
                          ? farben.primary
                          : farben.primary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    wochentageKurz[plusTage(h, i - 6).weekday - 1],
                    style: text.labelSmall?.copyWith(
                      color: i == werte.length - 1 ? farben.primary : farben.onSurfaceVariant,
                      fontWeight: i == werte.length - 1 ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AbzeichenKachel extends StatelessWidget {
  const _AbzeichenKachel({required this.a});

  final Abzeichen a;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final aktiv = a.erreicht;
    final symbolFarbe = aktiv ? farben.onTertiaryContainer : farben.outline;

    return Tooltip(
      message: '${a.beschreibung} (${a.stand > a.ziel ? a.ziel : a.stand}/${a.ziel})',
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: aktiv ? farben.tertiaryContainer : farben.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    value: a.fortschritt,
                    strokeWidth: 3,
                    color: aktiv ? farben.tertiary : farben.outline,
                    backgroundColor: farben.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                Icon(aktiv ? a.icon : Icons.lock_outline, color: symbolFarbe, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              a.titel,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(
                color: aktiv ? farben.onTertiaryContainer : farben.onSurfaceVariant,
                fontWeight: aktiv ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
