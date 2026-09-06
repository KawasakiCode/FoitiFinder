//showDialog with an animation you can actually see.
//
//Material's showDialog runs a 150ms fade with no scale, which at that speed
//reads as the dialog simply appearing - there is no sense of it coming FROM
//anywhere. This grows it out of the middle of the screen instead, so the eye
//follows it in.
//
//showDialog itself takes no transition parameters, so this drops down to
//showGeneralDialog, which does. Everything else about the call is kept
//identical (barrier colour from the theme, root navigator, dismissible
//barrier) so swapping showDialog -> showAppDialog changes nothing but the
//animation.

import 'package:flutter/material.dart';

//Forward is slower than reverse on purpose: an entrance wants to be watched,
//a dismissal wants to be over. Matching them makes closing feel sluggish.
const Duration _kEnterDuration = Duration(milliseconds: 300);
const Duration _kExitDuration = Duration(milliseconds: 180);

//THE SCRIM IS LIGHTER IN DARK MODE, and it has to be.
//
//A scrim dims by scaling every channel toward zero, so how much room a surface
//has to darken depends on how light it already is. In light mode 54% black
//takes a white card to #757575 - obviously dimmed, still obviously a card. In
//dark mode the same 54% takes a #1a1a1a card to #0c0c0c, indistinguishable
//from the near-black canvas: the cards do not dim, they vanish, and the page
//loses its structure the moment a dialog opens.
//
//The two numbers are coupled: the darker the cards are at rest, the less room
//they have to dim before hitting black, so the dark scrim has to be gentler.
//35% lands the current #181818 card on #101010 - the same dimmed value the
//old lighter card reached at 40%, so the dimmed look is unchanged while the
//resting cards are darker. Push the cards darker again and this has to drop
//again; eventually there is nothing left to give.
const double _kBarrierOpacityLight = 0.54;
const double _kBarrierOpacityDark = 0.35;

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  //Captured BEFORE the route is pushed. showGeneralDialog builds its page
  //against the navigator's context, which sits above this one - without
  //carrying the theme across, a dialog pushed on the root navigator can lose
  //the surrounding theme.
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  final CapturedThemes themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: useRootNavigator).context,
  );

  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _AppDialogRoute<T>(
      themes: themes,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(
        alpha: isDark ? _kBarrierOpacityDark : _kBarrierOpacityLight,
      ),
    ),
  );
}

//showGeneralDialog takes no reverseTransitionDuration, so the route is built
//by hand to let the exit run faster than the entrance.
class _AppDialogRoute<T> extends RawDialogRoute<T> {
  _AppDialogRoute({
    required CapturedThemes themes,
    required WidgetBuilder builder,
    required super.barrierDismissible,
    required String barrierLabel,
    required Color barrierColor,
  }) : super(
          barrierLabel: barrierLabel,
          barrierColor: barrierColor,
          transitionDuration: _kEnterDuration,
          pageBuilder: (dialogContext, _, _) =>
              themes.wrap(builder(dialogContext)),
          transitionBuilder: _buildTransition,
        );

  @override
  Duration get reverseTransitionDuration => _kExitDuration;
}

Widget _buildTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  //Closing plays the entrance backwards, but easeOutBack in reverse means the
  //dialog dips inwards before leaving, which looks like a stutter. A plain
  //ease on the way out avoids it.
  final bool closing = animation.status == AnimationStatus.reverse;

  final Animation<double> scale = CurvedAnimation(
    parent: animation,
    //a little overshoot past full size, so it lands with some weight instead
    //of easing to a stop
    curve: closing ? Curves.easeIn : Curves.easeOutBack,
  );

  //Fade finishes in the first half of the scale. The dialog is legible well
  //before it stops growing, which is what stops 300ms feeling slow.
  final Animation<double> fade = CurvedAnimation(
    parent: animation,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );

  return FadeTransition(
    opacity: fade,
    child: ScaleTransition(
      //from nothing, in the middle of the screen
      scale: scale,
      alignment: Alignment.center,
      child: child,
    ),
  );
}
