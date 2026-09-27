import 'package:backhaul_frontend/constants/algerian_wilayas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contains all 58 Algerian wilayas without duplicates', () {
    expect(algerianWilayas, hasLength(58));
    expect(algerianWilayas.toSet(), hasLength(58));
    expect(algerianWilayas, containsAll(<String>['Alger', 'Oran', 'El Meniaa']));
  });
}
