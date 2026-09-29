import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:fravo/services/time_bank.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fravo_delta_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('time_bank');
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('syncNativeUsageDelta: computes correct deltas and updates caches', () async {
    final service = TimeBankService.instance;

    // Grant 1,000 steps => 30 min earned = 1800s
    await service.updateSteps(1000);
    expect(service.earnedMinutes, 30);
    expect(service.remainingScreenTimeSeconds, 1800);

    // Initial sync after fresh reset: seeds baseline without treating preexisting native count as new usage
    await service.syncNativeUsageDelta({'com.instagram.android': 120});
    expect(service.usedSecondsTotal, 0);
    expect(service.remainingScreenTimeSeconds, 1800);

    // Subsequent sync: Instagram moves from 120s to 180s (+60s delta)
    await service.syncNativeUsageDelta({'com.instagram.android': 180});

    expect(service.usedSecondsTotal, 60);
    expect(service.usedMinutes, 1);
    expect(service.getUsedSecondsForApp('com.instagram.android'), 60);
    expect(service.remainingScreenTimeSeconds, 1800 - 60);

    // Native counter reset: service reports 30s (< 180s baseline)
    // Treats 30s as fresh delta from 0
    await service.syncNativeUsageDelta({'com.instagram.android': 30});

    expect(service.usedSecondsTotal, 60 + 30);
    expect(service.getUsedSecondsForApp('com.instagram.android'), 60 + 30);
    expect(service.remainingScreenTimeSeconds, 1800 - 90);
  });
}
