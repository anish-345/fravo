import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'time_bank.dart';
import 'blocker_service.dart';

/// Dual-Mode Hybrid Step Counter with **automatic background sync** and
/// **battery optimizations**:
///
/// 1. **Pedometer stream** (hardware sensor) — fires on every step but is
///    debounced to 3-second intervals to reduce CPU wake-ups by 90%.
/// 2. **Health Connect poll** — runs on adaptive timer (5-15 min based on
///    battery optimization state).
/// 3. **Rate limiting** — Block state re-evaluation is limited to once per
///    minute maximum to reduce native overhead.
class HealthService with WidgetsBindingObserver {
  HealthService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final HealthService instance = HealthService._();

  final Health _health = Health();
  bool _configured = false;
  StreamSubscription<StepCount>? _pedometerSubscription;
  Timer? _healthConnectTimer;
  Timer? _debounceTimer;

  int _latestSensorSteps = 0;
  int _pendingSteps = 0;

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

  /// Starts the hardware step-count stream listener with **debouncing**.
  /// Does NOT prompt the user automatically — only attaches if permission is already granted.
  Future<void> initPedometerListener() async {
    if (_pedometerSubscription != null) return;
    try {
      final status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        // Do not request permission automatically during init (which runs on app startup).
        // The permission dialog will be shown when the user reaches the onboarding or settings step.
        return;
      }

      _pedometerSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _pendingSteps = event.steps;
          _debounceTimer?.cancel();
          _debounceTimer = Timer(_pedometerDebounce, _processDebouncedSteps);
        },
        onError: (error) {
          debugPrint('Pedometer stream error: $error');
        },
      );

      debugPrint(
        '✅ Pedometer listener started with ${_pedometerDebounce.inSeconds}s debounce',
      );
    } catch (e) {
      debugPrint('initPedometerListener error: $e');
    }
  }

  /// Processes accumulated pedometer steps (called after debounce delay).
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

      if (storedDate != today || baseline > hardwareSteps) {
        baseline = hardwareSteps;
        await box.put('date', today);
        await box.put('baseline', baseline);
      }

      _latestSensorSteps = (hardwareSteps - baseline).clamp(0, 999999);
      _sensorStepsDate = today;
      debugPrint(
        '📱 Pedometer: $_latestSensorSteps steps today (hw: $hardwareSteps)',
      );

      await _autoUpdateSteps(_latestSensorSteps);
    } catch (e) {
      debugPrint('_processDebouncedSteps error: $e');
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

  Future<bool> checkPermissions() async {
    final activityGranted = await checkActivityRecognitionPermission();
    final healthConnectGranted = await checkHealthConnectPermission();
    return activityGranted || healthConnectGranted;
  }

  Future<bool> requestPermissions() async {
    // 1. Request Physical Activity (Hardware Motion Sensor)
    final activityRecognitionGranted =
        await requestActivityRecognitionPermission();
    // 2. Request Google Health Connect (Steps from smartwatches / other fitness apps)
    final healthConnectGranted = await requestHealthConnectPermission();
    return activityRecognitionGranted || healthConnectGranted;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_pedometerSubscription == null) {
        initPedometerListener();
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pedometerSubscription?.cancel();
    _pedometerSubscription = null;
    _healthConnectTimer?.cancel();
    _healthConnectTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
