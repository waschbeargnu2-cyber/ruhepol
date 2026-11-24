import 'package:flutter/material.dart';

import '../aufgaben_store.dart';
import '../datum.dart';
import '../design.dart';
import '../erinnerungen.dart';
import '../handy_kalender.dart';
import '../modelle.dart';
import '../updates.dart';
import '../widgets/hinweis.dart';

class MehrSeite extends StatelessWidget {
  const MehrSeite({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final offen = store.aufgaben.where((a) => !a.erledigt).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Einstellungen',
          style: text.labelLarge?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text('Mehr', style: text.headlineMedium),

        const Abschnitt('Erinnerungen'),
        const _ErinnerungsKarte(),

        const Abschnitt('Kalender'),
        const _KalenderKarte(),

        Abschnitt('Vorlagen', info: '${store.vorlagen.length}'),
        const _VorlagenKarte(),

        const Abschnitt('Farbschema'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in Pastell.values)
              ChoiceChip(
                label: Text(p.label),
                avatar: CircleAvatar(backgroundColor: p.seed),
                showCheckmark: false,
                selected: p == store.farbe,
                onSelected: (_) => store.farbeSetzen(p),
              ),
          ],
        ),

        const Abschnitt('Hell oder dunkel'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('Automatisch'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('Hell'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('Dunkel'),
              ),
            ],
            selected: {store.themeMode},
            onSelectionChanged: (s) => store.themeModeSetzen(s.first),
          ),
        ),

        const Abschnitt('Deine Daten'),
        Card.filled(
          margin: EdgeInsets.zero,
          color: farben.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_android, color: farben.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$offen offene Aufgaben in ${store.listen.length} Listen, '
                        'nur auf diesem Handy gespeichert.',
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tipp: Schalte unter Einstellungen → Konten und Sicherung → '
                  'Google Drive die Sicherung ein. Dann sichert Android '
                  'Agenda automatisch mit.',
                  style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),

        const Abschnitt('App'),
        const _AppKarte(),
      ],
    );
  }
}

class _VorlagenKarte extends StatelessWidget {
  const _VorlagenKarte();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final vorlagen = store.vorlagen.toList()
      ..sort((a, b) => a.titel.toLowerCase().compareTo(b.titel.toLowerCase()));

