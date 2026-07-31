import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'time_bank.dart';
import 'blocker_service.dart';

/// Dual-Mode Hybrid Step Counter with **automatic background sync**:
///
/// 1. **Pedometer stream** (hardware sensor) — fires on every step, updates
///    the time-bank instantly with no user interaction needed.
/// 2. **Health Connect poll** — runs on a 5-minute timer for higher accuracy.
/// 3. Both sources de-duplicate against the last known value, so only genuine
///    step increases trigger a budget re-evaluation.
class HealthService {
  HealthService._();

  static final HealthService instance = HealthService._();

  final Health _health = Health();
  bool _configured = false;
  StreamSubscription<StepCount>? _pedometerSubscription;
  Timer? _healthConnectTimer;

  int _latestSensorSteps = 0;
  /// Last step count we actually pushed to TimeBankService (avoids redundant calls).
  int _lastPushedSteps = 0;

  static const List<HealthDataType> _types = [HealthDataType.STEPS];

  /// Minimum step increase before we bother re-evaluating block state.
  /// Avoids hammering the native layer on every single step.
  static const int _minStepDeltaForEval = 10;

  // ── Configuration ─────────────────────────────────────────────────────────

  Future<bool> _ensureConfigured() async {
    if (_configured) return true;
    try {
      await _health.configure();
      _configured = true;
    } catch (e) {
      debugPrint('Health.configure error: $e');
    }
    return _configured;
  }

  // ── Pedometer (hardware sensor, instant) ──────────────────────────────────

  /// Starts the hardware step-count stream listener.
  /// On each new step event, automatically updates TimeBankService and
  /// re-evaluates the block state if the step delta is large enough.
  Future<void> initPedometerListener() async {
    if (_pedometerSubscription != null) return;
    try {
      final status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        final req = await Permission.activityRecognition.request();
        if (!req.isGranted) return;
      }

      _pedometerSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) async {
          final totalHardwareSteps = event.steps;
          final now = DateTime.now();
          final todayStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

          final box = await Hive.openBox('pedometer_store');
          final storedDate = box.get('date') as String?;
          int baseline = (box.get('baseline') as int?) ?? totalHardwareSteps;

          if (storedDate != todayStr || baseline > totalHardwareSteps) {
            baseline = totalHardwareSteps;
            await box.put('date', todayStr);
            await box.put('baseline', baseline);
          }

          _latestSensorSteps = (totalHardwareSteps - baseline).clamp(0, 999999);
          debugPrint(
              'Pedometer live: $_latestSensorSteps steps today (hw total: $totalHardwareSteps).');

          // ── Auto-push to TimeBankService ───────────────────────────────
          await _autoUpdateSteps(_latestSensorSteps);
        },
        onError: (error) {
          debugPrint('Pedometer stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('initPedometerListener error: $e')  ;
    }
  }

  // ── Health Connect poll (every 5 minutes, higher accuracy) ───────────────

  /// Starts a periodic Health Connect fetch every 5 minutes.
  /// Call once at startup after permissions are granted.
  void startAutoHealthSync() {
    _healthConnectTimer?.cancel();
    _healthConnectTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      debugPrint('HealthService: Auto Health Connect sync triggered.');
      await _syncFromHealthConnect();
    });
    // Also sync immediately on start
    _syncFromHealthConnect();
  }

  Future<void> _syncFromHealthConnect() async {
    try {
      final steps = await _fetchHealthConnectSteps();
      if (steps > 0) {
        await _autoUpdateSteps(steps);
      }
    } catch (e) {
      debugPrint('HealthService._syncFromHealthConnect error: $e');
    }
  }

  /// Pushes [newSteps] to TimeBankService and re-evaluates the block state if
  /// the step delta exceeds [_minStepDeltaForEval]. Safe to call frequently.
  Future<void> _autoUpdateSteps(int newSteps) async {
    final timeBank = TimeBankService.instance;
    final prevEarned = timeBank.earnedMinutes;

    await timeBank.updateSteps(newSteps);

    final newEarned = timeBank.earnedMinutes;
    final stepDelta = newSteps - _lastPushedSteps;

    // Re-evaluate block state only when earned minutes actually changed OR
    // the step delta crosses the threshold (avoids per-step native calls).
    if (newEarned != prevEarned || stepDelta >= _minStepDeltaForEval) {
      _lastPushedSteps = newSteps;
      try {
        await BlockerService.instance.evaluateBlockState();
      } catch (e) {
        debugPrint('HealthService._autoUpdateSteps evaluateBlockState error: $e');
      }
    }
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  /// Requests both Health Connect and Activity Recognition permissions,
  /// then starts the auto-sync timer.
  Future<bool> requestPermissions() async {
    bool healthConnectGranted = false;
    try {
      await _ensureConfigured();
      healthConnectGranted = await _health.requestAuthorization(
        _types,
        permissions: List.filled(_types.length, HealthDataAccess.READ),
      );
    } catch (e) {
      debugPrint('Health Connect authorization error: $e');
    }

    bool activityRecognitionGranted = false;
    try {
      final status = await Permission.activityRecognition.request();
      activityRecognitionGranted = status.isGranted;
      if (activityRecognitionGranted) {
        await initPedometerListener();
      }
    } catch (e) {
      debugPrint('Activity recognition permission error: $e');
    }

    if (healthConnectGranted || activityRecognitionGranted) {
      startAutoHealthSync();
    }

    return healthConnectGranted || activityRecognitionGranted;
  }

  // ── Step fetching ─────────────────────────────────────────────────────────

  /// Internal: fetch steps from Health Connect only (no pedometer fallback).
  Future<int> _fetchHealthConnectSteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      await _ensureConfigured();

      final hasPermission = await _health.hasPermissions(
        _types,
        permissions: List.filled(_types.length, HealthDataAccess.READ),
      );

      if (hasPermission == true) {
        final stepsInterval = await _health.getTotalStepsInInterval(midnight, now);
        debugPrint('getTotalStepsInInterval → $stepsInterval steps.');
        if (stepsInterval != null && stepsInterval > 0) return stepsInterval;

        // Raw query fallback
        final rawData = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: _types,
        );
        int rawTotal = 0;
        for (final point in rawData) {
          if (point.type == HealthDataType.STEPS) {
            final value = point.value;
            if (value is NumericHealthValue) rawTotal += value.numericValue.toInt();
          }
        }
        if (rawTotal > 0) return rawTotal;
      }
    } catch (e) {
      debugPrint('Health Connect fetch error: $e');
    }
    return 0;
  }

  /// Public: fetches today's steps using all available sources.
  /// Dual-Mode Hybrid strategy:
  /// 1. Health Connect (most accurate)
  /// 2. Physical hardware pedometer sensor (fallback)
  Future<int> fetchTodaySteps() async {
    await initPedometerListener();
    final hcSteps = await _fetchHealthConnectSteps();
    if (hcSteps > 0) return hcSteps;
    if (_latestSensorSteps > 0) {
      debugPrint('Using live pedometer steps: $_latestSensorSteps');
      return _latestSensorSteps;
    }
    debugPrint('All step sources returned 0.');
    return 0;
  }

  void dispose() {
    _pedometerSubscription?.cancel();
    _healthConnectTimer?.cancel();
  }
}
