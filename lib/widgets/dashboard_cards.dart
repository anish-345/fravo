import 'dart:async';

import 'package:flutter/material.dart';

import '../services/time_bank.dart';
import 'app_selector_sheet.dart';
import 'blocking_permission_flow.dart';
import 'premium_glass_system.dart';

// ── Missing Permissions Banner ──────────────────────────────────────────────

class MissingPermissionsBanner extends StatelessWidget {
  final Map<String, bool> permissions;
  final VoidCallback onRefresh;

  const MissingPermissionsBanner({
    super.key,
    required this.permissions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    int missingCount = 0;
    if (permissions['accessibility'] != true) missingCount++;
    if (permissions['usageStats'] != true) missingCount++;
    if (permissions['overlay'] != true) missingCount++;
    if (permissions['activityRecognition'] != true) missingCount++;
    if (permissions['notification'] != true) missingCount++;

    if (missingCount == 0) return const SizedBox.shrink();

    return PuffyGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      tintColor: const Color(0xFFFFE0C2),
      tintAlpha: 0.55,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: GlassPalette.peach),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF1A1A2E),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Required ($missingCount left)',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Grant permissions to enable app blocking',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PuffyGlassSubtlePill(
            label: 'Setup',
            icon: Icons.settings_rounded,
            tint: const Color(0xFFFFD0D0),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BlockingPermissionsSheet(onChanged: onRefresh),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Time Hero Card ─────────────────────────────────────────────────────────

class TimeHeroCard extends StatelessWidget {
  final int remaining;
  final int remainingSeconds; // live second-precision countdown from local timer
  final int earned;
  final int used;
  final int steps;

  const TimeHeroCard({
    super.key,
    required this.remaining,
    required this.remainingSeconds,
    required this.earned,
    required this.used,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = remaining > 0;
    final accent = isActive
        ? GlassPalette.mint
        : GlassPalette.rose;
    final ringValue = earned > 0 ? (remaining / earned).clamp(0.0, 1.0) : 0.0;

    return PuffyGlassContainer(
      borderRadius: 32,
      padding: const EdgeInsets.all(24),
      shadowBlur: 28,
      shadowOffset: const Offset(0, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress ring — compact (132) so the stat tiles below breathe.
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: CircularProgressIndicator(
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    value: ringValue,
                    backgroundColor:
                        const Color(0xFF1A1A2E).withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent.last),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.88, end: 1)
                                .animate(CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOut,
                                )),
                            child: child,
                          ),
                        ),
                        child: remaining <= 0
                            ? Text(
                                '0',
                                key: const ValueKey('blocked'),
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: -1.2,
                                  color: Color(0xFF1A1A2E),
                                ),
                              )
                            : remainingSeconds < 300 // < 5 min: show MM:SS
                                ? Text(
                                    _formatMMSS(remainingSeconds),
                                    key: ValueKey<int>(remainingSeconds),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      letterSpacing: -1.2,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  )
                                : Text(
                                    '$remaining',
                                    key: ValueKey<int>(remaining),
                                    style: const TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      letterSpacing: -1.2,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      remaining <= 0
                          ? 'blocked'
                          : remainingSeconds < 300
                              ? 'sec left'
                              : 'min left',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$used used · $earned earned',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: HeroStatTile(
                  icon: Icons.directions_walk_rounded,
                  gradient: GlassPalette.sky,
                  value: steps >= 1000
                      ? '${(steps / 1000).toStringAsFixed(1)}k'
                      : '$steps',
                  label: 'Steps',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeroStatTile(
                  icon: Icons.timer_rounded,
                  gradient: GlassPalette.mint,
                  value: '$earned',
                  label: 'Earned',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PuffyGlassChip(
            gradient: accent,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive
                      ? Icons.play_arrow_rounded
                      : Icons.lock_clock_rounded,
                  size: 14,
                  color: const Color(0xFF1A1A2E),
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'ACTIVE' : 'BLOCKED',
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formats seconds as MM:SS (e.g. 263 → "4:23").
  static String _formatMMSS(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';  
  }
}

// ── Hero Stat Tile ─────────────────────────────────────────────────────────

class HeroStatTile extends StatelessWidget {
  final IconData icon;
  final List<Color> gradient;
  final String value;
  final String label;

  const HeroStatTile({
    super.key,
    required this.icon,
    required this.gradient,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassContainer(
      borderRadius: 18,
      tintColor: Colors.white,
      tintAlpha: 0.6,
      shadowBlur: 10,
      shadowOffset: const Offset(0, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF1A1A2E)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Blocked Apps Card ──────────────────────────────────────────────────────

class BlockedAppsCard extends StatelessWidget {
  final List<String> apps;
  final TimeBankService timeBank;
  final VoidCallback onManage;

  const BlockedAppsCard({
    super.key,
    required this.apps,
    required this.timeBank,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final visible = apps.take(4).toList();
    final extra = apps.length - visible.length;

    return PuffyGlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(22),
      shadowBlur: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.block_rounded,
                color: Color(0xFF1A1A2E),
                size: 17,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'BLOCKED APPS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              PuffyGlassChip(
                gradient: GlassPalette.rose,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Text(
                  '${apps.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (apps.isEmpty)
            PuffyGlassContainer(
              borderRadius: 18,
              tintAlpha: 0.55,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: const [
                  Icon(
                    Icons.apps_rounded,
                    size: 26,
                    color: Color(0xFF1A1A2E),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No apps blocked yet',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap "Manage apps" to add some',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: visible.map((pkg) {
                final name = timeBank.displayNameFor(pkg);
                final usedStr = timeBank.getFormattedUsedTimeForApp(pkg);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      AppIconWidget(
                        packageName: pkg,
                        size: 32,
                        fallbackIcon: Icons.phone_android_rounded,
                        fallbackIconColor: const Color(0xFF1A1A2E),
                        fallbackBgColor: const Color(0xFFFFD0D0),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        usedStr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+$extra more apps',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          const SizedBox(height: 16),
          PuffyGlassSubtlePill(
            label: 'Manage Apps',
            icon: Icons.swap_horiz_rounded,
            tint: const Color(0xFFBFE5FF),
            onPressed: onManage,
          ),
        ],
      ),
    );
  }
}

// ── Emergency Snooze Card ──────────────────────────────────────────────────

class EmergencySnoozeCard extends StatelessWidget {
  final bool isAvailable;
  final VoidCallback onTap;

  const EmergencySnoozeCard({
    super.key,
    this.isAvailable = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = isAvailable
        ? const Color(0xFFFFD0D0)
        : const Color(0xFFE0E4EE);

    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: PuffyGlassContainer(
        borderRadius: 22,
        tintColor: tint,
        tintAlpha: 0.6,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAvailable
                      ? GlassPalette.rose
                      : const [Color(0xFFE0E4EE), Color(0xFFC5C9D6)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: Color(0xFF1A1A2E),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAvailable
                        ? 'Emergency 3-Min Pass'
                        : 'Emergency Pass Used Today',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAvailable
                        ? '+3 minutes emergency screen time (1 use per day)'
                        : 'Limit reached (1/day) • Resets at midnight',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            if (isAvailable)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF1A1A2E),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Emergency Pass Active Banner ───────────────────────────────────────────

class EmergencyPassBanner extends StatefulWidget {
  final DateTime expiry;
  /// Optional callback fired when the pass expires — use to re-evaluate
  /// block state immediately instead of waiting for the next 5s poll.
  final VoidCallback? onExpired;

  const EmergencyPassBanner({
    super.key,
    required this.expiry,
    this.onExpired,
  });

  @override
  State<EmergencyPassBanner> createState() => _EmergencyPassBannerState();
}

class _EmergencyPassBannerState extends State<EmergencyPassBanner> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final r = widget.expiry.difference(DateTime.now());
    final wasPositive = _remaining.inSeconds > 0;
    if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
    // When the pass just expired, fire the callback so blocking is
    // re-evaluated immediately without waiting for the next 5s poll.
    if (wasPositive && _remaining.inSeconds <= 0) {
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = _remaining.inSeconds;
    final mins = _remaining.inMinutes;
    final secsDisplay = secs % 60;
    final timeStr = '$mins:${secsDisplay.toString().padLeft(2, '0')}';

    return PuffyGlassContainer(
      borderRadius: 22,
      gradient: GlassPalette.rose,
      tintAlpha: 0.0,
      borderAlpha: 0.6,
      highlightAlpha: 0.6,
      shadowBlur: 22,
      shadowOffset: const Offset(0, 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFF1A1A2E), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Emergency Pass Active',
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Walk to Earn Card ──────────────────────────────────────────────────────

class WalkToEarnCard extends StatelessWidget {
  final int steps;
  final int earned;
  final int used;
  final int remaining;
  final int minutesPer1kSteps;

  const WalkToEarnCard({
    super.key,
    required this.steps,
    required this.earned,
    required this.used,
    required this.remaining,
    required this.minutesPer1kSteps,
  });

  @override
  Widget build(BuildContext context) {
    final stepsPerMinute = (1000 / minutesPer1kSteps).ceil();
    final inCurrentMinute = steps % stepsPerMinute;
    final progress = inCurrentMinute / stepsPerMinute;
    final stepsToNext = inCurrentMinute == 0
        ? stepsPerMinute
        : stepsPerMinute - inCurrentMinute;
    final isBlocked = earned > 0 && remaining <= 0;

    final String subline;
    if (isBlocked) {
      subline =
          'Apps are paused — walk about $stepsToNext steps to earn another minute.';
    } else if (steps == 0) {
      subline =
          'Every ~$stepsPerMinute steps earns a +1 minute. Walk a little and watch it grow!';
    } else {
      subline = '$stepsToNext steps to your next +1 minute →';
    }

    return PuffyGlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(20),
      shadowBlur: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'WALK TO EARN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              const LivePulseDot(),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                    child: child,
                  ),
                ),
                child: Text(
                  '$steps',
                  key: ValueKey<int>(steps),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -1.5,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'next +1 minute',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor:
                            const Color(0xFF1A1A2E).withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isBlocked
                              ? GlassPalette.rose.last
                              : GlassPalette.mint.last,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subline,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live pulse dot ─────────────────────────────────────────────────────────

class LivePulseDot extends StatefulWidget {
  const LivePulseDot({super.key});

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.2,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: GlassPalette.mint),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
