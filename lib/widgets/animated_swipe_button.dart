//Template for the 5 buttons used in homepage for swiping, rewinding and dm.
//
//Look: a clean circular button (white in light mode, near-black surface in dark)
//with a soft shadow and a gradient-tinted icon. On press it scales down and the
//whole circle fills with the gradient (icon flips to white) for tactile feedback.

import 'package:flutter/material.dart';

class AnimatedSwipeButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed; // Nullable to handle disabled state
  final Gradient gradient;
  final double size;
  final bool forcePressed;

  const AnimatedSwipeButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.gradient,
    this.size = 50.0,
    this.forcePressed = false,
  });

  @override
  State<AnimatedSwipeButton> createState() => _AnimatedSwipeButtonState();
}

class _AnimatedSwipeButtonState extends State<AnimatedSwipeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isPressed || widget.forcePressed;
    final bool isDisabled = widget.onPressed == null;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surface = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final double iconSize = widget.size * 0.6;
    final bool filled = isActive && !isDisabled;

    Widget iconWidget;
    if (isDisabled) {
      iconWidget = Icon(widget.icon,
          size: iconSize, color: Colors.grey.withValues(alpha: 0.5));
    } else if (filled) {
      //pressed: white icon over the gradient fill
      iconWidget = Icon(widget.icon, size: iconSize, color: Colors.white);
    } else {
      //idle: paint the icon itself with the gradient using a shader mask
      iconWidget = ShaderMask(
        shaderCallback: (bounds) => widget.gradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Icon(widget.icon, size: iconSize, color: Colors.white),
      );
    }

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onPressed!();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: isActive ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: filled ? null : surface,
            gradient: filled ? widget.gradient : null,
            shape: BoxShape.circle,
            border: isDark && !filled
                ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                : null,
            boxShadow: isDisabled || filled
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Center(child: iconWidget),
        ),
      ),
    );
  }
}
