import 'dart:io';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/health_service.dart';
import '../services/time_bank.dart';
import '../widgets/app_selector_sheet.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  final _timeBank = TimeBankService.instance;

  /// Key for the hidden RepaintBoundary that renders the share card.
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _refreshSteps() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final steps = await HealthService.instance.fetchTodaySteps();
      await _timeBank.updateSteps(steps);
      if (mounted && steps == 0) {
        setState(() {
          _errorMessage =
              'No steps detected yet — enable Physical Activity '
              'tracking, walk a few minutes, then refresh again.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to refresh: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Formatters ─────────────────────────────────────────────────────────────

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
    return steps.toString();
  }

  /// Average stride length ~0.762 m (adult average).
  double _stepsToKm(int steps) => (steps * 0.762) / 1000;

  /// Approx calories: steps × 0.04 kcal (walking estimate).
  int _stepsToCalories(int steps) => (steps * 0.04).round();

  /// Approx active minutes: steps / 100 (100 steps/min brisk walk).
  int _stepsToActiveMinutes(int steps) => (steps / 100).round();

  double get _progressRatio {
    final earned = _timeBank.earnedMinutes;
    final used = _timeBank.usedMinutes;
    if (earned <= 0) return 0;
    return (used / earned).clamp(0.0, 1.0);
  }

  // ── Custom Step Goal Selector ──────────────────────────────────────────────

  void _showStepGoalDialog() {
    final goals = [5000, 6000, 8000, 10000, 12000, 15000];
    int selected = _timeBank.customStepGoal;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Text('🎯 ', style: TextStyle(fontSize: 22)),
              Text(
                'Daily Step Goal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: goals.map((g) {
              final isSelected = selected == g;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setLocal(() => selected = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : const Color(0xFFEDF2F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF10B981)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          g >= 1000
                              ? '${(g / 1000).toStringAsFixed(0)}k steps'
                              : '$g steps',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : const Color(0xFF1A202C),
                          ),
                        ),
                        const Spacer(),
                        if (g == 10000)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF4A90E2,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF4A90E2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              onPressed: () async {
                await _timeBank.setCustomStepGoal(selected);
                if (ctx.mounted) {
                  setState(() {});
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Set Goal'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Share Achievement Card ─────────────────────────────────────────────────

  /// Renders the Fravo progress card off-screen as a PNG and opens the
  /// native share sheet directly, so the tap is one step to sharing.
  Future<void> _shareProgress() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      // Make sure the hidden card has been painted this frame before capture.
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _shareCardKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('PNG encoding failed');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/fravo_progress_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'I traded my steps for screen time today! 🏃📵',
        ),
      );
    } catch (e) {
      debugPrint('Share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share — please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _timeBank.totalStepsWalked;
    final earned = _timeBank.earnedMinutes;
    final used = _timeBank.usedMinutes;
    final remaining = _timeBank.remainingScreenTime;
    final minutesPer1k = _timeBank.minutesPer1kSteps;
    final blockedApps = _timeBank.blockedPackageDisplayNames;
    final goal = _timeBank.customStepGoal;
    final streak = _timeBank.currentStreakDays;

    final distanceKm = _stepsToKm(steps);
    final calories = _stepsToCalories(steps);
    final activeMin = _stepsToActiveMinutes(steps);

    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFECF0F5),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A202C),
              size: 18,
            ),
          ),
        ),
        title: Column(
          children: [
            const Text(
              'My Stats',
              style: TextStyle(
                color: Color(0xFF1A202C),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              today,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _isLoading ? null : _refreshSteps,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4A90E2),
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF4A90E2),
                      size: 18,
                    ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        _errorBanner(_errorMessage!),
                        const SizedBox(height: 12),
                      ],

                      // ── Anti-Bedrot Streak Banner ────────────────────────
                      if (streak > 0) ...[
                        _buildStreakBanner(streak),
                        const SizedBox(height: 12),
                      ],

                      // ── 7-Day Activity ───────────────────────────────────
                      _buildWeeklyChart(),
                      const SizedBox(height: 14),

                      // ── Steps & Distance Row ─────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _buildStepsCard(steps, minutesPer1k, goal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDistanceCard(distanceKm, steps),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Activity Stats Row (3 tiles) ─────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _metricTile(
                              icon: Icons.local_fire_department_rounded,
                              color: const Color(0xFFF59E0B),
                              label: 'Calories',
                              value: '$calories',
                              unit: 'kcal',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricTile(
                              icon: Icons.timer_outlined,
                              color: const Color(0xFF10B981),
                              label: 'Active',
                              value: '$activeMin',
                              unit: 'min',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricTile(
                              icon: Icons.trending_up_rounded,
                              color: const Color(0xFF4A90E2),
                              label: 'Goal',
                              value:
                                  '${((steps / goal) * 100).clamp(0, 100).toInt()}',
                              unit: '%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Screen Time Breakdown ────────────────────────────
                      _buildScreenTimeBreakdown(earned, used, remaining),
                      const SizedBox(height: 14),

                      // ── Reward Rate ──────────────────────────────────────
                      _buildRewardRateCard(steps, minutesPer1k),
                      const SizedBox(height: 14),

                      // ── Blocked Apps ─────────────────────────────────────
                      if (blockedApps.isNotEmpty) ...[
                        _buildBlockedAppsCard(blockedApps),
                        const SizedBox(height: 14),
                      ],

                      // ── Share Achievement Card ────────────────────────────
                      _buildShareButton(steps, earned, used, streak),
                      const SizedBox(height: 14),

                      // ── Motivational Tip ─────────────────────────────────
                      _buildMotivationalTip(steps, goal),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Hidden RepaintBoundary rendering the share card off-screen so it
          // can be captured to PNG and shared via the native share sheet.
          Positioned(
            top: 100000,
            left: 0,
            child: IgnorePointer(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 36,
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: _ShareStatCard(
                    steps: steps,
                    earnedMinutes: earned,
                    usedMinutes: used,
                    streak: streak,
                    minutesPer1k: minutesPer1k,
                    goal: goal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Streak Banner ─────────────────────────────────────────────────────────

  Widget _buildStreakBanner(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak-Day Anti-Bedrot Streak!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak == 1
                      ? 'Day 1! Keep walking, stop the scroll. 💪'
                      : 'You\'re on a roll — don\'t break the chain!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '🏆 $streak',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Screen Time Hero ────────────────────────────────────────────────────────

  // ── Steps Card ───────────────────────────────────────────────────────────

  Widget _buildStepsCard(int steps, int minutesPer1k, int goal) {
    final ratio = (steps / goal).clamp(0.0, 1.0);

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBadge(Icons.directions_walk_rounded, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          Text(
            _formatSteps(steps),
            style: const TextStyle(
              color: Color(0xFF1A202C),
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const Text(
            'steps today',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, val, _) => LinearProgressIndicator(
                value: val,
                minHeight: 7,
                backgroundColor: const Color(0xFFEDF2F7),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _showStepGoalDialog,
            child: Row(
              children: [
                Text(
                  '${(ratio * 100).toInt()}% of ${goal >= 1000 ? '${(goal / 1000).toStringAsFixed(0)}k' : '$goal'} goal',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit_rounded,
                  size: 11,
                  color: Color(0xFF4A90E2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Distance Card ────────────────────────────────────────────────────────

  Widget _buildDistanceCard(double km, int steps) {
    final metres = (km * 1000).round();
    final displayKm = km >= 1.0;

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBadge(Icons.route_rounded, const Color(0xFF8B5CF6)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                displayKm ? km.toStringAsFixed(2) : '$metres',
                style: const TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                displayKm ? 'km' : 'm',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Text(
            'distance walked',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Distance milestones
          _distanceMilestone(km),
        ],
      ),
    );
  }

  Widget _distanceMilestone(double km) {
    final double nextMilestone;
    final String milestoneName;

    if (km < 1) {
      nextMilestone = 1;
      milestoneName = '1 km';
    } else if (km < 5) {
      nextMilestone = 5;
      milestoneName = '5 km';
    } else if (km < 10) {
      nextMilestone = 10;
      milestoneName = '10 km';
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '🏅 Milestone reached!',
          style: TextStyle(
            color: Color(0xFF8B5CF6),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final remaining = ((nextMilestone - km) * 1000).round();
    return Text(
      '${remaining}m to $milestoneName',
      style: const TextStyle(
        color: Color(0xFF8B5CF6),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ── Metric Tile ──────────────────────────────────────────────────────────

  Widget _metricTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String unit,
  }) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Color(0xFF1A202C),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── 7-Day Weekly Trend Chart ──────────────────────────────────────────────

  Widget _buildWeeklyChart() {
    final history = _timeBank.dailyHistory;
    final goal = _timeBank.customStepGoal;

    // Build last 7 data points. Today is always shown even if not in history.
    final now = DateTime.now();
    final List<_DayData> days = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final isToday = i == 0;

      if (isToday) {
        days.add(
          _DayData(
            label: 'Today',
            steps: _timeBank.totalStepsWalked,
            earned: _timeBank.earnedMinutes,
          ),
        );
      } else {
        final record = history.where((r) => r.date == dateStr).firstOrNull;
        days.add(
          _DayData(
            label: DateFormat('EEE').format(date),
            steps: record?.steps ?? 0,
            earned: record?.earnedMinutes ?? 0,
          ),
        );
      }
    }

    final maxSteps = days.fold<int>(
      goal,
      (prev, d) => d.steps > prev ? d.steps : prev,
    );

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.bar_chart_rounded, const Color(0xFF6366F1)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Activity',
                      style: TextStyle(
                        color: Color(0xFF1A202C),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Steps per day vs your goal',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: history.isEmpty && _timeBank.totalStepsWalked == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          color: const Color(0xFF64748B).withValues(alpha: 0.4),
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Walk today to start your history!',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxSteps.toDouble() * 1.2,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, gi, rod, ri) {
                            final d = days[group.x.toInt()];
                            return BarTooltipItem(
                              '${d.label}\n${_formatSteps(d.steps)} steps',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= days.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  days[idx].label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: idx == 6
                                        ? const Color(0xFF4A90E2)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              );
                            },
                            reservedSize: 22,
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: goal.toDouble(),
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.25),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: days.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final d = entry.value;
                        final metGoal = d.steps >= goal;
                        final isToday = idx == 6;
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: d.steps.toDouble(),
                              width: 18,
                              borderRadius: BorderRadius.circular(6),
                              color: isToday
                                  ? const Color(0xFF4A90E2)
                                  : metGoal
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxSteps.toDouble() * 1.2,
                                color: const Color(0xFFEDF2F7),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFF10B981), 'Goal met'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF4A90E2), 'Today'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF94A3B8), 'Below goal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // ── Screen Time Breakdown ────────────────────────────────────────────────

  Widget _buildScreenTimeBreakdown(int earned, int used, int remaining) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.bar_chart_rounded, const Color(0xFF4A90E2)),
              const SizedBox(width: 12),
              const Text(
                'Screen Time Breakdown',
                style: TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stacked bar
          if (earned > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _progressRatio),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (_, val, _) {
                  return SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        if (val > 0)
                          Flexible(
                            flex: (val * 100).round(),
                            child: Container(color: const Color(0xFFEF4444)),
                          ),
                        if (val < 1)
                          Flexible(
                            flex: ((1 - val) * 100).round(),
                            child: Container(color: const Color(0xFF10B981)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: _breakdownItem(
                  'Earned',
                  _formatDuration(earned),
                  const Color(0xFF10B981),
                  Icons.add_circle_outline_rounded,
                ),
              ),
              Expanded(
                child: _breakdownItem(
                  'Used',
                  _formatDuration(used),
                  const Color(0xFFEF4444),
                  Icons.remove_circle_outline_rounded,
                ),
              ),
              Expanded(
                child: _breakdownItem(
                  'Left',
                  _formatDuration(remaining),
                  const Color(0xFF4A90E2),
                  Icons.hourglass_bottom_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Reward Rate ──────────────────────────────────────────────────────────

  Widget _buildRewardRateCard(int steps, int minutesPer1k) {
    final milestonesDone = steps ~/ 1000;
    final nextMilestone = (milestonesDone + 1) * 1000;
    final stepsToNext = nextMilestone - steps;

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.star_rounded, const Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              const Text(
                'Reward Rate',
                style: TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _rateItem('1,000', 'steps', const Color(0xFF64748B)),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
                _rateItem('$minutesPer1k', 'min', const Color(0xFFF59E0B)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Milestones earned
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: milestonesDone > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFCBD5E0),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '$milestonesDone milestone${milestonesDone == 1 ? '' : 's'} earned today',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$stepsToNext steps until next $minutesPer1k-min reward',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateItem(String value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Blocked Apps (with real icons) ──────────────────────────────────────

  Widget _buildBlockedAppsCard(Map<String, String> blockedApps) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.block_rounded, const Color(0xFFEF4444)),
              const SizedBox(width: 12),
              Text(
                'Blocked Apps Usage (${blockedApps.length})',
                style: const TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: blockedApps.entries.map((entry) {
              final pkg = entry.key;
              final name = entry.value;
              final usedMins = _timeBank.getUsedMinutesForApp(pkg);
              final totalEarned = _timeBank.earnedMinutes;
              final appRatio = totalEarned > 0
                  ? (usedMins / totalEarned).clamp(0.0, 1.0)
                  : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Real app icon using AppIconWidget
                        AppIconWidget(
                          packageName: pkg,
                          size: 36,
                          fallbackIcon: Icons.phone_android_rounded,
                          fallbackIconColor: const Color(0xFFEF4444),
                          fallbackBgColor: const Color(
                            0xFFEF4444,
                          ).withValues(alpha: 0.1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Color(0xFF1A202C),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$usedMins min',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (usedMins > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: appRatio),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOut,
                          builder: (_, val, _) => LinearProgressIndicator(
                            value: val,
                            minHeight: 4,
                            backgroundColor: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Share Achievement Button ──────────────────────────────────────────────

  Widget _buildShareButton(int steps, int earned, int used, int streak) {
    return GestureDetector(
      onTap: _isSharing ? null : _shareProgress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSharing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            else
              const Icon(
                Icons.leaderboard_rounded,
                color: Colors.white,
                size: 20,
              ),
            const SizedBox(width: 10),
            const Text(
              'Share My Progress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.share_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Motivational Tip ──────────────────────────────────────────────────────

  Widget _buildMotivationalTip(int steps, int goal) {
    final String message;
    final Color color;
    final IconData icon;

    if (steps >= goal) {
      message = '🏆 Goal crushed! You escaped bedrot mode today. Amazing!';
      color = const Color(0xFFF59E0B);
      icon = Icons.emoji_events_rounded;
    } else if (steps >= (goal * 0.75).toInt()) {
      message =
          '🔥 Almost there! Just ${_formatSteps(goal - steps)} more steps — don\'t bedrot now!';
      color = const Color(0xFF10B981);
      icon = Icons.trending_up_rounded;
    } else if (steps >= (goal * 0.5).toInt()) {
      message =
          '💪 Halfway! Stop scrolling, start walking. Your screen time is waiting.';
      color = const Color(0xFF10B981);
      icon = Icons.directions_walk_rounded;
    } else if (steps >= 1000) {
      message =
          '👣 Good start! ${_timeBank.minutesPer1kSteps} more minutes unlock per 1k steps. Move that body!';
      color = const Color(0xFF4A90E2);
      icon = Icons.directions_walk_rounded;
    } else {
      message =
          '📵 No bedrotting! Walk your first 1,000 steps to earn your screen time.';
      color = const Color(0xFF4A90E2);
      icon = Icons.play_arrow_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFEF4444),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day data helper ───────────────────────────────────────────────────────────

class _DayData {
  final String label;
  final int steps;
  final int earned;

  const _DayData({
    required this.label,
    required this.steps,
    required this.earned,
  });
}

// ── Share Stat Card ──────────────────────────────────────────────────────────

/// The off-screen Fravo achievement card. Rendered hidden inside a
/// RepaintBoundary on the stats screen and captured to PNG for sharing.
class _ShareStatCard extends StatelessWidget {
  final int steps;
  final int earnedMinutes;
  final int usedMinutes;
  final int streak;
  final int minutesPer1k;
  final int goal;

  const _ShareStatCard({
    required this.steps,
    required this.earnedMinutes,
    required this.usedMinutes,
    required this.streak,
    required this.minutesPer1k,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ((steps / goal) * 100).clamp(0, 100).toInt();
    final date = DateFormat('MMM d, yyyy').format(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🏃', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FRAVO',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '🔥 $streak day streak',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Hero stat
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: steps >= 1000
                      ? '${(steps / 1000).toStringAsFixed(1)}k'
                      : '$steps',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const TextSpan(
                  text: '  steps today',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$pct% of daily goal',
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _shareStatChip('⚡', '$earnedMinutes min', 'earned'),
              const SizedBox(width: 10),
              _shareStatChip('📱', '$usedMinutes min', 'used'),
              const SizedBox(width: 10),
              _shareStatChip('🚶', '$minutesPer1k min', '/1k steps'),
            ],
          ),
          const SizedBox(height: 20),

          // Tagline
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Text(
              '"I traded my steps for screen time — no bedrotting today! 🏃📵"',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareStatChip(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared glass card widget ──────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
