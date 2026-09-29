import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:fravo/services/time_bank.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fravo_midnight_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('time_bank');
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Daily reset: date rollover detection and clean reset', () async {
    final box = Hive.box('time_bank');
    
    // Simulate yesterday's state
    const yesterday = '2026-09-23';
    await box.put('lastResetDay', yesterday);
    await box.put('totalStepsWalked', 5000);
    await box.put('usedMinutes', 45);
    await box.put('usedSecondsTotal', 2700);
    await box.put('emergencyPassCountToday', 1);

    // Verify isDailyResetDue is true because date is in the past
    expect(TimeBankService.instance.isDailyResetDue, isTrue);

    // While reset is due, getters must return 0 to prevent yesterday's numbers leaking
    expect(TimeBankService.instance.totalStepsWalked, 0);
    expect(TimeBankService.instance.usedMinutes, 0);
    expect(TimeBankService.instance.usedSecondsTotal, 0);
    expect(TimeBankService.instance.emergencyPassCountToday, 0);

    // Now execute resetDailyIfNeeded
    await TimeBankService.instance.resetDailyIfNeeded();

    // Verify isDailyResetDue is now false
    expect(TimeBankService.instance.isDailyResetDue, isFalse);

    // Verify yesterday's data was archived properly to 7-day history
    final history = TimeBankService.instance.dailyHistory;
    expect(history, isNotEmpty);
    final archived = history.firstWhere((r) => r.date == yesterday);
    expect(archived.steps, 5000);
    expect(archived.usedMinutes, 45);

    // Now update steps on the fresh day
    await TimeBankService.instance.updateSteps(350);
    expect(TimeBankService.instance.totalStepsWalked, 350);
    expect(TimeBankService.instance.earnedMinutes, 10); // 350 / 1000 * 30 = 10
  });

  test('updateSteps automatically resets if called before explicit resetDailyIfNeeded', () async {
    final box = Hive.box('time_bank');

    // Simulate yesterday's state
    const yesterday = '2026-09-23';
    await box.put('lastResetDay', yesterday);
    await box.put('totalStepsWalked', 8000);
    await box.put('usedMinutes', 60);

    expect(TimeBankService.instance.isDailyResetDue, isTrue);

    // Suppose user walks 200 steps in the morning and updateSteps is called first
    await TimeBankService.instance.updateSteps(200);

    // The reset should have completed inside updateSteps:
    expect(TimeBankService.instance.isDailyResetDue, isFalse);
    expect(TimeBankService.instance.totalStepsWalked, 200);

    // And yesterday's 8000 steps should have been properly archived
    final history = TimeBankService.instance.dailyHistory;
    final archived = history.firstWhere((r) => r.date == yesterday);
    expect(archived.steps, 8000);
    expect(archived.usedMinutes, 60);
  });
}
