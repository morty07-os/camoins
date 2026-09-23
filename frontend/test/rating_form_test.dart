import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backhaul_frontend/widgets/rating_bottom_sheet.dart';

void main() {
  testWidgets('Rating form requires a star selection and allows an optional comment', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: RatingBottomSheet(
        tripId: 1, requestId: 2, reviewedUserId: 3, reviewedUserName: 'Samir',
      ))),
    ));
    expect(find.text('Évaluer le transport'), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));
    final submit = find.text("Envoyer l'évaluation");
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Veuillez sélectionner une note'), findsOneWidget);
    final fifthStar = find.byIcon(Icons.star_border_rounded).last;
    await tester.ensureVisible(fifthStar);
    await tester.tap(fifthStar);
    await tester.pump();
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('Veuillez sélectionner une note'), findsNothing);
    expect(find.text('Commentaire (optionnel)'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });
}
