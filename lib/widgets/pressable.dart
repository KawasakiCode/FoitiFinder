//Tap feedback without an ink ripple.
//
//Why not InkWell: the ripple paints ON TOP of whatever colour the row sits on,
//so on a filled card the splash colour and the card colour fight each other and
//the row reads as smeared rather than pressed. It also has to finish animating
//before it looks right, which is why DelayedInkWell exists at all - it holds the
//navigation back 225ms so the ripple can complete, and that delay is felt as lag.
//
//This does what Breeze does instead: dim the content slightly while the finger
//is down and (optionally) darken the background a touch. It reads as pressed
//immediately, costs no delay, and cannot collide with the surface underneath.
//
//onTap fires on release, so a drag off the row cancels it like any button.

import 'package:flutter/material.dart';

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  //rounded when the row is the first/last in a clipped card
  final BorderRadius? borderRadius;
  //how far the content dims while held. 1 = no change.
  final double pressedOpacity;
  //optional wash over the background while held; skip it on plain rows
  final bool tintBackground;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.pressedOpacity = 0.45,
    this.tintBackground = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  //a disabled row must not react to touch at all
  bool get _enabled => widget.onTap != null;

  void _set(bool down) {
    if (!_enabled || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    //a hair of the text colour, so it works on light and dark surfaces alike
    //without needing to know which one it is sitting on
    final Color tint = theme.colorScheme.onSurface.withValues(alpha: 0.06);

    return GestureDetector(
      //opaque so the whole row area is tappable, not just the painted pixels
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _down && widget.tintBackground ? tint : Colors.transparent,
          borderRadius: widget.borderRadius,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          opacity: _down ? widget.pressedOpacity : 1,
          child: widget.child,
        ),
      ),
    );
  }
}
