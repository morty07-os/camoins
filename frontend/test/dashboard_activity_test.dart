import 'dart:async';
import 'package:backhaul_frontend/models/transport_request.dart';
import 'package:backhaul_frontend/models/trip.dart';
import 'package:backhaul_frontend/widgets/dashboard_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'counts actionable requests and selects the nearest published departure',
      (tester) async {
    final statuses = [
      'PENDING',
      'PRICE_PROPOSED',
      'ACCEPTED',
      'AWAITING_CUSTOMER_CONFIRMATION',
      'COMPLETED',
      'CANCELLED',
      'REJECTED'
    ];
    Trip trip(int id, String date, String status) => Trip.fromJson({
          'id': id,
          'driver_id': 1,
          'truck_id': 1,
          'departure_date': date,
          'status': status,
          'origin_name': 'Alger',
          'destination_name': 'Oran'
        });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          dashboardRequestsProvider.overrideWith((ref) async => [
                for (var i = 0; i < statuses.length; i++)
                  TransportRequest.fromJson({
                    'id': i,
                    'trip_id': 1,
                    'customer_id': 1,
                    'status': statuses[i]
                  })
              ]),
          dashboardTripsProvider.overrideWith((ref) async => [
                trip(1, '2000-01-01', 'PUBLISHED'),
                trip(2, '2099-02-01', 'PUBLISHED'),
                trip(3, '2099-01-01', 'PUBLISHED'),
                trip(4, '2098-01-01', 'CANCELLED')
              ]),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: DashboardActivity(driver: true))))));
    await tester.pumpAndSettle();
    expect(find.text('1 demandes en attente'), findsOneWidget);
    expect(find.text('1 prix à confirmer'), findsOneWidget);
    expect(find.text('2 transports actifs'), findsOneWidget);
    expect(find.textContaining('2099-01-01'), findsOneWidget);
    expect(find.textContaining('2099-02-01'), findsNothing);
  });

  testWidgets(
      'loading and failed requests do not appear as zero activity and retry recovers',
      (tester) async {
    var attempts = 0;
    final pending = Completer<List<TransportRequest>>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          dashboardRequestsProvider.overrideWith((ref) {
            attempts++;
            return attempts == 1 ? pending.future : Future.value([]);
          }),
        ],
        child: const MaterialApp(
            home: Scaffold(body: DashboardActivity(driver: false)))));
    expect(find.textContaining('Chargement'), findsOneWidget);
    expect(find.text('0 demandes en attente'), findsNothing);
    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Activité indisponible'), findsOneWidget);
    expect(find.text('0 demandes en attente'), findsNothing);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('0 demandes en attente'), findsOneWidget);
    expect(attempts, 2);
  });
}
