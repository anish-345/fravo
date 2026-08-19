import 'dart:math';
import 'package:flutter/foundation.dart';

/// Activity modes recognized by the classifier.
enum ActivityMode {
  stationary,
  walking,
  running,
}

/// A classified step packet returned after processing sensor step deltas.
class ClassifiedStepDelta {
  final int walkingSteps;
  final int runningSteps;
  final int walkingDurationSeconds;
  final int runningDurationSeconds;
  final double walkingDistanceMeters;
  final double runningDistanceMeters;
  final double cadenceSpm;
  final ActivityMode mode;

  const ClassifiedStepDelta({
    required this.walkingSteps,
    required this.runningSteps,
    this.walkingDurationSeconds = 0,
    this.runningDurationSeconds = 0,
    this.walkingDistanceMeters = 0.0,
    this.runningDistanceMeters = 0.0,
    required this.cadenceSpm,
    required this.mode,
  });

  int get totalSteps => walkingSteps + runningSteps;
  int get totalDurationSeconds =>
      walkingDurationSeconds + runningDurationSeconds;
  int get totalDurationMinutes => (totalDurationSeconds / 60).round();
  int get walkingDurationMinutes => (walkingDurationSeconds / 60).round();
  int get runningDurationMinutes => (runningDurationSeconds / 60).round();
  double get totalDistanceMeters =>
      walkingDistanceMeters + runningDistanceMeters;
  double get totalDistanceKm => totalDistanceMeters / 1000.0;
  double get runningDistanceKm => runningDistanceMeters / 1000.0;
  double get walkingDistanceKm => walkingDistanceMeters / 1000.0;
}

/// Internal sensor sample record for windowed cadence calculation.
class _StepSample {
  final int hardwareSteps;
  final DateTime timestamp;

  _StepSample(this.hardwareSteps, this.timestamp);
}

/// Real-time biomechanical gait & cadence engine.
///
/// Calculates instantaneous and smoothed cadence (Steps Per Minute - SPM)
/// from hardware pedometer timestamps and deltas to accurately classify
/// movement into Walking (< 135 SPM) and Running (>= 135 SPM).
class ActivityClassifier {
  ActivityClassifier._();

  static final ActivityClassifier instance = ActivityClassifier._();

  /// Running cadence threshold (SPM).
  /// Typical human walking cadence: 60 - 125 SPM.
  /// Typical human running/jogging cadence: 135 - 180+ SPM.
  static const double defaultRunningThresholdSpm = 135.0;

  /// Stationary / minimum movement cadence threshold (SPM).
  static const double defaultWalkingThresholdSpm = 30.0;

  /// Maximum gap (in seconds) between sensor events to consider them part of
  /// the same continuous gait stride stream.
  static const int maxGaitGapSeconds = 12;

  final ValueNotifier<ActivityMode> currentModeNotifier =
      ValueNotifier<ActivityMode>(ActivityMode.stationary);

  final ValueNotifier<double> currentCadenceNotifier =
      ValueNotifier<double>(0.0);

  ActivityMode get currentMode => currentModeNotifier.value;
  double get currentCadence => currentCadenceNotifier.value;

  final List<_StepSample> _sampleHistory = [];
  double _smoothedCadence = 0.0;
  DateTime? _lastClassifyTime;

