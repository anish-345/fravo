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
import '../widgets/premium_glass_system.dart';

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
        builder: (context, setLocal) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: PuffyGlassContainer(
            borderRadius: 32,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            shadowBlur: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Text('🎯 ', style: TextStyle(fontSize: 22)),
                    Text(
                      'Daily Step Goal',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...goals.map((g) {
                  final isSelected = selected == g;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => setLocal(() => selected = g),
                      child: PuffyGlassContainer(
                        borderRadius: 18,
                        tintColor:
                            isSelected ? const Color(0xFFB8F2D8) : null,
                        tintAlpha: isSelected ? 0.8 : 0.5,
                        borderAlpha: isSelected ? 0.85 : 0.6,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
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
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                            const Spacer(),
                            if (g == 10000)
                              PuffyGlassChip(
                                tint: const Color(0xFFBFE5FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                child: const Text(
                                  'Default',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF1A1A2E),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            if (isSelected) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF1A1A2E),
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),
                PuffyGlassPillButton(
                  label: 'Set Goal',
                  gradient: GlassPalette.mint,
                  onPressed: () async {
                    await _timeBank.setCustomStepGoal(selected);
                    if (ctx.mounted) {
                      setState(() {});
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
          ),
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
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: PuffyGlassContainer(
              borderRadius: 14,
              tintAlpha: 0.7,
              shadowBlur: 10,
              shadowOffset: const Offset(0, 4),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1A1A2E),
                size: 18,
              ),
            ),
          ),
        ),
        title: Column(
          children: [
            const Text(
              'My Stats',
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              today,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
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
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: PuffyGlassContainer(
                borderRadius: 14,
                tintAlpha: 0.7,
                shadowBlur: 10,
                shadowOffset: const Offset(0, 4),
                padding: const EdgeInsets.all(8),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A1A2E),
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF1A1A2E),
                        size: 18,
                      ),
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
                              gradient: GlassPalette.peach,
                              label: 'Calories',
                              value: '$calories',
                              unit: 'kcal',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricTile(
                              icon: Icons.timer_outlined,
                              gradient: GlassPalette.mint,
                              label: 'Active',
                              value: '$activeMin',
                              unit: 'min',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricTile(
                              icon: Icons.trending_up_rounded,
                              gradient: GlassPalette.sky,
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
    return PuffyGlassContainer(
      borderRadius: 22,
      gradient: const [Color(0xFFFFE0C2), Color(0xFFFFB685)],
      tintAlpha: 0.0,
      borderAlpha: 0.6,
      highlightAlpha: 0.55,
      shadowBlur: 24,
      shadowOffset: const Offset(0, 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    color: Color(0xFF1A1A2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak == 1
                      ? 'Day 1! Keep walking, stop the scroll. 💪'
                      : 'You\'re on a roll — don\'t break the chain!',
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '🏆 $streak',
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Steps Card ───────────────────────────────────────────────────────────

  Widget _buildStepsCard(int steps, int minutesPer1k, int goal) {
    final ratio = (steps / goal).clamp(0.0, 1.0);

    return PuffyGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      shadowBlur: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: GlassPalette.mint),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: GlassPalette.mint.last.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: Color(0xFF1A1A2E),
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatSteps(steps),
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const Text(
            'steps today',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, val, _) => LinearProgressIndicator(
                value: val,
                minHeight: 7,
                backgroundColor: const Color(0xFF1A1A2E).withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(
                  Color(0xFF1A1A2E),
                ),
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
                    color: Color(0xFF1A1A2E),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit_rounded,
                  size: 11,
                  color: Color(0xFF1A1A2E),
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

    return PuffyGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      shadowBlur: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: GlassPalette.lavender),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: GlassPalette.lavender.last.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Color(0xFF1A1A2E),
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                displayKm ? km.toStringAsFixed(2) : '$metres',
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                displayKm ? 'km' : 'm',
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Text(
            'distance walked',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
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
      return PuffyGlassChip(
        gradient: GlassPalette.lavender,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: const Text(
          '🏅 Milestone reached!',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final remaining = ((nextMilestone - km) * 1000).round();
    return Text(
      '${remaining}m to $milestoneName',
      style: const TextStyle(
        color: Color(0xFF1A1A2E),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ── Metric Tile ──────────────────────────────────────────────────────────

  Widget _metricTile({
    required IconData icon,
    required List<Color> gradient,
    required String label,
    required String value,
    required String unit,
  }) {
    return PuffyGlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      shadowBlur: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1A1A2E), size: 18),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 10,
              fontWeight: FontWeight.w700,
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

    return PuffyGlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(20),
      shadowBlur: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: GlassPalette.lavender),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          GlassPalette.lavender.last.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF1A1A2E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Activity',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Steps per day vs your goal',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 11,
                      ),
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
                          color: const Color(0xFF1A1A2E),
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Walk today to start your history!',
                          style: TextStyle(
                            color: Color(0xFF1A1A2E),
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
                                color: Color(0xFF1A1A2E),
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
                                    fontWeight: FontWeight.w700,
                                    color: idx == 6
                                        ? GlassPalette.lavender.last
                                        : const Color(0xFF1A1A2E)
                                            .withValues(alpha: 0.6),
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
                          color: GlassPalette.mint.last
                              .withValues(alpha: 0.5),
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
                              borderRadius: BorderRadius.circular(8),
                              color: isToday
                                  ? GlassPalette.lavender.last
                                  : metGoal
                                      ? GlassPalette.mint.last
                                      : const Color(0xFF1A1A2E)
                                          .withValues(alpha: 0.25),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxSteps.toDouble() * 1.2,
                                color:
                                    const Color(0xFF1A1A2E).withValues(alpha: 0.06),
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
              _legendDot(GlassPalette.mint.last, 'Goal met'),
              const SizedBox(width: 16),
              _legendDot(GlassPalette.lavender.last, 'Today'),
              const SizedBox(width: 16),
              _legendDot(
                const Color(0xFF1A1A2E).withValues(alpha: 0.25),
                'Below goal',
              ),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Screen Time Breakdown ────────────────────────────────────────────────

  Widget _buildScreenTimeBreakdown(int earned, int used, int remaining) {
    return PuffyGlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(20),
      shadowBlur: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: GlassPalette.sky),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: GlassPalette.sky.last.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF1A1A2E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Screen Time Breakdown',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stacked bar
          if (earned > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: GlassPalette.rose,
                                ),
                              ),
                            ),
                          ),
                        if (val < 1)
                          Flexible(
                            flex: ((1 - val) * 100).round(),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: GlassPalette.mint,
                                ),
                              ),
                            ),
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
                  GlassPalette.mint,
                  Icons.add_circle_outline_rounded,
                ),
              ),
              Expanded(
                child: _breakdownItem(
                  'Used',
                  _formatDuration(used),
                  GlassPalette.rose,
                  Icons.remove_circle_outline_rounded,
                ),
              ),
              Expanded(
                child: _breakdownItem(
                  'Left',
                  _formatDuration(remaining),
                  GlassPalette.sky,
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
    List<Color> gradient,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF1A1A2E), size: 16),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
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

    return PuffyGlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(20),
      shadowBlur: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: GlassPalette.peach),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          GlassPalette.peach.last.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFF1A1A2E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Reward Rate',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PuffyGlassContainer(
            borderRadius: 18,
            tintColor: const Color(0xFFFFE0C2),
            tintAlpha: 0.7,
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _rateItem('1,000', 'steps', const Color(0xFF1A1A2E)),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF1A1A2E),
                  size: 20,
                ),
                _rateItem('$minutesPer1k', 'min', const Color(0xFF1A1A2E)),
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
                    ? GlassPalette.peach.last
                    : const Color(0xFF1A1A2E).withValues(alpha: 0.3),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '$milestonesDone milestone${milestonesDone == 1 ? '' : 's'} earned today',
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$stepsToNext steps until next $minutesPer1k-min reward',
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
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
            color: Color(0xFF1A1A2E),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Blocked Apps (with real icons) ──────────────────────────────────────

  Widget _buildBlockedAppsCard(Map<String, String> blockedApps) {
    return PuffyGlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(20),
      shadowBlur: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: GlassPalette.rose),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: GlassPalette.rose.last.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Color(0xFF1A1A2E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Blocked Apps Usage (${blockedApps.length})',
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
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

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PuffyGlassContainer(
                  borderRadius: 16,
                  tintColor: const Color(0xFFFFD0D0),
                  tintAlpha: 0.55,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
                            fallbackIconColor: const Color(0xFF1A1A2E),
                            fallbackBgColor: const Color(0xFFFFD0D0),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Color(0xFF1A1A2E),
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
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$usedMins min',
                              style: const TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (usedMins > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: appRatio),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOut,
                            builder: (_, val, _) => LinearProgressIndicator(
                              value: val,
                              minHeight: 4,
                              backgroundColor: const Color(0xFFFFD0D0)
                                  .withValues(alpha: 0.4),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFFFA8A8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
    return PuffyGlassPillButton(
      label: _isSharing ? 'Preparing…' : 'Share My Progress',
      icon: _isSharing ? null : Icons.leaderboard_rounded,
      gradient: GlassPalette.lavender,
      onPressed: _isSharing ? null : _shareProgress,
    );
  }

  // ── Motivational Tip ──────────────────────────────────────────────────────

  Widget _buildMotivationalTip(int steps, int goal) {
    final List<Color> gradient;
    final Color textColor;
    final IconData icon;
    final String message;

    if (steps >= goal) {
      gradient = GlassPalette.peach;
      textColor = const Color(0xFF1A1A2E);
      icon = Icons.emoji_events_rounded;
      message = '🏆 Goal crushed! You escaped bedrot mode today. Amazing!';
    } else if (steps >= (goal * 0.75).toInt()) {
      gradient = GlassPalette.mint;
      textColor = const Color(0xFF1A1A2E);
      icon = Icons.trending_up_rounded;
      message =
          '🔥 Almost there! Just ${_formatSteps(goal - steps)} more steps — don\'t bedrot now!';
    } else if (steps >= (goal * 0.5).toInt()) {
      gradient = GlassPalette.mint;
      textColor = const Color(0xFF1A1A2E);
      icon = Icons.directions_walk_rounded;
      message =
          '💪 Halfway! Stop scrolling, start walking. Your screen time is waiting.';
    } else if (steps >= 1000) {
      gradient = GlassPalette.sky;
      textColor = const Color(0xFF1A1A2E);
      icon = Icons.directions_walk_rounded;
      message =
          '👣 Good start! ${_timeBank.minutesPer1kSteps} more minutes unlock per 1k steps. Move that body!';
    } else {
      gradient = GlassPalette.sky;
      textColor = const Color(0xFF1A1A2E);
      icon = Icons.play_arrow_rounded;
      message =
          '📵 No bedrotting! Walk your first 1,000 steps to earn your screen time.';
    }

    return PuffyGlassContainer(
      borderRadius: 22,
      gradient: gradient,
      tintAlpha: 0.0,
      borderAlpha: 0.6,
      highlightAlpha: 0.55,
      shadowBlur: 22,
      shadowOffset: const Offset(0, 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _errorBanner(String message) {
    return PuffyGlassContainer(
      borderRadius: 18,
      tintColor: const Color(0xFFFFD0D0),
      tintAlpha: 0.7,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFF1A1A2E),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day data helper ─────────────────────────────────────────────────────────

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
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: GlassPalette.lavender),
        borderRadius: BorderRadius.all(Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 30,
            offset: Offset(0, 14),
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
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
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
                      color: Color(0xFF1A1A2E),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    date,
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
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
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🔥 $streak day streak',
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
                    color: Color(0xFF1A1A2E),
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const TextSpan(
                  text: '  steps today',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$pct% of daily goal',
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 14,
              fontWeight: FontWeight.w800,
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
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '"I traded my steps for screen time — no bedrotting today! 🏃📵"',
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
                fontWeight: FontWeight.w700,
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
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
