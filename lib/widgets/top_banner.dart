//The in-app version of a push banner: it drops in from the top, says what
//happened, and takes you there if you tap it.
//
//WHY IT HAS TO EXIST. Android does not draw a system notification while the
//app is in the foreground - the message arrives as onMessage instead and the
//app is expected to say something itself. Without this, a match being
//revealed while somebody was swiping simply changed a row on a page they
//were not looking at, so the only way to notice was to go and count.
//
//AN OVERLAY, NOT A SnackBar OR A MaterialBanner. A SnackBar comes from the
//bottom, which is where this app's three action buttons live, and it would
//cover them. A MaterialBanner displaces the page content downwards rather
//than passing over it, so the deck would physically move while being swiped.
//An overlay entry sits above everything and touches nothing underneath.
//
//ONE AT A TIME. Two pushes arriving together used to be possible (a confirm
//and a reveal seconds apart), and two stacked banners would cover each other
//at the same offset. The newer message is the one worth showing, so it
//replaces rather than queues - this is a notice, not a log.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foitifinder/theme/app_colors.dart';

//HOW LONG IT STAYS. Long enough to read a line and decide to tap it, short
//enough that it is gone before it becomes part of the furniture.
const Duration kTopBannerVisible = Duration(seconds: 4);
const Duration kTopBannerSlide = Duration(milliseconds: 260);

//the entry currently on screen, so a second call can take its place
OverlayEntry? _current;

/// Drop a one-line notice in from the top of the screen.
///
/// [onTap] is called after it closes, so whatever it opens is not fighting
/// the exit animation for the same frames.
void showTopBanner(
  BuildContext context, {
  required String message,
  VoidCallback? onTap,
}) {
  //THE ROOT OVERLAY, so the banner survives a route being pushed underneath
  //it and is not clipped by whatever Scaffold happens to be on screen.
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _current?.remove();
  _current = null;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopBanner(
      message: message,
      onTap: onTap,
      onClosed: () {
        //GUARDED, because the entry can already be gone: a newer banner
        //replaced it, or the route it belonged to was torn down first.
        if (_current == entry) {
          _current = null;
          entry.remove();
        }
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _TopBanner extends StatefulWidget {
  final String message;
  final VoidCallback? onTap;
  final VoidCallback onClosed;

  const _TopBanner({
    required this.message,
    required this.onClosed,
    this.onTap,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: kTopBannerSlide,
    vsync: this,
  );
  Timer? _timer;
  //stops a tap during the exit animation from opening something twice
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(kTopBannerVisible, () => _close());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close({bool tapped = false}) async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();

    await _controller.reverse();
    widget.onClosed();
    //AFTER IT IS GONE. Opening a profile while this is still sliding would
    //put a route transition and this animation on the same frames, which is
    //exactly the stutter the notification path was just cleaned up to avoid.
    if (tapped) widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        ),
        child: SafeArea(
          //the status bar is not ours to draw over
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Material(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _close(tapped: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      //SAYS IT IS A DOOR. Without it the banner reads as a
                      //status message, and the match it is about stays
                      //one page away for no reason.
                      Icon(Icons.chevron_right,
                          color: theme.hintColor, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
