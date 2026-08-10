import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/health_service.dart';
import '../services/time_bank.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  final _timeBank = TimeBankService.instance;

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
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
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
      final granted = await HealthService.instance.requestPermissions();
      if (!granted) {
        setState(() => _errorMessage = 'Health Connect permissions required.');
        return;
      }
      final steps = await HealthService.instance.fetchTodaySteps();
      await _timeBank.updateSteps(steps);
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _errorMessage = 'Failed to refresh: $e');
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

  @override
  Widget build(BuildContext context) {
    final steps = _timeBank.totalStepsWalked;
    final earned = _timeBank.earnedMinutes;
    final used = _timeBank.usedMinutes;
    final remaining = _timeBank.remainingScreenTime;
    final minutesPer1k = _timeBank.minutesPer1kSteps;
    final blockedApps = _timeBank.blockedPackageDisplayNames;

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
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.8)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1A202C), size: 18),
          ),
        ),
        title: Column(
          children: [
            const Text(
              'Today\'s Stats',
              style: TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            Text(today,
                style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
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
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF4A90E2)),
                    )
                  : const Icon(Icons.refresh_rounded,
                      color: Color(0xFF4A90E2), size: 18),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    _errorBanner(_errorMessage!),
                    const SizedBox(height: 12),
                  ],

                  // ── Screen Time Hero ─────────────────────────────────
                  _buildScreenTimeHero(remaining, earned, used),
                  const SizedBox(height: 14),

                  // ── Steps & Distance Row ─────────────────────────────
                  Row(children: [
                    Expanded(child: _buildStepsCard(steps, minutesPer1k)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDistanceCard(distanceKm, steps)),
                  ]),
                  const SizedBox(height: 14),

                  // ── Activity Stats Row (3 tiles) ─────────────────────
                  Row(children: [
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
                        value: '${((steps / 10000) * 100).clamp(0, 100).toInt()}',
                        unit: '%',
                      ),
                    ),
                  ]),
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

                  // ── Motivational Tip ─────────────────────────────────
                  _buildMotivationalTip(steps),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Screen Time Hero ────────────────────────────────────────────────────────

  Widget _buildScreenTimeHero(int remaining, int earned, int used) {
    final ratio = _progressRatio;
    final isExhausted = remaining <= 0 && earned > 0;
    final ringColor = isExhausted
        ? const Color(0xFFEF4444)
        : ratio > 0.8
            ? const Color(0xFFF59E0B)
            : const Color(0xFF4A90E2);

    return _GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'SCREEN TIME BUDGET',
            style: TextStyle(
              color: const Color(0xFF64748B).withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),

          // Circular ring
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 14,
                    color: const Color(0xFFEDF2F7),
                  ),
                ),
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    builder: (_, val, __) => CircularProgressIndicator(
                      value: val,
                      strokeWidth: 14,
                      strokeCap: StrokeCap.round,
                      color: ringColor,
                    ),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    '$remaining',
                    style: TextStyle(
                      color: isExhausted
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1A202C),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                  const Text(
                    'min left',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 18),

          if (isExhausted)
            _pillBadge('Limit reached — walk to unlock more!',
                const Color(0xFFEF4444))
          else
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _pillBadge('+${_formatDuration(earned)} earned',
                  const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _pillBadge('${_formatDuration(used)} used',
                  const Color(0xFFEF4444)),
            ]),
        ],
      ),
    );
  }

  // ── Steps Card ───────────────────────────────────────────────────────────

  Widget _buildStepsCard(int steps, int minutesPer1k) {
    const goal = 10000;
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
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                minHeight: 7,
                backgroundColor: const Color(0xFFEDF2F7),
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(ratio * 100).toInt()}% of 10k goal',
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500),
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
                displayKm
                    ? km.toStringAsFixed(2)
                    : '$metres',
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
                fontWeight: FontWeight.w500),
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
          color: const Color(0xFF8B5CF6).withOpacity(0.1),
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
          fontWeight: FontWeight.w600),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
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
      ]),
    );
  }

  // ── Screen Time Breakdown ────────────────────────────────────────────────

  Widget _buildScreenTimeBreakdown(int earned, int used, int remaining) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBadge(Icons.bar_chart_rounded, const Color(0xFF4A90E2)),
          const SizedBox(width: 12),
          const Text(
            'Screen Time Breakdown',
            style: TextStyle(
                color: Color(0xFF1A202C),
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
        ]),
        const SizedBox(height: 16),

        // Stacked bar
        if (earned > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _progressRatio),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, val, __) {
                return SizedBox(
                  height: 14,
                  child: Row(children: [
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
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        Row(children: [
          Expanded(child: _breakdownItem('Earned', _formatDuration(earned),
              const Color(0xFF10B981), Icons.add_circle_outline_rounded)),
          Expanded(child: _breakdownItem('Used', _formatDuration(used),
              const Color(0xFFEF4444), Icons.remove_circle_outline_rounded)),
          Expanded(child: _breakdownItem('Left', _formatDuration(remaining),
              const Color(0xFF4A90E2), Icons.hourglass_bottom_rounded)),
        ]),
      ]),
    );
  }

  Widget _breakdownItem(
      String label, String value, Color color, IconData icon) {
    return Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 6),
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]);
  }

  // ── Reward Rate ──────────────────────────────────────────────────────────

  Widget _buildRewardRateCard(int steps, int minutesPer1k) {
    final milestonesDone = steps ~/ 1000;
    final nextMilestone = (milestonesDone + 1) * 1000;
    final stepsToNext = nextMilestone - steps;

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBadge(Icons.star_rounded, const Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          const Text(
            'Reward Rate',
            style: TextStyle(
                color: Color(0xFF1A202C),
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.2)),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _rateItem('1,000', 'steps', const Color(0xFF64748B)),
                const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFFF59E0B), size: 20),
                _rateItem('$minutesPer1k', 'min', const Color(0xFFF59E0B)),
              ]),
        ),
        const SizedBox(height: 12),

        // Milestones earned
        Row(children: [
          Icon(Icons.emoji_events_rounded,
              color: milestonesDone > 0
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFCBD5E0),
              size: 16),
          const SizedBox(width: 6),
          Text(
            '$milestonesDone milestone${milestonesDone == 1 ? '' : 's'} earned today',
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          '$stepsToNext steps until next $minutesPer1k-min reward',
          style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  Widget _rateItem(String value, String unit, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900)),
      Text(unit,
          style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]);
  }

  // ── Blocked Apps ─────────────────────────────────────────────────────────

  Widget _buildBlockedAppsCard(Map<String, String> blockedApps) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBadge(Icons.block_rounded, const Color(0xFFEF4444)),
          const SizedBox(width: 12),
          Text(
            'Blocked Apps Usage (${blockedApps.length})',
            style: const TextStyle(
                color: Color(0xFF1A202C),
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
        ]),
        const SizedBox(height: 14),
        Column(
          children: blockedApps.entries.map((entry) {
            final pkg = entry.key;
            final name = entry.value;
            final usedMins = _timeBank.getUsedMinutesForApp(pkg);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.phone_android_rounded,
                        size: 16, color: Color(0xFFEF4444)),
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
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$usedMins min used',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── Motivational Tip ──────────────────────────────────────────────────────

  Widget _buildMotivationalTip(int steps) {
    final String message;
    final Color color;
    final IconData icon;

    if (steps >= 10000) {
      message = '🏆 You\'ve crushed your 10k goal! Amazing work today.';
      color = const Color(0xFFF59E0B);
      icon = Icons.emoji_events_rounded;
    } else if (steps >= 7500) {
      message = '🔥 Almost there! Just ${_formatSteps(10000 - steps)} steps to your goal.';
      color = const Color(0xFF10B981);
      icon = Icons.trending_up_rounded;
    } else if (steps >= 5000) {
      message = '💪 Halfway there! Keep walking to earn more screen time.';
      color = const Color(0xFF10B981);
      icon = Icons.directions_walk_rounded;
    } else if (steps >= 1000) {
      message = '👣 Good start! Every 1,000 steps earns you ${ _timeBank.minutesPer1kSteps} more minutes.';
      color = const Color(0xFF4A90E2);
      icon = Icons.directions_walk_rounded;
    } else {
      message = '🌟 Start walking to earn your screen time today!';
      color = const Color(0xFF4A90E2);
      icon = Icons.play_arrow_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4)),
        ),
      ]),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _pillBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFEF4444), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
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
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: Colors.white.withOpacity(0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
