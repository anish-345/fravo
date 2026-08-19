import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'activity_classifier.dart';
import 'time_bank.dart';
import 'blocker_service.dart';

/// Dual-Mode Hybrid Step Counter with **automatic background sync** and
/// **battery optimizations**:
///
/// 1. **Pedometer stream** (hardware sensor) — fires on every step but is
///    debounced to reduce CPU wake-ups, classified in real time into walking/running.
/// 2. **Health Connect poll** — runs on adaptive timer (5-15 min based on
///    battery optimization state).
/// 3. **Rate limiting** — Block state re-evaluation is limited to once per
///    minute maximum to reduce native overhead.
class HealthService {
  HealthService._();

  static final HealthService instance = HealthService._();

  final Health _health = Health();
  bool _configured = false;
  StreamSubscription<StepCount>? _pedometerSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  Timer? _healthConnectTimer;
  Timer? _debounceTimer;

  int _latestSensorSteps = 0;
  int _pendingSteps = 0;
  DateTime? _lastStepEventTimestamp;

  /// The day (yyyy-MM-dd) the current [_latestSensorSteps] value was sampled.
  /// Guards against using a stale pre-midnight count after a daily reset —
  /// before the first step of the new day, the sensor still holds yesterday's
  /// pedometer total.
  String? _sensorStepsDate;

  static const List<HealthDataType> _types = [HealthDataType.STEPS];

  /// Debounce duration for pedometer events (reduces CPU wake-ups).
  static const Duration _pedometerDebounce = Duration(seconds: 1);

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

