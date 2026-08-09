import 'dart:async';

import 'package:flutter/material.dart';

import '../services/time_bank.dart';
import 'app_selector_sheet.dart';
import 'blocking_permission_flow.dart';
import 'premium_glass_system.dart';

// ── Beautiful Explanatory Missing Permissions Banner ───────────────────

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

    return UltraGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFFF59E0B),
              size: 24,
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
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Grant permissions to enable app blocking',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BlockingPermissionsSheet(onChanged: onRefresh),
              );
            },
            child: const Text(
              'Setup',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Time Hero Card ────────────────────────────────────────────────────────────

/// Large "screen time left" hero: a glass card with a progress ring around the
/// remaining minutes, plus steps / earned stat tiles and an ACTIVE/BLOCKED
/// status pill. The ring is intentionally compact so the stat tiles below it
/// get the room they need to show their full values.
class TimeHeroCard extends StatelessWidget {
  final int remaining;
  final int earned;
  final int used;
  final int steps;

  const TimeHeroCard({
    super.key,
    required this.remaining,
    required this.earned,
    required this.used,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = remaining > 0;
    final accent = isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final ringValue = earned > 0 ? (remaining / earned).clamp(0.0, 1.0) : 0.0;

    return GlassHeroCard(
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
                // Ring: neutral track + colored remaining-time arc.
                SizedBox(
                  width: 132,
                  height: 132,
                  child: CircularProgressIndicator(
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    value: ringValue,
                    backgroundColor: const Color(
                      0xFF64748B,
                    ).withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$remaining',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -1.2,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'min left',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
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
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: HeroStatTile(
                  icon: Icons.directions_walk_rounded,
                  color: const Color(0xFF4A90E2),
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
                  color: const Color(0xFF10B981),
                  value: '$earned',
                  label: 'Earned',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive
                      ? Icons.play_arrow_rounded
                      : Icons.lock_clock_rounded,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'ACTIVE' : 'BLOCKED',
                  style: TextStyle(
                    color: accent,
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
}

// ── Hero Stat Tile ────────────────────────────────────────────────────────────

/// Compact inline stat (steps / earned) shown inside the time hero card.
class HeroStatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const HeroStatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1F2937).withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: color),
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
                      color: Color(0xFF1A202C),
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
                    color: Color(0xFF4B5563),
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

// ── Blocked Apps Card ─────────────────────────────────────────────────────────

/// Full-width card listing blocked apps (up to 4) with live per-app usage.
/// Tapping the manage button (or an app row) opens the app selector.
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

    return UltraGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.block_rounded,
                color: Color(0xFFEF4444),
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
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${apps.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (apps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1F2937).withValues(alpha: 0.07),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.apps_rounded,
                    size: 26,
                    color: Color(0xFF4B5563),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No apps blocked yet',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap "Manage apps" to add some',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                  ),
                ],
              ),
            )
          else
            Column(
              children: visible.map((pkg) {
                final name = timeBank.displayNameFor(pkg);
                final usedMins = timeBank.getUsedMinutesForApp(pkg);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      AppIconWidget(
                        packageName: pkg,
                        size: 32,
                        fallbackIcon: Icons.phone_android_rounded,
                        fallbackIconColor: const Color(0xFFEF4444),
                        fallbackBgColor: const Color(
                          0xFFEF4444,
                        ).withValues(alpha: 0.12),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A202C),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${usedMins}m',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
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
                  color: Color(0xFF4B5563),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Material(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onManage,
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: Color(0xFF4A90E2),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Manage Apps',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Emergency Snooze Card ─────────────────────────────────────────────────────

class EmergencySnoozeCard extends StatelessWidget {
  final int totalSteps;
  final VoidCallback onTap;

  const EmergencySnoozeCard({
    super.key,
    required this.totalSteps,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasEnough = totalSteps >= TimeBankService.emergencyPassCostSteps;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: hasEnough
              ? const Color(0xFFEF4444).withValues(alpha: 0.06)
              : const Color(0xFF64748B).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasEnough
                ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                : const Color(0xFF64748B).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: hasEnough
                    ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                    : const Color(0xFF64748B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emergency_rounded,
                color: hasEnough
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF6B7280),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasEnough
                        ? 'Emergency 3-Min Pass'
                        : 'Emergency Pass Locked',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: hasEnough
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasEnough
                        ? 'Costs ${TimeBankService.emergencyPassCostSteps} steps for ${TimeBankService.emergencyPassDurationMinutes} min unlock'
                        : 'Walk ${TimeBankService.emergencyPassCostSteps} steps to unlock this feature',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (hasEnough)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Emergency Pass Active Banner ──────────────────────────────────────────────

class EmergencyPassBanner extends StatefulWidget {
  final DateTime expiry;

  const EmergencyPassBanner({super.key, required this.expiry});

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
    if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFF97316)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Emergency Pass Active',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
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

// ── Walk to Earn Card ─────────────────────────────────────────────────────────

/// Live "steps → screen time" loop card on the home dashboard. Rebuilds every
/// ~5s (dashboard poll), so the counter ticks up while the user walks.
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

    return UltraGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      borderWidth: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'WALK TO EARN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Color(0xFF4B5563),
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
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Animated step counter
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
                    color: Color(0xFF1A202C),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Progress to next minute
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'next +1 minute',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: const Color(
                          0xFF64748B,
                        ).withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isBlocked
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isBlocked
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Softly pulsing green dot indicating live step tracking.
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
        decoration: const BoxDecoration(
          color: Color(0xFF10B981),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