  /// Classifies a hardware step change and returns the walking & running step breakdown.
  ClassifiedStepDelta classifyHardwareStepDelta({
    required int previousHardwareSteps,
    required int currentHardwareSteps,
    required DateTime timestamp,
    double runningThreshold = defaultRunningThresholdSpm,
  }) {
    final stepDelta = currentHardwareSteps - previousHardwareSteps;
    if (stepDelta <= 0) {
      if (_lastClassifyTime == null) {
        _lastClassifyTime = timestamp;
        _sampleHistory.add(_StepSample(currentHardwareSteps, timestamp));
      }
      _checkStationaryDecay(timestamp);
      return ClassifiedStepDelta(
        walkingSteps: 0,
        runningSteps: 0,
        cadenceSpm: _smoothedCadence,
        mode: currentMode,
      );
    }

    // Add current sample to history
    _sampleHistory.add(_StepSample(currentHardwareSteps, timestamp));
    // Keep only samples within the last 15 seconds for responsive cadence
    final windowCutoff = timestamp.subtract(const Duration(seconds: 15));
    _sampleHistory.removeWhere((s) => s.timestamp.isBefore(windowCutoff));

    double measuredCadence = 0.0;
    if (_sampleHistory.length >= 2) {
      final first = _sampleHistory.first;
      final last = _sampleHistory.last;
      final elapsedSec =
          last.timestamp.difference(first.timestamp).inMilliseconds / 1000.0;
      final windowSteps = last.hardwareSteps - first.hardwareSteps;

      if (elapsedSec >= 0.4 && elapsedSec <= maxGaitGapSeconds && windowSteps > 0) {
        measuredCadence = (windowSteps / elapsedSec) * 60.0;
      }
    }

    // If history window did not produce a cadence, estimate from instantaneous delta with _lastClassifyTime
    if (measuredCadence <= 0.0 && _lastClassifyTime != null) {
      final elapsed =
          timestamp.difference(_lastClassifyTime!).inMilliseconds / 1000.0;
      if (elapsed >= 0.4 && elapsed <= maxGaitGapSeconds) {
        measuredCadence = (stepDelta / elapsed) * 60.0;
      }
    }

    _lastClassifyTime = timestamp;

    // Apply Exponential Moving Average (EMA) smoothing: alpha = 0.45
    if (measuredCadence > 0.0) {
      if (_smoothedCadence <= 0.0) {
        _smoothedCadence = measuredCadence;
      } else {
        _smoothedCadence = (0.45 * measuredCadence) + (0.55 * _smoothedCadence);
      }
    } else if (_smoothedCadence <= 0.0) {
      // Default to standard walking cadence if instantaneous interval is unavailable
      _smoothedCadence = 90.0;
    }

    // Clamp cadence to realistic human range (0 - 240 SPM)
    _smoothedCadence = _smoothedCadence.clamp(0.0, 240.0);

    // Classify into activity mode
    final ActivityMode mode;
    int walking = 0;
    int running = 0;

    if (_smoothedCadence >= runningThreshold) {
      mode = ActivityMode.running;
      running = stepDelta;
    } else if (_smoothedCadence >= defaultWalkingThresholdSpm) {
      mode = ActivityMode.walking;
      walking = stepDelta;
    } else {
      // Very slow movement or single step
      mode = ActivityMode.walking;
      walking = stepDelta;
    }

    currentModeNotifier.value = mode;
    currentCadenceNotifier.value = _smoothedCadence;

    // Calculate active duration in seconds for this delta packet
    int durationSec = 0;
    if (_lastClassifyTime != null) {
      final diff = timestamp.difference(_lastClassifyTime!).inSeconds;
      if (diff > 0 && diff <= maxGaitGapSeconds) {
        durationSec = diff;
      }
    }
    if (durationSec == 0 && stepDelta > 0 && _smoothedCadence > 0) {
      durationSec = max(1, ((stepDelta / _smoothedCadence) * 60).round());
    }

    final int walkingSec = (mode == ActivityMode.walking) ? durationSec : 0;
    final int runningSec = (mode == ActivityMode.running) ? durationSec : 0;
    final double walkDist = walking * 0.762;
    final double runDist = running * 1.050;

    debugPrint(
      '🏃‍♂️ Classifier: +$stepDelta steps (Walk: $walking, Run: $running) | '
      'Duration: ${durationSec}s | SPM: ${_smoothedCadence.toStringAsFixed(1)} | Mode: ${mode.name}',
    );

    return ClassifiedStepDelta(
      walkingSteps: walking,
      runningSteps: running,
      walkingDurationSeconds: walkingSec,
      runningDurationSeconds: runningSec,
      walkingDistanceMeters: walkDist,
      runningDistanceMeters: runDist,
      cadenceSpm: _smoothedCadence,
      mode: mode,
    );
  }

  /// Gradually decays cadence to 0 when user stops moving.
  void _checkStationaryDecay(DateTime now) {
    if (_lastClassifyTime != null) {
      final idleSec = now.difference(_lastClassifyTime!).inSeconds;
      if (idleSec >= 6) {
        _smoothedCadence = max(0.0, _smoothedCadence * 0.5);
        if (_smoothedCadence < 15.0) {
          _smoothedCadence = 0.0;
          currentModeNotifier.value = ActivityMode.stationary;
        }
        currentCadenceNotifier.value = _smoothedCadence;
      }
    }
  }

  /// Resets real-time classifier history on daily reset or tracking restart.
  void reset() {
    _sampleHistory.clear();
    _smoothedCadence = 0.0;
    _lastClassifyTime = null;
    currentModeNotifier.value = ActivityMode.stationary;
    currentCadenceNotifier.value = 0.0;
  }
}
