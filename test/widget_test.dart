import 'package:flutter_test/flutter_test.dart';
import 'package:ruhepol/main.dart';

void main() {
  testWidgets('App startet und zeigt die Navigation', (tester) async {
    await tester.pumpWidget(const RuhepolApp());
    expect(find.text('Heute'), findsWidgets);
    expect(find.text('Kalender'), findsWidgets);
  });
}