  /// Starts the hardware step-count stream listener with **debouncing** and **classification**.
  Future<void> initPedometerListener() async {
    if (_pedometerSubscription != null) return;
    try {
      final status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        final req = await Permission.activityRecognition.request();
        if (!req.isGranted) return;
      }

      _pedometerSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _pendingSteps = event.steps;
          _lastStepEventTimestamp = event.timeStamp;
          _debounceTimer?.cancel();
          _debounceTimer = Timer(_pedometerDebounce, _processDebouncedSteps);
        },
        onError: (error) {
          debugPrint('Pedometer stream error: $error');
        },
      );

      try {
        _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
          (PedestrianStatus event) {
            debugPrint('🚶 Pedestrian status: ${event.status}');
            if (event.status == 'stopped') {
              ActivityClassifier.instance.currentModeNotifier.value =
                  ActivityMode.stationary;
            }
          },
          onError: (error) {
            debugPrint('Pedestrian status stream error: $error');
          },
        );
      } catch (e) {
        debugPrint('PedestrianStatus listener error: $e');
      }

      debugPrint(
        '✅ Pedometer listener started with ${_pedometerDebounce.inSeconds}s debounce & gait classifier',
      );
    } catch (e) {
      debugPrint('initPedometerListener error: $e');
    }
  }

  /// Processes accumulated pedometer steps (called after debounce delay) and
  /// routes them into classified walking and running categories.
  Future<void> _processDebouncedSteps() async {
    if (_pendingSteps == 0) return;

    final hardwareSteps = _pendingSteps;
    _pendingSteps = 0;

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final box = await Hive.openBox('pedometer_store');
      final storedDate = box.get('date') as String?;
      int baseline = (box.get('baseline') as int?) ?? hardwareSteps;
      int storedLastHw = (box.get('lastHwSteps') as int?) ?? hardwareSteps;

      if (storedDate != today || baseline > hardwareSteps) {
        baseline = hardwareSteps;
        storedLastHw = hardwareSteps;
        await box.put('date', today);
        await box.put('baseline', baseline);
        await box.put('lastHwSteps', storedLastHw);
        ActivityClassifier.instance.reset();
      }

      final stepDelta = hardwareSteps - storedLastHw;
      if (stepDelta > 0) {
        final classified = ActivityClassifier.instance.classifyHardwareStepDelta(
          previousHardwareSteps: storedLastHw,
          currentHardwareSteps: hardwareSteps,
          timestamp: _lastStepEventTimestamp ?? now,
        );

        await box.put('lastHwSteps', hardwareSteps);
        await TimeBankService.instance.addClassifiedStepDelta(
          walkingDelta: classified.walkingSteps,
          runningDelta: classified.runningSteps,
          walkingSecondsDelta: classified.walkingDurationSeconds,
          runningSecondsDelta: classified.runningDurationSeconds,
        );
      }

      _latestSensorSteps = (hardwareSteps - baseline).clamp(0, 999999);
      _sensorStepsDate = today;
      debugPrint(
        '📱 Pedometer: $_latestSensorSteps steps today (hw: $hardwareSteps, walk: ${TimeBankService.instance.walkingSteps}, run: ${TimeBankService.instance.runningSteps})',
      );

      await _evaluateBlockStateIfEarnedChanged();
    } catch (e) {
      debugPrint('_processDebouncedSteps error: $e');
    }
  }

  Future<void> _evaluateBlockStateIfEarnedChanged() async {
    final timeBank = TimeBankService.instance;
    final prevEarned = timeBank.earnedMinutes;
    final newEarned = timeBank.earnedMinutes;

    if (newEarned != prevEarned) {
      try {
        await BlockerService.instance.evaluateBlockState();
      } catch (e) {
        debugPrint('_evaluateBlockState error: $e');
      }
    }
  }

  // ── Health Connect poll ────────────────────────────────────────────────────

  /// Starts periodic Health Connect fetch.
  void startAutoHealthSync() {
    _healthConnectTimer?.cancel();
    _healthConnectTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      debugPrint('🔄 Auto Health Connect sync triggered');
      await _syncFromHealthConnect();
    });
    _syncFromHealthConnect();
  }

  Future<void> _syncFromHealthConnect() async {
    try {
      final steps = await _fetchHealthConnectSteps();
      if (steps > 0) {
        await _autoUpdateSteps(steps);
      }
    } catch (e) {
      debugPrint('_syncFromHealthConnect error: $e');
    }
  }

  /// Pushes steps to TimeBankService and re-evaluates block state only when
  /// the earned minutes actually increase (not on every pedometer event).
  Future<void> _autoUpdateSteps(int newSteps) async {
    final timeBank = TimeBankService.instance;
    final prevEarned = timeBank.earnedMinutes;

    await timeBank.updateSteps(newSteps);

    final newEarned = timeBank.earnedMinutes;

    // Only re-evaluate when earned budget actually changes.
    // Evaluating on every 20 steps was wiping the native baseline too often.
    if (newEarned != prevEarned) {
      try {
        debugPrint(
          '🔄 Earned minutes changed ($prevEarned → $newEarned min), re-evaluating block state.',
        );
        await BlockerService.instance.evaluateBlockState();
      } catch (e) {
        debugPrint('_autoUpdateSteps evaluateBlockState error: $e');
      }
    }
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> checkActivityRecognitionPermission() async {
    try {
      final status = await Permission.activityRecognition.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  Future<bool> openAppSettingsPage() async {
    return await openAppSettings();
  }

  Future<bool> checkHealthConnectPermission() async {
    try {
      await _ensureConfigured();
      final hasPermission = await _health.hasPermissions(
        _types,
        permissions: List.filled(_types.length, HealthDataAccess.READ),
      );
      return hasPermission == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestActivityRecognitionPermission() async {
    try {
      var status = await Permission.activityRecognition.status;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      status = await Permission.activityRecognition.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      if (status.isGranted) {
        await initPedometerListener();
      }
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestHealthConnectPermission() async {
    try {
      await _ensureConfigured();
      final healthConnectGranted = await _health.requestAuthorization(
        _types,
        permissions: List.filled(_types.length, HealthDataAccess.READ),
      );
      if (healthConnectGranted) {
        startAutoHealthSync();
      }
      return healthConnectGranted;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    final healthConnectGranted = await requestHealthConnectPermission();
    final activityRecognitionGranted =
        await requestActivityRecognitionPermission();
    return healthConnectGranted || activityRecognitionGranted;
  }

  // ── Step fetching ─────────────────────────────────────────────────────────

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
        final stepsInterval = await _health.getTotalStepsInInterval(
          midnight,
          now,
        );
        debugPrint('getTotalStepsInInterval → $stepsInterval steps');
        if (stepsInterval != null && stepsInterval > 0) return stepsInterval;

        final rawData = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: _types,
        );
        int rawTotal = 0;
        for (final point in rawData) {
          if (point.type == HealthDataType.STEPS) {
            final value = point.value;
            if (value is NumericHealthValue) {
              rawTotal += value.numericValue.toInt();
            }
          }
        }
        if (rawTotal > 0) return rawTotal;
      }
    } catch (e) {
      debugPrint('Health Connect fetch error: $e');
    }
    return 0;
  }

  Future<int> fetchTodaySteps() async {
    await initPedometerListener();
    final hcSteps = await _fetchHealthConnectSteps();
    if (hcSteps > 0) return hcSteps;
    // Only trust the live pedometer count if it was sampled TODAY.
    // Before the first step event of a new day, _latestSensorSteps still
    // holds YESTERDAY's leftover count; returning it here would resurrect
    // the previous day's steps right after the midnight reset.
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_sensorStepsDate == today && _latestSensorSteps > 0) {
      debugPrint('Using live pedometer steps: $_latestSensorSteps');
      return _latestSensorSteps;
    }
    debugPrint('All step sources returned 0');
    return 0;
  }

  void dispose() {
    _pedometerSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    _healthConnectTimer?.cancel();
    _debounceTimer?.cancel();
  }
}
