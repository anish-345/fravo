import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft "puffy glass" design system — inspired by the workspace glass widget
/// reference. Compared to the old heavy-iridescent style this is:
///
/// - **Pill / capsule** border radii (very high) instead of 24–32 boxy cards
/// - **Two soft inner highlights** (top-left bright, bottom-right bright)
///   instead of a single iridescent rainbow overlay
/// - **No harsh white border** — a single 1px translucent hairline
/// - **Subtle outer drop shadow** for the floating-glass 3D feel
/// - Colors are pastel tints (green / purple / pink / blue) when used as
///   gradient accents, never a saturated flat fill

// ── Base "puffy glass" container ─────────────────────────────────────────────

class PuffyGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tintColor;
  final double tintAlpha;
  final double borderAlpha;
  final double highlightAlpha;
  final double shadowBlur;
  final Offset shadowOffset;
  final List<Color>? gradient;

  const PuffyGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
    this.tintColor,
    this.tintAlpha = 0.75,
    this.borderAlpha = 0.6,
    this.highlightAlpha = 0.4,
    this.shadowBlur = 22,
    this.shadowOffset = const Offset(0, 10),
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final tint = tintColor ?? Colors.white;
    // Pick up the accent color for the gradient wash so the top-left
    // actually shows the widget's tint instead of getting bleached white.
    final accent = gradient != null && gradient!.isNotEmpty
        ? gradient!.first
        : tint;
    final accentDeep = gradient != null && gradient!.length > 1
        ? gradient!.last
        : tint;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Stack(
          children: [
            // Base tint
            Container(
              decoration: BoxDecoration(
                gradient: gradient != null
                    ? LinearGradient(colors: gradient!)
                    : null,
                color: gradient == null
                    ? tint.withValues(alpha: tintAlpha)
                    : null,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: borderAlpha),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: shadowBlur,
                    offset: shadowOffset,
                  ),
                ],
              ),
              padding: padding,
              child: child,
            ),
            // Top-left colored highlight (accent gradient wash — gives the
            // top-left the saturated color the reference shows, instead of
            // a bleached white corner).
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: highlightAlpha + 0.25),
                          accentDeep.withValues(alpha: highlightAlpha * 0.5),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.35, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom-right bright pop (the "light catches the edge" sheen).
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: highlightAlpha * 0.5),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pastel color palette used across accent buttons / tabs / etc. ──────────

class GlassPalette {
  static const List<Color> mint = [Color(0xFFB8F2D8), Color(0xFF7FE3B5)];
  static const List<Color> lavender = [Color(0xFFD9CFFF), Color(0xFFB6A4FF)];
  static const List<Color> rose = [Color(0xFFFFD0D0), Color(0xFFFFA8A8)];
  static const List<Color> sky = [Color(0xFFBFE5FF), Color(0xFF8FC9F7)];
  static const List<Color> peach = [Color(0xFFFFE0C2), Color(0xFFFFB685)];

  /// Return the pastel accent that matches [color] from the active palette.
  static List<Color> accentFor(Color color) {
    if (color == const Color(0xFF10B981)) return mint;
    if (color == const Color(0xFF8B5CF6)) return lavender;
    if (color == const Color(0xFFEF4444)) return rose;
    if (color == const Color(0xFF4A90E2)) return sky;
    if (color == const Color(0xFFF59E0B)) return peach;
    return sky;
  }
}

// ── Primary pill button (the big "Create workspace" style) ─────────────────

class PuffyGlassPillButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color> gradient;
  final double height;

  const PuffyGlassPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.gradient = GlassPalette.lavender,
    this.height = 56,
  });

  @override
  State<PuffyGlassPillButton> createState() => _PuffyGlassPillButtonState();
}

