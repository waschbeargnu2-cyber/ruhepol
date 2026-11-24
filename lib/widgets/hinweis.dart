import 'package:flutter/material.dart';

import '../aufgaben_store.dart';

/// Kurze Meldung unten am Bildschirm, optional mit „Rückgängig“.
void zeigeHinweis(
  ScaffoldMessengerState messenger,
  String text, {
  AufgabenStore? rueckgaengig,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 4),
        action: rueckgaengig == null
            ? null
            : SnackBarAction(
                label: 'Rückgängig',
                onPressed: rueckgaengig.rueckgaengig,
              ),
      ),
    );
}

/// Überschrift eines Abschnitts mit optionaler Zusatzinfo rechts.
class Abschnitt extends StatelessWidget {
  const Abschnitt(this.titel, {super.key, this.info});

  final String titel;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final farben = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(titel, style: text.titleSmall)),
          if (info != null)
            Text(
              info!,
              style: text.labelMedium?.copyWith(color: farben.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// Freundlicher Hinweis, wenn eine Liste leer ist.
class LeerHinweis extends StatelessWidget {
  const LeerHinweis(this.text, {super.key, this.icon = Icons.wb_sunny_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: farben.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: farben.primary),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: farben.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
