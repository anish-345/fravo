import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  test('Catvertising AdRevenueData and precision constants', () {
    expect(AdRevenuePrecision.exact, isNotNull);
    expect(AdRevenuePrecision.estimated, isNotNull);
    expect(AdRevenuePrecision.unknown, isNotNull);

    final data = AdRevenueData(
      mediatorName: AdMediatorName('admob'),
      adFormat: AdFormat.rewarded,
      adUnitId: 'test_unit_id',
      impressionId: 'test_impression_id',
      revenueMicros: 1500,
      currency: 'USD',
      precision: AdRevenuePrecision.exact,
    );

    expect(data.revenueMicros, 1500);
    expect(data.currency, 'USD');
    expect(data.adUnitId, 'test_unit_id');
  });
}
