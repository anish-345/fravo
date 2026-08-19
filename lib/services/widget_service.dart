import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Centralized service to update Android & iOS Home Screen Widgets with Fravo dashboard data.
class WidgetService {
  WidgetService._privateConstructor();
  static final WidgetService instance = WidgetService._privateConstructor();

  static const String androidWidgetProviderName = 'FravoWidgetProvider';
  static const String iosWidgetKindName = 'FravoWidget';

  /// Save current dashboard statistics to widget storage and trigger a refresh.
  Future<void> updateWidgetData({
    required int steps,
    required int stepGoal,
    required int earnedMinutes,
    required int usedMinutes,
    required int remainingMinutes,
    required bool isPremium,
    String? selectedAppPackage,
    String? selectedAppName,
  }) async {
    if (kIsWeb) return;

    try {
      final formattedSteps = _formatNumber(steps);
      final formattedGoal = _formatNumber(stepGoal);
      final formattedEarned = _formatMinutes(earnedMinutes);
      final formattedUsed = _formatMinutes(usedMinutes);
      final formattedRemaining = _formatMinutes(remainingMinutes);

      // Progress percentages
      final double stepProgress = stepGoal > 0 ? (steps / stepGoal).clamp(0.0, 1.0) : 0.0;
      final int stepProgressPercent = (stepProgress * 100).round();

      final double remainingTimeProgress = earnedMinutes > 0
          ? (remainingMinutes / earnedMinutes).clamp(0.0, 1.0)
          : 0.0;
      final int remainingProgressPercent = (remainingTimeProgress * 100).round();

      // Save data for Android RemoteViews / iOS WidgetKit
      await HomeWidget.saveWidgetData<String>('fravo_steps', formattedSteps);
      await HomeWidget.saveWidgetData<String>('fravo_step_goal', formattedGoal);
      await HomeWidget.saveWidgetData<String>('fravo_time_earned', formattedEarned);
      await HomeWidget.saveWidgetData<String>('fravo_time_used', formattedUsed);
      await HomeWidget.saveWidgetData<String>('fravo_time_remaining', formattedRemaining);
      
      await HomeWidget.saveWidgetData<int>('fravo_step_progress', stepProgressPercent);
      await HomeWidget.saveWidgetData<int>('fravo_time_progress', remainingProgressPercent);
      await HomeWidget.saveWidgetData<bool>('fravo_is_premium', isPremium);
      
      await HomeWidget.saveWidgetData<String>(
        'fravo_selected_app_package',
        selectedAppPackage ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'fravo_selected_app_name',
        selectedAppName ?? 'Blocked Apps',
      );

      // Trigger update
      await HomeWidget.updateWidget(
        name: androidWidgetProviderName,
        iOSName: iosWidgetKindName,
      );

      if (kDebugMode) {
        print('[WidgetService] Home widget updated: steps=$formattedSteps, remaining=$formattedRemaining, app=$selectedAppName, isPremium=$isPremium');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WidgetService] Error updating home widget: $e');
      }
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }
}
