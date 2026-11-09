//The presentation pieces the main pages share: how things arrive, how they
//answer a finger, what stands in while they load, and what floats over them.
//
//NONE OF THIS KNOWS ABOUT THE APP'S DATA. Every widget here is handed its text
//and callbacks, so a page keeps its own state and logic and only borrows the
//way it is drawn.

import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:foitifinder/theme/app_colors.dart';

//the frost on everything that floats
final ImageFilter kGlassBlur = ImageFilter.blur(sigmaX: 10, sigmaY: 10);

//Fade and rise into place once, when first built. `order` staggers siblings.
//
//shouldPlay IS FOR LAZY LISTS. A sliver list rebuilds a row every time it
//scrolls back into range, which would replay the entrance on content the user
//has already seen. It is asked once per widget, and a false starts settled.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    this.order = 0,
    this.shouldPlay,
    required this.child,
  });

  final int order;
  final bool Function()? shouldPlay;
  final Widget child;

  //only the first screenful staggers: a row reached by scrolling has no
  //neighbours arriving with it, so a delay there is just a blank gap
  static int orderFor(int index) => index < 8 ? index : 0;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> {
  static const int _stepMs = 80;
  static const int _travelMs = 400;

  late final bool _play = widget.shouldPlay?.call() ?? true;

  @override
  Widget build(BuildContext context) {
    final int delayMs = _stepMs * widget.order;
    final int totalMs = delayMs + _travelMs;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _play ? 0 : 1, end: 1),
      duration: !_play || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      child: widget.child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

//A cross-fade that fills its parent. Whatever is leaving stops taking touches,
//so a second tap on something already on its way out does nothing.
class Crossfade extends StatelessWidget {
  const Crossfade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: FadeTransition(opacity: animation, child: child),
        builder: (context, faded) => IgnorePointer(
          ignoring: animation.status == AnimationStatus.reverse,
          child: faded,
        ),
      ),
      child: child,
    );
  }
}

//Scales its child to 0.95 under the finger and springs back, with a light
//haptic. The child keeps its own tap handling.
//
//A Listener, NOT onTapDown. Inside anything that scrolls, a GestureDetector
//holds onTapDown back for 100ms in case the touch becomes a drag, and a quick
//tap never shows a press at all. Listening to the raw pointer also leaves
//every existing onPressed, and its disabled state, exactly where it was.
class SpringPress extends StatefulWidget {
  const SpringPress({super.key, this.enabled = true, required this.child});

  //false while the child is disabled, so a dead button does not react
  final bool enabled;
  final Widget child;

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress>
    with SingleTickerProviderStateMixin {
  //underdamped, so the release overshoots slightly and settles
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 20,
  );

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  int? _pointer;
  Offset _start = Offset.zero;

  void _springTo(double target) {
    _scale.animateWith(
      SpringSimulation(_spring, _scale.value, target, _scale.velocity),
    );
  }

  void _release() {
    _pointer = null;
    _springTo(1);
  }

  void _onDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    _pointer = event.pointer;
    _start = event.position;
    _springTo(0.95);
  }

  //a touch that turns into a scroll is not a press
  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _start).distance > kTouchSlop) _release();
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    HapticFeedback.lightImpact();
    _release();
  }

  void _onCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _release();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

//The band of light that crosses a skeleton. 0 is centred; -1 and 1 are fully
//off either edge.
class ShimmerSweep extends GradientTransform {
  const ShimmerSweep(this.fraction);

  final double fraction;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

({Color base, Color highlight}) shimmerColors(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final Color base = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  return (
    base: base,
    highlight: Color.lerp(base, Colors.white, isDark ? 0.08 : 0.64)!,
  );
}

//Paints a shimmer through whatever Bones are under it.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.base, this.highlight, required this.child});

  //the skeleton colours when null; set for a shimmer on a coloured surface
  final Color? base;
  final Color? highlight;
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = shimmerColors(context);
    final Color base = widget.base ?? colors.base;
    final Color highlight = widget.highlight ?? colors.highlight;
    final bool still = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _sweep,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: LinearGradient(
            begin: const Alignment(-1, -0.32),
            end: const Alignment(1, 0.32),
            stops: const [0.32, 0.5, 0.68],
            colors: [base, highlight, base],
            transform: ShimmerSweep(still ? 0 : _sweep.value * 2 - 1),
          ).createShader,
          child: child,
        ),
      ),
    );
  }
}

//One placeholder shape. Null dimensions take whatever the parent allows.
class Bone extends StatelessWidget {
  const Bone({
    super.key,
    this.width,
    this.height,
    this.color = Colors.white,
    this.radius = 8,
    this.circle = false,
  });

  final double? width;
  final double? height;
  final Color color;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

//An icon, the words, and something to do about it. Expects a bounded parent,
//normally a SliverFillRemaining, so a page can keep pull-to-refresh working.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String? title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Entrance(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          if (title != null) ...[
            Entrance(
              order: 1,
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Entrance(
            order: 2,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: ink.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Entrance(
            order: 3,
            child: SpringPress(
              child: Semantics(
                container: true,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAction,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.refresh,
                          size: 24,
                          color: AppColors.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            actionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//Frosts any app bar, for a page whose content scrolls underneath it. The
//Scaffold needs extendBodyBehindAppBar, and the scroll view SliverGlassBarInset
//as its first sliver so the content starts below the bar.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({super.key, required this.child});

  final PreferredSizeWidget child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: kGlassBlur,
        child: Theme(
          data: theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: theme.scaffoldBackgroundColor.withValues(
                alpha: 0.72,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SliverGlassBarInset extends StatelessWidget {
  const SliverGlassBarInset({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverSafeArea(
      left: false,
      right: false,
      bottom: false,
      sliver: SliverToBoxAdapter(child: SizedBox(height: 8)),
    );
  }
}

//A frosted round icon button, for controls that sit on a photograph.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      child: ClipOval(
        child: BackdropFilter(
          filter: kGlassBlur,
          child: Material(
            color: Colors.black.withValues(alpha: 0.24),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onPressed,
              icon: Icon(icon, color: Colors.white),
              tooltip: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}
