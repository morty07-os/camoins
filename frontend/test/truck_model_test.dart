import 'package:flutter_test/flutter_test.dart';
import 'package:backhaul_frontend/models/truck.dart';

void main() {
  Truck buildTruck(String type) => Truck(
        id: 1,
        driverId: 1,
        truckType: type,
        maxWeight: 1000,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
      );

  group('TruckTypeDisplayNames', () {
    test('contains exactly the six supported truck types', () {
      expect(Truck.truckTypeDisplayNames.keys.toSet(), {
        'FLATBED',
        'TARP',
        'REFRIGERATED',
        'VAN',
        'SEMI_TRAILER',
        'OTHER',
      });
    });

    test('has no duplicated French labels', () {
      final labels = Truck.truckTypeDisplayNames.values.toList();
      expect(labels.toSet().length, labels.length);
    });

    test('maps internal English values to French labels', () {
      expect(buildTruck('FLATBED').displayName, 'Plateau');
      expect(buildTruck('TARP').displayName, 'Camion bâché');
      expect(buildTruck('REFRIGERATED').displayName, 'Camion frigorifique');
      expect(buildTruck('VAN').displayName, 'Fourgon');
      expect(buildTruck('SEMI_TRAILER').displayName, 'Semi-remorque');
      expect(buildTruck('OTHER').displayName, 'Autre');
    });
  });

  group('Truck.fromJson', () {
    test('parses optional fields and numbers', () {
      final truck = Truck.fromJson({
        'id': 5,
        'driver_id': 2,
        'truck_type': 'REFRIGERATED',
        'brand': 'Mercedes',
        'model': 'Actros',
        'max_weight': 20000,
        'max_volume': 90,
        'registration_number': 'DZ-9999-Z',
        'image_url': null,
        'created_at': '2026-01-01 10:00:00',
        'updated_at': '2026-01-01 10:00:00',
      });

      expect(truck.id, 5);
      expect(truck.driverId, 2);
      expect(truck.truckType, 'REFRIGERATED');
      expect(truck.brand, 'Mercedes');
      expect(truck.model, 'Actros');
      expect(truck.maxWeight, 20000);
      expect(truck.maxVolume, 90);
      expect(truck.registrationNumber, 'DZ-9999-Z');
      expect(truck.displayName, 'Camion frigorifique');
    });

    test('defaults missing optional string fields', () {
      final truck = Truck.fromJson({
        'id': 1,
        'driver_id': 1,
        'truck_type': 'PLATEAU',
        'max_weight': 1000,
        'max_volume': null,
        'created_at': 'x',
        'updated_at': 'x',
      });

      expect(truck.brand, '');
      expect(truck.model, '');
      expect(truck.registrationNumber, '');
      expect(truck.maxVolume, isNull);
    });
  });
}