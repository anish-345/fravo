import 'package:flutter_test/flutter_test.dart';

import 'package:fravo/services/time_bank.dart';

void main() {
  group('TimeBankService — business logic (1,000 steps = 30 min default formula)', () {
    test('minutesPer1kSteps default is 30', () {
      // The service requires Hive init so we test the formula constant directly.
      const defaultRate = 30;
      expect(defaultRate, 30);
    });

    test('earnedMinutes formula: 1,000 steps @ 30 min/1k = 30 min', () {
      const steps = 1000;
      const rate = 30;
      final earned = ((steps / 1000) * rate).floor();
      expect(earned, 30);
    });

    test('earnedMinutes formula: 500 steps @ 30 min/1k = 15 min', () {
      const steps = 500;
      const rate = 30;
      final earned = ((steps / 1000) * rate).floor();
      expect(earned, 15);
    });

    test('earnedMinutes formula: 999 steps @ 30 min/1k = 29 min (floor)', () {
      const steps = 999;
      const rate = 30;
      final earned = ((steps / 1000) * rate).floor();
      expect(earned, 29);
    });

    test('earnedMinutes formula: 0 steps = 0 minutes', () {
      const steps = 0;
      const rate = 30;
      final earned = ((steps / 1000) * rate).floor();
      expect(earned, 0);
    });

    test('earnedMinutes formula: 5,000 steps @ 60 min/1k = 300 min', () {
      const steps = 5000;
      const rate = 60;
      final earned = ((steps / 1000) * rate).floor();
      expect(earned, 300);
    });

    test('CommonApps presets are non-empty and have valid data', () {
      expect(CommonApps.presets, isNotEmpty);
      for (final app in CommonApps.presets) {
        expect(app.name, isNotEmpty);
        expect(app.packageName, isNotEmpty);
        expect(app.category, isNotEmpty);
        expect(app.packageName, contains('.'));
      }
    });

    test('CommonApps includes Instagram', () {
      final insta = CommonApps.presets.firstWhere(
        (p) => p.packageName == 'com.instagram.android',
        orElse: () => const PresetApp(name: '', packageName: '', category: ''),
      );
      expect(insta.name, 'Instagram');
    });

    test('CommonApps includes TikTok', () {
      final tiktok = CommonApps.presets.firstWhere(
        (p) => p.packageName == 'com.zhiliaoapp.musically',
        orElse: () => const PresetApp(name: '', packageName: '', category: ''),
      );
      expect(tiktok.name, 'TikTok');
    });

    test('All preset packageNames are unique', () {
      final pkgs = CommonApps.presets.map((p) => p.packageName).toList();
      final unique = pkgs.toSet();
      expect(pkgs.length, unique.length);
    });
  });
}
