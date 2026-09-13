import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:backhaul_frontend/main.dart';

void main() {
  testWidgets('App loads with BackhaulApp', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: BackhaulApp()));

    // Wait for async operations to complete
    await tester.pumpAndSettle();

    // Verify that the app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
