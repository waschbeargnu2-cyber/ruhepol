import 'package:flutter_test/flutter_test.dart';
import 'package:ruhepol/aufgaben_store.dart';
import 'package:ruhepol/main.dart';
import 'package:ruhepol/speicher.dart';

void main() {
  testWidgets('App startet mit Begrüßungsaufgaben', (tester) async {
    final speicher = ArbeitsspeicherSpeicher();
    final store = AufgabenStore(speicher);
    await store.laden();

    await tester.pumpWidget(RuhepolApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Heute'), findsWidgets);
    expect(find.text('Tippe auf den Kreis, um mich abzuhaken'), findsOneWidget);
    expect(speicher.daten, isNotNull);
  });

  testWidgets('Abhaken verschiebt Aufgabe zu „Heute erledigt“', (tester) async {
    final store = AufgabenStore(ArbeitsspeicherSpeicher());
    await store.laden();

    await tester.pumpWidget(RuhepolApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Erledigen').first);
    await tester.pumpAndSettle();

    expect(store.aufgaben.where((a) => a.erledigt).length, 1);
    expect(find.text('Heute erledigt'), findsOneWidget);

    // Speicher-Timer und Snackbar ablaufen lassen
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