class _PuffyGlassPillButtonState extends State<PuffyGlassPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: SizedBox(
          height: widget.height,
          child: PuffyGlassContainer(
            borderRadius: widget.height,
            gradient: widget.gradient,
            tintAlpha: 0.0,
            borderAlpha: 0.7,
            highlightAlpha: 0.55,
            shadowBlur: 26,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: const Color(0xFF1A1A2E), size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Subtle pill (the "Secondary button" style) ─────────────────────────────

class PuffyGlassSubtlePill extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color tint;

  const PuffyGlassSubtlePill({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tint = const Color(0xFFFFD0D0),
  });

  @override
  State<PuffyGlassSubtlePill> createState() => _PuffyGlassSubtlePillState();
}

class _PuffyGlassSubtlePillState extends State<PuffyGlassSubtlePill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: PuffyGlassContainer(
          borderRadius: 28,
          tintColor: widget.tint,
          tintAlpha: 0.55,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: const Color(0xFF1A1A2E), size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glass text field (the "Search projects..." / "Text field" style) ──────

class PuffyGlassTextField extends StatefulWidget {
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextEditingController? controller;
  final bool obscureText;
  final double height;

  const PuffyGlassTextField({
    super.key,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.controller,
    this.obscureText = false,
    this.height = 54,
  });

  @override
  State<PuffyGlassTextField> createState() => _PuffyGlassTextFieldState();
}

class _PuffyGlassTextFieldState extends State<PuffyGlassTextField> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PuffyGlassContainer(
      borderRadius: widget.height,
      tintAlpha: 0.7,
      borderAlpha: _focus.hasFocus ? 0.85 : 0.65,
      shadowBlur: 14,
      shadowOffset: const Offset(0, 6),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: SizedBox(
        height: widget.height,
        child: Row(
          children: [
            if (widget.prefixIcon != null) ...[
              Icon(
                widget.prefixIcon,
                color: const Color(0xFF1A1A2E),
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                obscureText: widget.obscureText,
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: const Color(0xFF1A1A2E).withValues(alpha: 0.75),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (widget.suffixIcon != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onSuffixTap,
                child: Icon(
                  widget.suffixIcon,
                  color: const Color(0xFF1A1A2E),
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Glass pill switch (the green/lavender toggle style) ────────────────────

class PuffyGlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final List<Color> activeGradient;

  const PuffyGlassSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeGradient = GlassPalette.lavender,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: PuffyGlassContainer(
        borderRadius: 30,
        gradient: value ? activeGradient : null,
        tintAlpha: value ? 0 : 0.7,
        borderAlpha: value ? 0.6 : 0.65,
        highlightAlpha: value ? 0.55 : 0.8,
        shadowBlur: 16,
        shadowOffset: const Offset(0, 6),
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 70,
          height: 36,
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glass tab pill ("Tabs" style — sliding indicator) ─────────────────────

class PuffyGlassTabs extends StatefulWidget {
  final List<String> labels;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final List<Color> accentGradient;

  const PuffyGlassTabs({
    super.key,
    required this.labels,
    required this.currentIndex,
    required this.onChanged,
    this.accentGradient = GlassPalette.lavender,
  });

  @override
  State<PuffyGlassTabs> createState() => _PuffyGlassTabsState();
}

class _PuffyGlassTabsState extends State<PuffyGlassTabs> {
  @override
  Widget build(BuildContext context) {
    return PuffyGlassContainer(
      borderRadius: 30,
      tintAlpha: 0.7,
      borderAlpha: 0.65,
      shadowBlur: 14,
      shadowOffset: const Offset(0, 6),
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.labels.length, (i) {
          final selected = i == widget.currentIndex;
          return GestureDetector(
            onTap: () => widget.onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(colors: widget.accentGradient)
                    : null,
                borderRadius: BorderRadius.circular(24),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: widget.accentGradient.last
                              .withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                widget.labels[i],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Glass icon button (the round mic/edit icon style) ────────────────────

class PuffyGlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color tint;
  final double size;
  final Color? iconColor;

  const PuffyGlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tint = const Color(0xFFE0E4EE),
    this.size = 56,
    this.iconColor,
  });

  @override
  State<PuffyGlassIconButton> createState() => _PuffyGlassIconButtonState();
}

class _PuffyGlassIconButtonState extends State<PuffyGlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: PuffyGlassContainer(
          borderRadius: widget.size,
          tintColor: widget.tint,
          tintAlpha: 0.7,
          borderAlpha: 0.65,
          highlightAlpha: 0.85,
          shadowBlur: 14,
          shadowOffset: const Offset(0, 6),
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Icon(
              widget.icon,
              size: widget.size * 0.42,
              color: widget.iconColor ?? const Color(0xFF1A1A2E),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glass toast / chip (the "+ Toast notification" / round dot style) ────

class PuffyGlassChip extends StatelessWidget {
  final Widget child;
  final List<Color>? gradient;
  final Color? tint;
  final EdgeInsetsGeometry padding;

  const PuffyGlassChip({
    super.key,
    required this.child,
    this.gradient,
    this.tint,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassContainer(
      borderRadius: 28,
      gradient: gradient,
      tintColor: tint,
      tintAlpha: 0.7,
      borderAlpha: 0.65,
      highlightAlpha: 0.85,
      shadowBlur: 16,
      shadowOffset: const Offset(0, 8),
      padding: padding,
      child: child,
    );
  }
}

// ── Modal dialog scaffold (the "Modal Cialog" reference card) ───────────

class PuffyGlassModal extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  const PuffyGlassModal({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.onAction,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: PuffyGlassContainer(
        borderRadius: 32,
        tintAlpha: 0.85,
        borderAlpha: 0.8,
        highlightAlpha: 0.85,
        shadowBlur: 30,
        shadowOffset: const Offset(0, 16),
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: onClose ?? () => Navigator.of(context).pop(),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: const Color(0xFF1A1A2E).withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            PuffyGlassPillButton(
              label: actionLabel,
              gradient: GlassPalette.lavender,
              onPressed: () {
                Navigator.of(context).pop();
                onAction?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Backwards-compatible aliases so existing callers still work ───────────

/// Alias kept for any existing callers that imported the old name.
class UltraGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderWidth;
  final bool showIridescence;
  final List<Color>? customGradient;

  const UltraGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.borderColor,
    this.borderWidth = 1.5,
    this.showIridescence = true,
    this.customGradient,
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassContainer(
      borderRadius: borderRadius,
      padding: padding,
      gradient: customGradient,
      tintColor: customGradient == null
          ? (borderColor ?? Colors.white)
          : null,
      borderAlpha: borderColor != null ? 0.8 : 0.65,
      child: child,
    );
  }
}

/// Alias kept for existing callers.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassContainer(
      borderRadius: borderRadius,
      padding: padding ?? const EdgeInsets.all(24),
      child: child,
    );
  }
}

/// Alias kept for the hero card call sites.
class GlassHeroCard extends StatelessWidget {
  final Widget child;
  const GlassHeroCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PuffyGlassContainer(
      borderRadius: 32,
      padding: const EdgeInsets.all(28),
      child: child,
    );
  }
}

/// Old "vibrant" CTA button — now a wide pill button with the supplied
/// gradient. Kept as an alias for onboarding and any other legacy caller.
class VibrantGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color> gradientColors;
  final bool loading;

  const VibrantGlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.gradientColors = GlassPalette.lavender,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassPillButton(
      label: label,
      icon: icon,
      gradient: gradientColors,
      onPressed: onPressed,
    );
  }
}

/// Old subtle pill button alias.
class SubtleGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SubtleGlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassSubtlePill(
      label: label,
      icon: icon,
      onPressed: onPressed,
    );
  }
}

/// Old toggle alias — maps activeColor to its matching pastel gradient.
class PremiumGlassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  const PremiumGlassToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor = const Color(0xFF10B981),
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassSwitch(
      value: value,
      onChanged: onChanged,
      activeGradient: GlassPalette.accentFor(activeColor),
    );
  }
}

/// Old text-field alias.
class GlassInputField extends StatelessWidget {
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextEditingController? controller;
  final bool obscureText;

  const GlassInputField({
    super.key,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.controller,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassTextField(
      hint: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      onSuffixTap: onSuffixTap,
      controller: controller,
      obscureText: obscureText,
    );
  }
}

/// Old metric-card alias.
class GlassMetricCard extends StatelessWidget {
  final String value;
  final String label;
  final String? unit;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final IconData? subtitleIcon;
  final Color? subtitleColor;

  const GlassMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    required this.icon,
    this.iconColor = const Color(0xFF4A90E2),
    this.subtitle,
    this.subtitleIcon,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: GlassPalette.accentFor(iconColor),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1A1A2E), size: 24),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                  height: 1,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Text(
                  unit!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  subtitleIcon ?? Icons.straighten_rounded,
                  size: 13,
                  color: subtitleColor ?? iconColor,
                ),
                const SizedBox(width: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: subtitleColor ?? iconColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Old icon-button alias — round, tinted glass. Used by the app bar.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.iconColor,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return PuffyGlassIconButton(
      icon: icon,
      onPressed: onPressed,
      iconColor: iconColor,
      size: size,
    );
  }
}