    return Card.filled(
      margin: EdgeInsets.zero,
      color: farben.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vorlagen.isEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Noch keine Vorlagen. Speichere eine Aufgabe in ihren Details mit '
                  '„Als Vorlage speichern“. Was du öfter einträgst, schlägt Agenda '
                  'dir automatisch vor.',
                  style: text.bodyMedium,
                ),
              ),
            for (final v in vorlagen)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bookmark, color: farben.primary),
                title: Text(v.titel),
                subtitle: Text([
                  store.listeVon(v.listeId).name,
                  if (v.prioritaet != Prioritaet.keine) v.prioritaet.label,
                  if (v.dauer != null) dauerText(v.dauer!),
                  if (v.unteraufgaben.isNotEmpty) '${v.unteraufgaben.length} Unteraufgaben',
                  '${store.haeufigkeit(v.titel)}× genutzt',
                ].join(' · ')),
                trailing: IconButton(
                  tooltip: 'Vorlage löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(context);
                    store.vorlageLoeschen(v.id);
                    zeigeHinweis(messenger, 'Vorlage „${v.titel}“ gelöscht');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppKarte extends StatelessWidget {
  const _AppKarte();

  @override
  Widget build(BuildContext context) {
    final u = UpdateScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final neu = u.neu;

    final status = switch (u.status) {
      UpdateStatus.pruefe => 'Suche nach Updates …',
      UpdateStatus.laedt => 'Lade neue Version …',
      UpdateStatus.aktuell => 'Du hast die neueste Version.',
      UpdateStatus.verfuegbar when neu != null =>
        'Neue Version verfügbar: Build ${neu.build} (${neu.groesseText})',
      UpdateStatus.fehler => 'Update-Suche fehlgeschlagen.',
      _ => 'Updates kommen direkt von GitHub.',
    };

    return Card.filled(
      margin: EdgeInsets.zero,
      color: farben.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: farben.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Agenda ${u.versionText}', style: text.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(status, style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant)),
            if (u.verfuegbar && neu != null && neu.notiz.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Neu:', style: text.labelLarge),
              Text(neu.notiz, style: text.bodySmall),
            ],
            if (u.fehler != null) ...[
              const SizedBox(height: 8),
              Text(u.fehler!, style: text.bodySmall?.copyWith(color: farben.error)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (u.verfuegbar)
                  FilledButton.icon(
                    onPressed: u.status == UpdateStatus.laedt ? null : u.installieren,
                    icon: u.status == UpdateStatus.laedt
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update),
                    label: const Text('Aktualisieren'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: u.status == UpdateStatus.pruefe ? null : () => u.pruefen(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nach Updates suchen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErinnerungsKarte extends StatelessWidget {
  const _ErinnerungsKarte();

  static const _vorlaufOptionen = [0, 5, 10, 15, 30, 60];

  String _vorlaufText(int minuten) =>
      minuten == 0 ? 'Genau zur Uhrzeit' : '$minuten Minuten vorher';

  Future<void> _zeitWaehlen(
    BuildContext context,
    int aktuell,
    String hilfe,
    void Function(int minute) setzen,
  ) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: aktuell ~/ 60, minute: aktuell % 60),
      helpText: hilfe,
    );
    if (t != null) setzen(t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final dienst = ErinnerungsScope.of(context);
    final store = StoreScope.of(context);
    final e = store.erinnerung;
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final inhalt = <Widget>[];
    if (dienst.aktiv) {
      final n = dienst.naechste;
      inhalt.addAll([
        Row(
          children: [
            Icon(Icons.notifications_active, color: farben.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${dienst.geplant} Erinnerungen geplant'
                '${n != null ? ' · nächste: ${relativ(n.zeit)}, '
                    '${uhrzeitText(n.zeit.hour * 60 + n.zeit.minute)} Uhr' : ''}',
                style: text.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: const Text('Aufgaben mit Uhrzeit'),
          subtitle: Text(_vorlaufText(e.vorlauf)),
          onTap: () async {
            final wahl = await showDialog<int>(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('Erinnern'),
                children: [
                  for (final m in _vorlaufOptionen)
                    SimpleDialogOption(
                      onPressed: () => Navigator.of(context).pop(m),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(_vorlaufText(m)),
                      ),
                    ),
                ],
              ),
            );
            if (wahl != null) store.erinnerungAendern((x) => x.vorlauf = wahl);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.wb_sunny_outlined),
          title: const Text('Aufgaben ohne Uhrzeit und Fristen'),
          subtitle: Text('Am Tag um ${uhrzeitText(e.morgens)} Uhr'),
          onTap: () => _zeitWaehlen(
            context,
            e.morgens,
            'Erinnerung ohne Uhrzeit',
            (m) => store.erinnerungAendern((x) => x.morgens = m),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.flag_outlined),
          title: const Text('An Fristen erinnern'),
          subtitle: const Text('3 Tage, 1 Tag vorher und am Tag selbst'),
          value: e.fristen,
          onChanged: (v) => store.erinnerungAendern((x) => x.fristen = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.wb_twilight),
          title: const Text('Morgen-Übersicht'),
          subtitle: Text('Dein Tag auf einen Blick um ${uhrzeitText(e.uebersichtUm)} Uhr'),
          value: e.uebersicht,
          onChanged: (v) => store.erinnerungAendern((x) => x.uebersicht = v),
        ),
        if (e.uebersicht)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 40),
            title: const Text('Uhrzeit der Übersicht'),
            subtitle: Text('${uhrzeitText(e.uebersichtUm)} Uhr'),
            onTap: () => _zeitWaehlen(
              context,
              e.uebersichtUm,
              'Morgen-Übersicht',
              (m) => store.erinnerungAendern((x) => x.uebersichtUm = m),
            ),
          ),
        if (!dienst.exakt)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Hinweis: Android erlaubt gerade keine minutengenauen Wecker. '
              'Erinnerungen können ein paar Minuten später kommen.',
              style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
            ),
          ),
        Text(
          'Tipp: Kommen Erinnerungen zu spät, nimm Agenda unter Einstellungen → '
          'Akku → Hintergrundnutzungslimits aus den „schlafenden Apps“ heraus.',
          style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                dienst.testErinnerung();
                zeigeHinweis(messenger, 'Test-Erinnerung kommt in 10 Sekunden');
              },
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Test in 10 Sek.'),
            ),
            TextButton(
              onPressed: dienst.ausschalten,
              child: const Text('Ausschalten'),
            ),
          ],
        ),
      ]);
    } else {
      final dauerhaft = dienst.status == ErinnerungsStatus.dauerhaftVerweigert;
      inhalt.addAll([
        Text(
          'Agenda erinnert dich zur Uhrzeit einer Aufgabe, vor Fristen und auf '
          'Wunsch jeden Morgen mit einer Tagesübersicht. In der Benachrichtigung '
          'kannst du Aufgaben direkt abhaken oder um eine Stunde verschieben.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: dienst.status == ErinnerungsStatus.verbinde
              ? null
              : dauerhaft
                  ? dienst.einstellungenOeffnen
                  : dienst.einschalten,
          icon: Icon(dauerhaft ? Icons.settings : Icons.notifications_active),
          label: Text(dauerhaft ? 'App-Einstellungen öffnen' : 'Erinnerungen einschalten'),
        ),
        if (dauerhaft) ...[
          const SizedBox(height: 4),
          TextButton(onPressed: dienst.einschalten, child: const Text('Erneut prüfen')),
        ],
      ]);
    }
    if (dienst.fehler != null) {
      inhalt.addAll([
        const SizedBox(height: 10),
        Text(dienst.fehler!, style: text.bodySmall?.copyWith(color: farben.error)),
      ]);
    }

    return Card.filled(
      margin: EdgeInsets.zero,
      color: farben.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: inhalt,
        ),
      ),
    );
  }
}

