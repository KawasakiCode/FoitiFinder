//template for the 5 buttons used in homepage for swiping, rewinding and dm

import 'package:flutter/material.dart';

class AnimatedSwipeButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed; // Nullable to handle disabled state
  final Color activeColor;
  final double size;
  final bool forcePressed;

  const AnimatedSwipeButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.activeColor,
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
    final isActive = _isPressed || widget.forcePressed;
    final bool isDisabled = widget.onPressed == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surfaceColor = isDark ? const Color(0xFF1F2228) : Colors.white;

    final Color currentBackgroundColor = isActive 
        ? widget.activeColor 
        : surfaceColor;
        
    final Color iconColor = isActive 
        ? surfaceColor // Contrast color when pressed
        : (isDisabled ? Colors.grey : widget.activeColor);

    final List<BoxShadow> shadows = isActive || isDisabled
        ? [] // No shadow when pressed (feels like it's pushed in)
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ];

    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (widget.onPressed != null) widget.onPressed!();
      },
      onTapCancel: () => setState(() => _isPressed = false),

      child: AnimatedScale(
        scale: isActive ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: currentBackgroundColor,
            shape: BoxShape.circle,
            boxShadow: shadows,
          ),
          child: Icon(
            widget.icon,
            color: iconColor,
            size: widget.size * 0.6,
          ),
        ),
      ),
    );
  }
}