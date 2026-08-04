import 'package:flutter/material.dart';
import 'dart:ui';

/// Premium Glass Design System matching reference image
/// Features: Ultra-transparency, thick borders, heavy blur, iridescent effects

/// Base glass container with all effects
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
    return Stack(
      children: [
        // Main glass container
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              decoration: BoxDecoration(
                gradient: customGradient != null 
                  ? LinearGradient(colors: customGradient!)
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: borderColor ?? Colors.white.withValues(alpha: 0.2),
                  width: borderWidth,
                ),
                boxShadow: [
                  // Outer shadow - depth
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                    spreadRadius: -5,
                  ),
                  // Inner glow - glass effect
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                    spreadRadius: -10,
                  ),
                ],
              ),
              padding: padding,
              child: child,
            ),
          ),
        ),
        // Iridescent rainbow reflection overlay
        if (showIridescence)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyan.withValues(alpha: 0.03),
                        Colors.pink.withValues(alpha: 0.02),
                        Colors.yellow.withValues(alpha: 0.02),
                        Colors.purple.withValues(alpha: 0.01),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Primary action button with vibrant gradient (like "Start project")
class VibrantGlassButton extends StatefulWidget {
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
    this.gradientColors = const [
      Color(0xFFFF6B35), // Orange
      Color(0xFFFFC107), // Yellow
    ],
    this.loading = false,
  });

  @override
  State<VibrantGlassButton> createState() => _VibrantGlassButtonState();
}

class _VibrantGlassButtonState extends State<VibrantGlassButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: UltraGlassContainer(
          borderRadius: 22,
          customGradient: [
            widget.gradientColors[0].withValues(alpha: 0.85),
            widget.gradientColors[1].withValues(alpha: 0.75),
          ],
          borderColor: Colors.white.withValues(alpha: 0.35),
          borderWidth: 2,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              else if (widget.icon != null)
                Icon(widget.icon, color: Colors.white, size: 22),
              if (widget.icon != null || widget.loading) 
                const SizedBox(width: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Secondary button with subtle glass (like "Secondary")
class SubtleGlassButton extends StatefulWidget {
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
  State<SubtleGlassButton> createState() => _SubtleGlassButtonState();
}

class _SubtleGlassButtonState extends State<SubtleGlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: UltraGlassContainer(
          borderRadius: 22,
          borderColor: Colors.white.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon, 
                  color: const Color(0xFF2D3748), 
                  size: 20,
                ),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass card for content areas (like "Card" in image)
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
    return UltraGlassContainer(
      borderRadius: borderRadius,
      padding: padding ?? const EdgeInsets.all(24),
      child: child,
    );
  }
}

/// Glass input field (like "With suggestions")
class GlassInputField extends StatefulWidget {
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
  State<GlassInputField> createState() => _GlassInputFieldState();
}

class _GlassInputFieldState extends State<GlassInputField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return UltraGlassContainer(
      borderRadius: 20,
      borderColor: _isFocused 
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.2),
      borderWidth: _isFocused ? 2 : 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          if (widget.prefixIcon != null) ...[
            Icon(
              widget.prefixIcon,
              color: const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Focus(
              onFocusChange: (focused) {
                setState(() => _isFocused = focused);
              },
              child: TextField(
                controller: widget.controller,
                obscureText: widget.obscureText,
                style: const TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: const Color(0xFF64748B).withValues(alpha: 0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          if (widget.suffixIcon != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: widget.onSuffixTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.suffixIcon,
                  color: const Color(0xFF4A90E2),
                  size: 20,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Premium glass toggle switch (like green toggle in image)
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
    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 64,
        height: 36,
        decoration: BoxDecoration(
          gradient: value
            ? LinearGradient(
                colors: [
                  activeColor,
                  activeColor.withValues(alpha: 0.8),
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: value
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: value ? [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ] : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
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
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
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

/// Glass metric card with icon
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
    final subColor = subtitleColor ?? iconColor;
    final subIcon = subtitleIcon ?? Icons.straighten_rounded;

    return UltraGlassContainer(
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
                colors: [
                  iconColor.withValues(alpha: 0.15),
                  iconColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A202C),
                  height: 1,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  subIcon,
                  size: 13,
                  color: subColor,
                ),
                const SizedBox(width: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subColor,
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

/// Icon button with glass effect
class GlassIconButton extends StatefulWidget {
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
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: UltraGlassContainer(
          borderRadius: 14,
          padding: EdgeInsets.all((widget.size - 24) / 2),
          child: Icon(
            widget.icon,
            color: widget.iconColor ?? const Color(0xFF2D3748),
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Large hero card for main content
class GlassHeroCard extends StatelessWidget {
  final Widget child;
  
  const GlassHeroCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return UltraGlassContainer(
      borderRadius: 32,
      padding: const EdgeInsets.all(32),
      borderWidth: 2,
      child: child,
    );
  }
}