class _KalenderKarte extends StatelessWidget {
  const _KalenderKarte();

  @override
  Widget build(BuildContext context) {
    final dienst = KalenderScope.of(context);
    final store = StoreScope.of(context);
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final inhalt = <Widget>[];
    if (dienst.verbunden) {
      final stand = store.termineStand;
      final ziel = dienst.zielKalender;
      inhalt.addAll([
        Row(
          children: [
            Icon(Icons.check_circle, color: farben.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Verbunden · ${store.termine.length} Termine'
                '${stand != null ? ' (Stand ${uhrzeitText(stand.hour * 60 + stand.minute)})' : ''}',
                style: text.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.edit_calendar),
          title: const Text('Aufgaben eintragen in'),
          subtitle: Text(
            ziel == null ? 'Agenda (nur auf diesem Handy)' : '${ziel.name} · ${ziel.herkunft}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _zielWaehlen(context, dienst),
        ),
        Text(
          'Nur Aufgaben mit Datum und Uhrzeit werden eingetragen. Deine anderen '
          'Termine liest Agenda nur.',
          style: text.bodySmall?.copyWith(color: farben.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: dienst.laedt ? null : dienst.aktualisieren,
              icon: const Icon(Icons.refresh),
              label: const Text('Aktualisieren'),
            ),
            TextButton(
              onPressed: dienst.ausschalten,
              child: const Text('Ausschalten'),
            ),
          ],
        ),
      ]);
    } else {
      final dauerhaft = dienst.status == KalenderStatus.dauerhaftVerweigert;
      inhalt.addAll([
        Text(
          'Verbinde den Kalender deines Handys: Termine aus Google- und '
          'Samsung-Kalender erscheinen dann in Agenda, und Aufgaben mit Uhrzeit '
          'werden dort eingetragen. Dafür braucht es kein Google-Konto in der App.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: dienst.status == KalenderStatus.verbinde
              ? null
              : dauerhaft
                  ? dienst.einstellungenOeffnen
                  : dienst.verbinden,
          icon: Icon(dauerhaft ? Icons.settings : Icons.event_available),
          label: Text(dauerhaft ? 'App-Einstellungen öffnen' : 'Kalender verbinden'),
        ),
        if (dauerhaft) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: dienst.verbinden,
            child: const Text('Erneut prüfen'),
          ),
        ],
      ]);
    }
    if (dienst.fehler != null) {
      inhalt.addAll([
        const SizedBox(height: 10),
        Text(dienst.fehler!, style: text.bodySmall?.copyWith(color: farben.error)),
      ]);
    }

    return Card.filled(
      margin: EdgeInsets.zero,
      color: farben.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: inhalt,
        ),
      ),
    );
  }

  Future<void> _zielWaehlen(BuildContext context, KalenderDienst dienst) async {
    final kalender = dienst.schreibbareKalender;
    final aktuell = dienst.zielKalender?.id;
    final wahl = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Wähle einen Google-Kalender, wenn die Aufgaben auch auf anderen '
                'Geräten erscheinen sollen.',
              ),
            ),
            for (final k in kalender)
              ListTile(
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor:
                      k.farbe != null ? Color((k.farbe! & 0xFFFFFF) | 0xFF000000) : null,
                ),
                title: Text(k.istEigener ? 'Agenda' : k.name),
                subtitle: Text(k.herkunft),
                trailing: k.id == aktuell ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(k.id),
              ),
          ],
        ),
      ),
    );
    if (wahl != null) await dienst.zielSetzen(wahl);
  }
}
