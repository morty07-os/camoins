import 'package:flutter_test/flutter_test.dart';
import 'package:backhaul_frontend/models/trip.dart';

void main() {
  group('Trip.fromJson', () {
    test('parses all fields including optional coordinates and data', () {
      final trip = Trip.fromJson({
        'id': 3,
        'driver_id': 1,
        'truck_id': 7,
        'origin_name': 'Alger',
        'origin_lat': 36.7538,
        'origin_lng': 3.0588,
        'destination_name': 'Sétif',
        'destination_lat': null,
        'destination_lng': null,
        'departure_date': '2026-09-15',
        'available_weight': 5000,
        'available_volume': 40,
        'trip_type': 'RETURN',
        'status': 'PUBLISHED',
        'description': 'Retour à vide',
        'created_at': '2026-09-01 10:00:00',
        'updated_at': '2026-09-01 10:00:00',
      });

      expect(trip.id, 3);
      expect(trip.driverId, 1);
      expect(trip.truckId, 7);
      expect(trip.originName, 'Alger');
      expect(trip.originLat, 36.7538);
      expect(trip.originLng, 3.0588);
      expect(trip.destinationName, 'Sétif');
      expect(trip.destinationLat, isNull);
      expect(trip.destinationLng, isNull);
      expect(trip.departureDate, '2026-09-15');
      expect(trip.availableWeight, 5000.0);
      expect(trip.availableVolume, 40.0);
      expect(trip.tripType, 'RETURN');
      expect(trip.status, 'PUBLISHED');
      expect(trip.description, 'Retour à vide');
    });

    test('defaults missing optional fields safely', () {
      final trip = Trip.fromJson({
        'id': 1,
        'driver_id': 1,
        'truck_id': 1,
        'origin_name': 'Alger',
        'destination_name': 'Sétif',
        'departure_date': '2026-09-15',
        'available_weight': 2000,
        'created_at': '',
        'updated_at': '',
      });

      expect(trip.originLat, isNull);
      expect(trip.originLng, isNull);
      expect(trip.availableVolume, isNull);
      expect(trip.description, '');
      expect(trip.tripType, 'RETURN');
      expect(trip.status, 'PUBLISHED');
    });
  });

  group('tripTypeDisplayNames', () {
    test('contains exactly the RETURN trip type', () {
      expect(Trip.tripTypeDisplayNames.keys.toSet(), {'RETURN'});
    });

    test('maps RETURN to the French label', () {
      final trip = Trip(
        id: 1,
        driverId: 1,
        truckId: 1,
        originName: 'Alger',
        destinationName: 'Sétif',
        departureDate: '2026-09-15',
        availableWeight: 1000,
        createdAt: '',
        updatedAt: '',
      );

      expect(trip.tripTypeDisplayName, 'Trajet retour');
    });
  });

  group('statusDisplayNames', () {
    test('contains exactly the four supported statuses', () {
      expect(Trip.statusDisplayNames.keys.toSet(), {
        'PUBLISHED',
        'IN_PROGRESS',
        'COMPLETED',
        'CANCELLED',
      });
    });

    test('has no duplicated French labels', () {
      final labels = Trip.statusDisplayNames.values.toList();
      expect(labels.toSet().length, labels.length);
    });

    Trip buildTrip(String status) => Trip(
          id: 1,
          driverId: 1,
          truckId: 1,
          originName: 'Alger',
          destinationName: 'Sétif',
          departureDate: '2026-09-15',
          availableWeight: 1000,
          status: status,
          createdAt: '',
          updatedAt: '',
        );

    test('maps internal English values to French labels', () {
      expect(buildTrip('PUBLISHED').statusDisplayName, 'Publié');
      expect(buildTrip('IN_PROGRESS').statusDisplayName, 'En cours');
      expect(buildTrip('COMPLETED').statusDisplayName, 'Terminé');
      expect(buildTrip('CANCELLED').statusDisplayName, 'Annulé');
    });

    test('exposes correct status getters', () {
      expect(buildTrip('PUBLISHED').isPublished, isTrue);
      expect(buildTrip('PUBLISHED').isInProgress, isFalse);
      expect(buildTrip('IN_PROGRESS').isInProgress, isTrue);
      expect(buildTrip('COMPLETED').isCompleted, isTrue);
      expect(buildTrip('CANCELLED').isCancelled, isTrue);
    });
  });

  group('display helpers', () {
    Trip buildTrip({
      double weight = 5000,
      double? volume = 40,
    }) =>
        Trip(
          id: 1,
          driverId: 1,
          truckId: 1,
          originName: 'Alger',
          destinationName: 'Sétif',
          departureDate: '2026-09-15',
          availableWeight: weight,
          availableVolume: volume,
          createdAt: '',
          updatedAt: '',
        );

    test('routeLabel combines origin and destination', () {
      expect(buildTrip().routeLabel, 'Alger → Sétif');
    });

    test('capacityLabel shows kilograms', () {
      expect(buildTrip().capacityLabel, '5000 kg disponibles');
      expect(buildTrip(weight: 5000.5).capacityLabel, '5000.5 kg disponibles');
    });

    test('formatFrenchDate renders French long date', () {
      expect(Trip.formatFrenchDate('2026-09-15'), '15 septembre 2026');
      expect(Trip.formatFrenchDate('2026-01-05'), '5 janvier 2026');
      expect(Trip.formatFrenchDate('not-a-date'), 'not-a-date');
    });
  });
}