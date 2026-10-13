import 'package:backhaul_frontend/widgets/wilaya_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search accepts accents and only selects existing wilayas', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: WilayaField(
        decoration: const InputDecoration(labelText: 'Départ'),
        onChanged: (value) => selected = value,
      )),
    ));
    await tester.tap(find.byType(WilayaField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'inconnue');
    await tester.pumpAndSettle();
    expect(find.text('Aucune wilaya trouvée'), findsOneWidget);
    expect(selected, isNull);
    await tester.enterText(find.byType(TextField), 'SETIF');
    await tester.pumpAndSettle();
    expect(find.text('Sétif'), findsOneWidget);
    await tester.tap(find.text('Sétif'));
    await tester.pumpAndSettle();
    expect(selected, 'Sétif');
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byType(WilayaField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'oran');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(selected, 'Sétif');
  });
}
