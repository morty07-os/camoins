import 'dart:convert';

import 'package:backhaul_frontend/pages/trip_search_results_page.dart';
import 'package:backhaul_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> resultJson(String driverName) => {
      'trip': {
        'id': driverName == 'Latest driver' ? 2 : 1,
        'driver_id': 10,
        'truck_id': 20,
        'origin_name': 'Alger',
        'destination_name': 'Sétif',
        'departure_date': '2035-06-10',
        'available_weight': 1500,
        'available_volume': 20,
        'trip_type': 'RETURN',
        'status': 'PUBLISHED',
        'created_at': '2035-01-01',
        'updated_at': '2035-01-01',
      },
      'driver': {
        'id': 10,
        'email': 'driver@example.test',
        'full_name': driverName,
        'rating': 4.5,
        'rating_count': 3,
      },
      'truck': {
        'id': 20,
        'driver_id': 10,
        'truck_type': 'TARP',
        'brand': 'Volvo',
        'model': 'FH',
        'max_weight': 5000,
        'max_volume': 50,
        'registration_number': 'TEST',
        'created_at': '2035-01-01',
        'updated_at': '2035-01-01',
      },
      'matchScore': 100,
    };

http.Response responseFor(String driverName) => http.Response(
      jsonEncode({
        'success': true,
        'count': 1,
        'page': 1,
        'totalPages': 1,
        'trips': [resultJson(driverName)],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

http.Response emptyResponse() => http.Response(
      jsonEncode({
        'success': true,
        'count': 0,
        'page': 1,
        'pageSize': 20,
        'totalPages': 0,
        'trips': <dynamic>[],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('loads immediately and keeps only the newest debounced response',
      (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final origin = request.url.queryParameters['origin_name'];
      if (origin == 'a') {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        return responseFor('Stale driver');
      }
      if (origin == 'ab') {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return responseFor('Latest driver');
      }
      return responseFor('Initial driver');
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripSearchResultsPage(apiService: ApiService(client: client)),
        ),
      ),
    );
    await tester.pump();
    expect(requests.single.queryParameters['page'], '1');
    expect(requests.single.queryParameters.containsKey('origin_name'), isFalse);

    final departure = find.widgetWithText(TextField, 'Départ');
    await tester.enterText(departure, 'a');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(departure, 'ab');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Latest driver'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Latest driver'), findsOneWidget);
    expect(find.text('Stale driver'), findsNothing);
    expect(requests.last.queryParameters['origin_name'], 'ab');
  });

  testWidgets('accepts decimal commas and sends canonical capacity units',
      (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return responseFor('Driver');
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripSearchResultsPage(apiService: ApiService(client: client)),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Poids min. (kg)'), '1000,5');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(requests.last.queryParameters['required_weight'], '1000.5');
    expect(find.textContaining('nombre positif'), findsNothing);
  });

  testWidgets('combines filters, clears one independently, and resets all',
      (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return responseFor('Driver');
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripSearchResultsPage(apiService: ApiService(client: client)),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Départ'), 'Alger');
    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      'Oran',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Poids min. (kg)'),
      '1000',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(requests.last.queryParameters['origin_name'], 'Alger');
    expect(requests.last.queryParameters['destination_name'], 'Oran');
    expect(requests.last.queryParameters['required_weight'], '1000.0');

    await tester.enterText(find.widgetWithText(TextField, 'Départ'), '');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(requests.last.queryParameters.containsKey('origin_name'), isFalse);
    expect(requests.last.queryParameters['destination_name'], 'Oran');
    expect(requests.last.queryParameters['required_weight'], '1000.0');

    await tester.tap(find.text('Réinitialiser').first);
    await tester.pump();
    expect(requests.last.queryParameters.containsKey('destination_name'), isFalse);
    expect(requests.last.queryParameters.containsKey('required_weight'), isFalse);
    expect(requests.last.queryParameters['page'], '1');
  });

  testWidgets('shows an explicit empty state and reset restores all trips',
      (tester) async {
    final client = MockClient((request) async {
      return request.url.queryParameters['origin_name'] == 'Constantine'
          ? emptyResponse()
          : responseFor('Available driver');
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripSearchResultsPage(apiService: ApiService(client: client)),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Départ'),
      'Constantine',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(
      find.text('Aucun trajet ne correspond à vos critères'),
      findsOneWidget,
    );
    expect(find.text('Available driver'), findsNothing);

    await tester.tap(find.text('Réinitialiser').first);
    await tester.pump();
    expect(find.text('Available driver'), findsOneWidget);
  });

  testWidgets('invalid capacity is rejected without sending a request',
      (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return responseFor('Driver');
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripSearchResultsPage(apiService: ApiService(client: client)),
        ),
      ),
    );
    await tester.pump();
    final initialRequestCount = requests.length;

    await tester.enterText(
      find.widgetWithText(TextField, 'Poids min. (kg)'),
      '-1',
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(requests, hasLength(initialRequestCount));
    expect(find.text('Saisissez un nombre positif (kg)'), findsOneWidget);
  });

  testWidgets('request errors do not display stale matching trips',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.queryParameters['origin_name'] == 'Erreur') {
        return http.Response(
          jsonEncode({'success': false, 'message': 'Serveur indisponible'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      }
      return responseFor('Previously loaded driver');
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripSearchResultsPage(apiService: ApiService(client: client)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Previously loaded driver'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Départ'), 'Erreur');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Impossible de charger les trajets'), findsOneWidget);
    expect(find.text('Previously loaded driver'), findsNothing);
  });

  testWidgets('loads subsequent server-filtered pages when scrolling',
      (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final page = request.url.queryParameters['page'] ?? '1';
      return http.Response(
        jsonEncode({
          'success': true,
          'count': 2,
          'page': int.parse(page),
          'pageSize': 1,
          'totalPages': 2,
          'trips': [resultJson(page == '1' ? 'Page one' : 'Page two')],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripSearchResultsPage(apiService: ApiService(client: client)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Page one'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pump();
    await tester.pump();

    expect(requests.any((uri) => uri.queryParameters['page'] == '2'), isTrue);
    expect(find.text('Page two'), findsOneWidget);
  });
}
