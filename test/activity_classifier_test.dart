import 'package:flutter_test/flutter_test.dart';
import 'package:fravo/services/activity_classifier.dart';

void main() {
  group('ActivityClassifier Tests', () {
    late ActivityClassifier classifier;

    setUp(() {
      classifier = ActivityClassifier.instance;
      classifier.reset();
    });

    test('Initial state is stationary with 0 SPM', () {
      expect(classifier.currentMode, ActivityMode.stationary);
      expect(classifier.currentCadence, 0.0);
    });

    test('Classifies normal walking cadence (< 135 SPM)', () {
      final t0 = DateTime(2026, 8, 19, 10, 0, 0);
      final t1 = t0.add(const Duration(seconds: 3));

      // 5 steps in 3 seconds = (5 / 3) * 60 = 100 SPM (Brisk walk)
      final result = classifier.classifyHardwareStepDelta(
        previousHardwareSteps: 1000,
        currentHardwareSteps: 1005,
        timestamp: t1,
      );

      expect(result.walkingSteps, 5);
      expect(result.runningSteps, 0);
      expect(result.mode, ActivityMode.walking);
      expect(result.cadenceSpm, greaterThanOrEqualTo(80.0));
      expect(result.cadenceSpm, lessThan(135.0));
    });

    test('Classifies running cadence (>= 135 SPM)', () {
      final t0 = DateTime(2026, 8, 19, 10, 0, 0);
      // Seed first sample
      classifier.classifyHardwareStepDelta(
        previousHardwareSteps: 1000,
        currentHardwareSteps: 1000,
        timestamp: t0,
      );

      final t1 = t0.add(const Duration(seconds: 2));
      // 6 steps in 2 seconds = (6 / 2) * 60 = 180 SPM (Running)
      final result = classifier.classifyHardwareStepDelta(
        previousHardwareSteps: 1000,
        currentHardwareSteps: 1006,
        timestamp: t1,
      );

      expect(result.runningSteps, 6);
      expect(result.walkingSteps, 0);
      expect(result.mode, ActivityMode.running);
      expect(result.cadenceSpm, greaterThanOrEqualTo(135.0));
    });

    test('Calculates running distance and duration accurately', () {
      final t0 = DateTime(2026, 8, 19, 10, 0, 0);
      classifier.classifyHardwareStepDelta(
        previousHardwareSteps: 1000,
        currentHardwareSteps: 1000,
        timestamp: t0,
      );

      final t1 = t0.add(const Duration(seconds: 4));
      // 12 steps in 4 seconds = 180 SPM (Running)
      final result = classifier.classifyHardwareStepDelta(
        previousHardwareSteps: 1000,
        currentHardwareSteps: 1012,
        timestamp: t1,
      );

      expect(result.mode, ActivityMode.running);
      expect(result.runningSteps, 12);
      expect(result.runningDurationSeconds, 4);
      // 12 steps * 1.05m = 12.6 meters
      expect(result.runningDistanceMeters, closeTo(12.6, 0.01));
      expect(result.runningDistanceKm, closeTo(0.0126, 0.0001));
    });

    test('Calculates walking distance and duration accurately', () {
      final t0 = DateTime(2026, 8, 19, 10, 0, 0);
      classifier.classifyHardwareStepDelta(
        previousHardwareSteps: 1000,
        currentHardwareSteps: 1000,
        timestamp: t0,
      );

      final t1 = t0.add(const Duration(seconds: 5));
      // 8 steps in 5 seconds = 96 SPM (Walking)
      final result = classifier.classifyHardwareStepDelta(
        previousHardwareSteps: 1000,
        currentHardwareSteps: 1008,
        timestamp: t1,
      );

      expect(result.mode, ActivityMode.walking);
      expect(result.walkingSteps, 8);
      expect(result.walkingDurationSeconds, 5);
      // 8 steps * 0.762m = 6.096 meters
      expect(result.walkingDistanceMeters, closeTo(6.096, 0.01));
    });
  });
}
